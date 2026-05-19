#! /bin/bash

# Using split-displayVideo.sh and play_audio.sh together to merge audio and video into a single file.
# Uses ffmpeg, v4l2loopback, and ALSA.

_now=$(printf "%(%Y%m%d-%H%M)T" -1)
progn=${0##*/}  # basename
cd ${0%/*} # Need to be in dirname for this script to work  
splitVid="split-displayVideo.sh"

# Check if split-displayVideo.sh is running and has made the video loopback device available. See split-displayVideo.sh for details.
if [ -f /tmp/${splitVid}-vars.txt ] ; then
    . /tmp/${splitVid}-vars.txt
else
    echo "${splitVid} does not appear to be running. Running it now..." >&2
    ./${splitVid} -x &
    splitpid=$!
    sleep 2
    if [ -f /tmp/${splitVid}-vars.txt ] ; then
        . /tmp/${splitVid}-vars.txt
    else
        echo "${splitVid} did not start successfully. Exiting." >&2
        exit 1
    fi
fi

# Check if video loopback device is available. See split-displayVideo.sh for details.
if [ -n "$AVAILABLE" ] && [ -e "$AVAILABLE" ] ; then
    echo "Using available video loopback device $AVAILABLE" >&2
else
    echo "Video loopback device not available. Exiting." >&2
    exit 1
fi

ffcmd=( ffmpeg 
    -hide_banner -nostdin
    -loglevel warning
    -f v4l2 -i "$AVAILABLE" 
    "${_now}.mov"
)

echo "Executing >> ${ffcmd[@]}" >&2

"${ffcmd[@]}" &
ffpid=$!

./play_audio.sh -p $_now.wav &
audioPid=$!

[ -d /proc/$ffpid ] || {
    echo "ffmpeg process did not start successfully. Exiting." >&2
    kill -HUP $audioPid
    rm "${_now}.wav" $_now.mov 2> /dev/null
    exit 1
}

[ -d /proc/$audioPid ] || {
    echo "Audio process did not start successfully. Exiting." >&2
    kill -HUP $ffpid
    rm "${_now}.wav" $_now.mov 2> /dev/null
    exit 1
}

cleanup() {
    trap - EXIT HUP TERM INT
    sleep .5
    echo "Cleaning up $ffpid $audioPid $splitpid" >&2
    kill -QUIT $ffpid
    sleep 1
    kill -HUP $ffpid        # Sometimes needed if input got intterrupted 
    kill -TERM $audioPid
    sleep 1

    echo Merging audio and video into ${_now}-merged.mov... >&2
    ffmpeg -hide_banner -loglevel error -i "${_now}.mov" -i "${_now}.wav" -c:v copy -c:a aac "${_now}-merged.mov"
    exit
}

trap cleanup EXIT HUP TERM INT

wait -n $ffpid $audioPid $splitpid

exit