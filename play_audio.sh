#!/bin/bash
#
# Audio player script using ffmpeg. It can read from an ALSA capture device or a file, and write to an ALSA playback device or a file.
#

progn=${0##*/}
inputDevice=${AUD_DEVICE:-"hw:3"}
outputDevice=${AUD_OUTPUT:-"hw:1"}
pi () { echo "[$progn] $*" >&2 ; }

inputParam=()
outputParam=()

usage() {
    cat <<_EOL_

$progn [ -c file ] [ -p file ]
    
    Play audio from a file or device (default $inputDevice)
    into device or file (default $outputDevice) using ffmpeg.

    ALSA device detection should be automatic.

    -c file    Input file or capture device (default $inputDevice)
    -p file    Output file or playback device (default $outputDevice)

_EOL_

    exit
}

while [ -n "$1" ] ; do
    case "$1" in
        -c) 
            shift
            [ -e "$1" ] || {
                pi "Input < "$1" > not found." 
                exit 1
            }
            inputDevice="$1"
            ;;
        -p) 
            shift
            outputDevice="$1"
            ;;
        *) usage ;;
    esac
    shift
done

# Input ALSA?
if grep -q CAPTURE <( alsactl info $inputDevice 2> /dev/null ) ; then  
    pi "$inputDevice is an ALSA capture device" 
    inputParam=( "${inputParam[@]}" -f alsa -ac 2 -ar 48000 )
else
    # Should be an actual file-like input. Assume raw PCM if it doesn't have a recognizable format.
    [ -e "$inputDevice" ] || {
        pi "Input < $inputDevice > not found." 
        exit 1
    }
    inputParam=( "${inputParam[@]}" -f s16le -ac 2 -ar 48000 )
fi
    
# Output ALSA?
grep -q PLAYBACK <( alsactl info $outputDevice 2> /dev/null ) && { 
    pi "$outputDevice is an ALSA playback device" 
    outputParam=( "${outputParam[@]}" -f alsa )
}


cmd=( ffmpeg 
    -hide_banner -loglevel error
    "${inputParam[@]}" 
    -i "$inputDevice" 
    "${outputParam[@]}" -c:a copy 
    "$outputDevice"
)

pi "$progn: Executing >> ${cmd[@]}" 
"${cmd[@]}"
ret=$?

pi "$progn: Finished playing audio." 

exit $ret

