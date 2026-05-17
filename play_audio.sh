#!/bin/bash
#
# Made for KittyHo's output on hw:1
#

progn=${0##*/}
inputDevice="hw:3"
outputDevice="hw:1"

inputParam=()
outputParam=()

usage() {
    cat <<_EOL_

$progn [ -c file ] [ -p file ]
    
    Play audio from a file or device (default $inputDevice)
    into device or file (default $outputDevice).

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
                echo "Input < "$1" > not found." >&2
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
    echo "$inputDevice is an ALSA capture device" >&2
    inputParam=( "${inputParam[@]}" -f alsa -ac 2 -ar 48000 )
else
    inputParam=( "${inputParam[@]}" -f s16le -ac 2 -ar 48000 )
fi
    
# Output ALSA?
grep -q PLAYBACK <( alsactl info $outputDevice 2> /dev/null ) && { 
    echo "$outputDevice is an ALSA playback device" >&2
    outputParam=( "${outputParam[@]}" -f alsa )
}


cmd=( ffmpeg 
    -hide_banner -loglevel error
    "${inputParam[@]}" 
    -i "$inputDevice" 
    "${outputParam[@]}" -c:a copy 
    "$outputDevice"
)

echo "$progn: Executing >> ${cmd[@]}" >&2
"${cmd[@]}"

exit

