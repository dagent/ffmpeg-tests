#! /bin/bash

# Using captureInit.sh and play_audio.sh together to merge audio and video into a single file.
# Uses ffmpeg, v4l2loopback, and ALSA.

_now=$(printf "%(%Y%m%d-%H%M%S)T" -1)
progn=${0##*/}  # basename
cd ${0%/*} # Need to be in dirname for this script to work  

# Debugging output
DEBUG={$DEBUG:-false}
pd () {
    $DEBUG && echo "[${progn}-${BASHLINENO}] $@" >&2
}

# General reporting
pe () {
    echo "$progn: $@" >&2
    }

# Check if cameraInit.sh is running and has made the video loopback device available.
if [ -f /tmp/cameraInit.sh-vars.txt ] ; then
    . /tmp/cameraInit.sh-vars.txt
else
    pe "cameraInit.sh does not appear to be running. "
    pe "Please start cameraInit.sh first to initialize the video loopback device. Exiting."
    exit 1
fi

./captureInit.sh record -o "${_now}.mkv" || {
    pe "Failed to start video capture. Exiting."
    rm "${_now}.mkv" 2> /dev/null
    exit 1
}

pe "AUD_DEVICE: $AUD_DEVICE" 
./play_audio.sh -p $_now.wav & 
audioPid=$! 

sleep 1

[ -d /proc/$(cat /tmp/captureInit.sh-record.pid) ] || {
    pe "ffmpeg process did not start successfully. Exiting."
    kill -HUP $audioPid
    rm "${_now}.wav" $_now.mkv 2> /dev/null
    exit 1
}

[ -d /proc/$audioPid ] || {
    pe "Audio process did not start successfully. Exiting."
    ./captureInit.sh record -q
    sleep .5
    rm "${_now}.wav" $_now.mkv 2> /dev/null
    exit 1
}

cleanup() {
    trap - EXIT HUP TERM INT
    ./captureInit.sh record -q
    sleep .1
    pe "Cleaning up $audioPid "
    kill -TERM $audioPid
    sleep .5

    if [ -f "${_now}.mkv"  -a  -f "${_now}.wav" ] ; then
        pe " Merging audio and video into ${_now}-merged.mkv... "
        ffmpeg -hide_banner -loglevel error -i "${_now}.mkv" -i "${_now}.wav" -c:v copy -c:a aac "${_now}-merged.mkv"
    else 
        pe "One or both of the output files ${_now}.mkv and ${_now}.wav are missing. Skipping merge." 
    fi
    exit
}

trap cleanup EXIT HUP TERM INT

wait -n $audioPid 

exit