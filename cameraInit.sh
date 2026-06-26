#! /bin/bash

# connect (or disconnect) a real video device to 2 loopback devices.

 
progn=${0##*/}  # basename
cd ${0%/*} # Need to be in dirname for this script to work
pi () { echo "[$progn] $*" >&2 ; }
pd () { ${DEBUG:-false} && echo "[$progn-$BASH_LINENO] $*" >&2 ; }

PIDFILE="/tmp/${progn}.pid"
VARFILE="/tmp/${progn}-vars.txt"

# Ability to declare and store our variables if not already set. See variable_storer.sh for details.
[ -f ./variable_storer.sh ] || {
   pi "variable_storer.sh not found" ; exit 1 
}
. ./variable_storer.sh
# This script relies on v4l2loopback module to create loopback video devices. See v4l2loopbackInit for details.
[ -f ./v4l2loopbackInit ] || {
   pi "missing v4l2loopbackInit ." ; exit 1 
}
. ./v4l2loopbackInit ; modCheck 

setAndStore VID_DEVICE /dev/video0
setAndStore VID1 10 # Will create /dev/video${VID1} for display
setAndStore VID2 11 # Will create /dev/video${VID2} for recording
setAndStore VID_WIDTH 640
setAndStore VID_HEIGHT 480
setAndStore VID_FPS 30
setAndStore VID_FORMAT yuyv422
setAndStore DEBUG false

usage () {
    cat <<_EOL_

Usage: $progn <options>

    Atttach a real video device to 2 loopback devices for use
    with other software.

    Options: 

    -r|-q           Remove camera from loopback devices and exit if not in use.

    -f              Force remove camera from loopback devices without
                    checking if they are in use.

    -i video_device         Real v4l2 capture device. [$VID_DEVICE]   
    -n video_number         Base number for loopback devices. [$VID1]

                            Will create /dev/video${VID1} and /dev/video$(( VID1 + 1 )).

    v4l2loopback module needs to be pre-loaded for this script to run in
    the background. See v4l2loopbackInit for details. This script will
    attempt to load it, but it will invoke sudo.

    Override the following via environment variables by setting them
    before running the script.

$(printSTORED)

_EOL_

    exit 1
}

# Remove camera from loopback devices if not in use.
removeCamera () {
    if [ -f $PIDFILE ] ; then {
        local pid=$(cat $PIDFILE)
        if ps -p $pid >& /dev/null ; then
            pi "Process with PID $pid is still running."
            if [ "$1" != "nocheck" ] ; then
                # Check if loopback devices are in use before removing camera from them.
                local pid1=$(lsof -t /dev/video$VID1 2>/dev/null | grep -v $pid)
                local pid2=$(lsof -t /dev/video$VID2 2>/dev/null | grep -v $pid)
                if [ -n "$pid1" ] || [ -n "$pid2" ] ; then
                        pi "Loopback devices /dev/video$VID1 or /dev/video$VID2 are currently in use. Not removing camera from loopback devices."
                    return 1
                fi
            fi
            pi "Removing camera from loopback devices."
            kill -TERM $pid || {
                pi "Error killing process with PID $pid. Exiting."
                return 1
            }

            rm -f $PIDFILE
            rm -f $VARFILE
            pi "Camera removed from loopback devices." 

        else {   
            pi "Process with PID $pid is not running. Removing stale PID file." 
            rm -f $PIDFILE
            rm -f $VARFILE
            }
        fi

    } else {
        pi "No PID file found. Assuming camera is not currently attached to loopback devices."
    } 
    fi
    return 0
}

# Handle command line options.
while [ -n "$1" ] ; do
    case "$1" in
        -r|-q|remove)
           pi "Removing camera from loopback devices if not in use and exiting."
           removeCamera || {
                pi "Error removing camera from loopback devices. Exiting." 
                exit 1
            }
            exit 0
            ;;
        -f) pi "Force removing camera from loopback devices without checking if they are in use."
            removeCamera nocheck || {
                pi "Error removing camera from loopback devices. Exiting." 
                exit 1
            }
            exit 0
            ;;
        -i) shift
            setAndStore VID_DEVICE "$1"
            pd "--- VID_DEVICE set to $VID_DEVICE"
            ;;
        -n) shift
            setAndStore VID1 "$1" ; setAndStore VID2 "$(( VID1 + 1 ))"
            pd "--- Output numbers set to $VID1 and $VID2"
            ;;
        *) usage ;;
    esac
    shift
done

# Are we already running? If so, exit. This is to prevent multiple instances of
# this script from running at the same time and creating multiple loopback
# devices.  We *do not* consider this a failure.
if [ -f "$PIDFILE" ] ; then
    pi "Another instance of $progn is already running. Exiting." 
    exit 0
fi

# Video device exists?
[ -c "$VID_DEVICE" ] || {
    pi "--- Error: VID_DEVICE '$VID_DEVICE' not found. Exiting." 
    exit 1
}

# Insert loopback module if not already loaded and check for errors.
modLoad || {
    pi "Error: Unable to load v4l2loopback module. Exiting." 
    exit 1
}

loopcmd=( ffmpeg 
  # Global options
    -y -hide_banner -loglevel error

  # Video source
    -f v4l2 
    -video_size "${VID_WIDTH}x${VID_HEIGHT}"
    -framerate $VID_FPS 
    -input_format $VID_FORMAT
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
    pi "loop cmd borked" ; exit 1 ; } ; loopcmdpid=$!
pd "Loop PID $loopcmdpid"
echo $loopcmdpid > $PIDFILE

printSTORED > $VARFILE

sleep 1
