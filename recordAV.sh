#/bin/bash

# Mix video and audio input in real time, while displaying video, save to file.
 
_now=$(printf "%(%Y%m%d-%H%M)T" -1)
progn=${0##*/}

VID_DEVICE=${VID_DEVICE:-/dev/video0}
#VID_OUTPUT="${VID_OUT:-TestVid-${_now}.mkv}"    # This works
VID_OUTPUT="${VID_OUT:-TestVid-${_now}.mov}"    # This is on iOS
AUD_DEVICE="${AUD_DEVICE:-hw:3}"

VID_WIDTH=${VID_WIDTH:-640}
VID_HEIGHT=${VID_HEIGHT:-480}
VID_FPS=${VID_FPS:-30}

Xout=false

CONF=""


usage () {
    cat <<_EOL_

Usage: $progn <options>

    Record input from a video and audio source.  Optionally display video live.

    Options:        [defaults] 

    -i video_file   [$VID_DEVICE]
    -D audio_file   [$AUD_DEVICE]
    -o output_file  [$VID_OUTPUT]

    -c config_file  [No default; declared values will overide any
                     command line options]

    -x            Display video live (to X)
    -d            Script debugging
    -p            Print ffmpeg command and exit

_EOL_

    exit 1
}

# Debugging
pd () {
    ${DEBUG:-false} && echo -ne "[$progn-$LINENO] $*" >&2
}

while [ -n "$1" ] ; do
    case "$1" in
        -i) shift
            VID_DEVICE="$1"
            pd "--- VID_DEVICE set to $VID_DEVICE"
            ;;
        -D) shift
            AUD_DEVICE="$1"
            pd "--- AUD_DEVICE set to $AUD_DEVICE"
            ;;
        -o) shift
            VID_OUTPUT="$1"
            pd "--- VID_OUTPUT set to $VID_OUTPUT"
            ;;
        -c) shift
            CONF="$1"
            ;;
        -x) shift
            Xout=true
            ;;
        -d) shift
            DEBUG=true
            ;;
        -p) shift
            PRINTCMD=true
            ;;
        *) usage ;;
    esac
    shift
done

[ -f "$CONF" ] && {
    pd "--- Reading configuration $CONF"
    . "$CONF"
} || pd "--- Configuration <$CONF> not found, continuing with defaults."

# Video device exists?
[ -c "$VID_DEVICE" ] || {
    pd "--- Error: VID_DEVICE '$VID_DEVICE' not found. Exiting."
    exit 1
}

# Audio device exists?
[ -e "$AUD_DEVICE" ] || {
    # Input ALSA?
    grep -q CAPTURE <( alsactl info "$AUD_DEVICE" 2> /dev/null ) && { 
        pd "--- $AUD_DEVICE is an ALSA capture device"
        audioInputParam=( "${audioInputParam[@]}" -f alsa -channels 2 -framerate 48000 )
    } || {
        pd "--- Error: AUD_DEVICE '$AUD_DEVICE' not found (or is not an ALSA device)."
        exit 1
    }
}

${Xout:-false} && {
    pd "--- X output enabled."
    TITLE="< $VID_DEVICE @ ${VID_WIDTH}x${VID_HEIGHT} ${VID_FPS}fps >"
    XoutputParam=( -pix_fmt yuv420p -f xv "$TITLE" )
}

cmd=( ffmpeg 
  # Global options
    -y -hide_banner

  # Audio source
    "${audioInputParam[@]}"
    -channels 2 
    -framerate 44100
        -i "$AUD_DEVICE"

  # Video source
    -f v4l2 
    -video_size "${VID_WIDTH}x${VID_HEIGHT}"
    -framerate $VID_FPS 
    -input_format yuyv422
    -ts 1
        -i "$VID_DEVICE" 

  # Output to file
    -force_key_frames 00:00:00.000
    -c:a copy
        "${VID_OUTPUT}"
  
  #Output to screen
    "${XoutputParam[@]}"
)

pd -ne "\n    ### Executing >> ${cmd[@]} <<\n\n" 
${PRINTCMD:-false} && { echo "${cmd[@]}"; exit; }

"${cmd[@]}"

exit
