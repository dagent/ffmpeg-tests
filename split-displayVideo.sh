#! /bin/bash

# Split video input into 2, display video, save to file.
# Uses ffmpeg, v4l2loopback


 
_now=$(printf "%(%Y%m%d-%H%M)T" -1)
progn=${0##*/}  # basename
cd ${0%/*} # Need to be in dirname for this script to work

# Are we already running? If so, exit. This is to prevent multiple instances of
# this script from running at the same time and creating multiple loopback
# devices.
if [ -f /tmp/${progn}-vars.txt ] ; then
    echo "Another instance of $progn is already running. Exiting." >&2
    exit 1
fi

# Ability to declare and store our variables if not already set. See variable_storer.sh for details.
[ -f ./variable_storer.sh ] || {
   echo "At line $LINENO -- missing file." >&2 ; exit 1 ; }
. ./variable_storer.sh
# This script relies on v4l2loopback to create loopback video devices. See v4l2loop.sh for details.
[ -f ./v4l2loop.sh ] || {
   echo "At line $LINENO -- missing file." >&2 ; exit 1 ; }
. ./v4l2loop.sh ; modCheck

setAndStore VID_DEVICE /dev/video0
setAndStore VID1 10 # Will create /dev/video${VID1} for splitting
setAndStore VID2 11 # Will create /dev/video${VID2} for splitting
setAndStore VID_WIDTH 640
setAndStore VID_HEIGHT 480
setAndStore VID_FPS 30
setAndStore CODEC_DEVICE yuyv422
setAndStore DEBUG false
setAndStore VID_OUTPUT "TestVid-${_now}.mov"

usage () {
    cat <<_EOL_

Usage: $progn <options>

    Display and record video via /dev/video{n,n+1} loopback devices.

    Options:        [defaults] 

    -i video_device [$VID_DEVICE]   Real v4l2 capture device.
    -n video_number [$VID1]         Base number for loopback devices. 
                                    Will create /dev/video${VID1} and /dev/video$(( VID1 + 1 )).
    -x                              Don't save to file, just display -- but still create loopback devices for use with other software. Overrides VID_OUTPUT.

    v4l2loopback module needs to be pre-loaded for this script to run in the background. See v4l2loop.sh.

    Override the following variables via environment or command line options. 

$(printSTORED)

_EOL_

    exit 1
}

# Debugging
pd () {
    local ln=${BASH_LINENO[0]} 
    ${DEBUG:-false} && echo -ne "[$progn-$ln] $*\n" >&2
}


while [ -n "$1" ] ; do
    case "$1" in
        -i) shift
            setAndStore VID_DEVICE "$1"
            pd "--- VID_DEVICE set to $VID_DEVICE"
            ;;
        -n) shift
            setAndStore VID1 "$1" ; setAndStore VID2 "$(( VID1 + 1 ))"
            pd "--- Output numbers set to $VID1 and $VID2"
            ;;
        -x) shift
            VID_OUTPUT=""  ; setAndStore VID_OUTPUT ""
            pd "--- VID_OUTPUT set to empty, will not save to file"
            ;;
        *) usage ;;
    esac
    shift
done

# Video device exists?
[ -c "$VID_DEVICE" ] || {
    echo "--- Error: VID_DEVICE '$VID_DEVICE' not found. Exiting." >&2
    exit 1
}

# Insert loopback module
modLoad || {
    echo "Error: Unable to load v4l2loopback module. Exiting." >&2
    exit 1
}


loopcmd=( ffmpeg 
  # Global options
    -y -hide_banner -loglevel error

  # Video source
    -f v4l2 
    -video_size "${VID_WIDTH}x${VID_HEIGHT}"
    -framerate $VID_FPS 
    -input_format $CODEC_DEVICE
    -ts 1
        -i "$VID_DEVICE" 

  # Output to both loopbacks
    -f v4l2
    -c copy
        /dev/video$VID1
    -f v4l2
    -c copy
        /dev/video$VID2
)

pd "Executing loop cmd\n\t${loopcmd[@]}\n"

{ "${loopcmd[@]}" & }  || {
    echo "loop cmd borked" >&2 ; exit 1 ; } ; loopcmdpid=$!
pd "Loop PID $loopcmdpid"

sleep 1

pd "Display " 
{ ffplay -hide_banner -loglevel error /dev/video$VID1 & } || {
    echo "Display  borked" >&2 ; exit ; } ; vid1pid=$!
pd "Display PID $vidpid1"

#pd "Display 2"
#{ ffmpeg -y -hide_banner -loglevel fatal \
    #-f v4l2 -i /dev/video$VID2 -f xv "/dev/video$VID2" & } || { 
    #echo "Display 2 borked" >&2 ; exit ; } ; vid2pid=$!

if [ -n "$VID_OUTPUT" ] ; then 
    echo "Saving to file ${VID_OUTPUT}"
    { ffmpeg -y -hide_banner -loglevel error \
        -f v4l2 -i  /dev/video$VID2 "${VID_OUTPUT}" & } || { 
            echo "File save borked" >&2 
            exit 
            } 
            vid2pid=$!
            pd "File save PID $vidpid2"
 else 
    pd "Not saving to file, skipping ffmpeg output command."
    echo "/dev/video$VID2 is available for use with other software." >&2
    setAndStore AVAILABLE "/dev/video$VID2"
fi

# Make available for merging with audio via play_audio.sh and mergeAV.sh. See those scripts for details.
printSTORED > /tmp/${progn}-vars.txt

cleanup () {
    trap - EXIT HUP TERM
    sleep .5
    [ -n "$vid2pid" ] && kill -TERM $vid2pid
    sleep .5
    kill -HUP $vid1pid
    sleep .5
    kill $loopcmdpid
    [ -f /tmp/${progn}-vars.txt ] && rm /tmp/${progn}-vars.txt
    exit
    #sleep .setAndStore
    #modDelete
}

trap cleanup EXIT HUP TERM

wait -n $vid1pid $vid2pid $loopcmdpid

