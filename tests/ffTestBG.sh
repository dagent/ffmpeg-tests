#! /bin/bash

# Testing to get ffmpeg record video stream in the background, and host to gracefully stop recording and clean up when the script is killed. 

_now=$(printf "%(%Y%m%d-%H%M)T" -1)
progn=${0##*/}  # basename
cd ${0%/*} # Need to be in dirname for this script to work

sig=${sig:-"-QUIT"}   # <- This seems to be the best signal for ffmpeg to gracefully stop recording and finalize the output file. 
VID_DEVICE=${VID_DEVICE:-"/dev/video0"}
VID_WIDTH=640
VID_HEIGHT=480
VID_FPS=30
CODEC_DEVICE="yuyv422"
ffcmd=( ffmpeg 
    -hide_banner -y
    -nostdin        # Puts ffmpeg in non-interactive mode, so it doesn't wait for user input on the terminal. Important for running in the background.
    #-loglevel error
    -f v4l2 -video_size ${VID_WIDTH}x${VID_HEIGHT} -framerate $VID_FPS -input_format $CODEC_DEVICE -i "$VID_DEVICE" 
    "Test$progn.mov"
)

echo -ne "\n### Executing > ${ffcmd[@]} <\n\n"  

"${ffcmd[@]}" &
ffpid=$!    

cleanup () {
    echo "Cleaning up..." >&2
    [ -d /proc/$ffpid ] && {
        echo "Killing ffmpeg process $ffpid with signal $sig" >&2
        kill $sig $ffpid
    sleep .5
    exit
    }
}
trap cleanup EXIT TERM INT HUP

while false ; do
    sleep 5
    echo "ffmpeg process $ffpid is still running..." >&2
done

wait $ffpid
ret=$?

echo "$progn exited with code $ret" >&2

exit