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

    -c file    Input file or device (default $inputDevice)
    -p file    Output file or device (default $outputDevice)

_EOL_

    exit
}

while [ -n "$1" ] ; do
    case "$1" in
        -c) 
            shift
            [ -f "$1" ] || [ -c "$1" ] || {
                echo "Input `"$1"` not found."
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
grep -q CAPTURE <( alsactl info $inputDevice 2> /dev/null ) && { 
    echo "$inputDevice is an ALSA capture device" >&2
    inputParam=( "${inputParam[@]}" -f alsa )
}
    
# Output ALSA?
grep -q CAPTURE <( alsactl info $outputDevice 2> /dev/null ) && { 
    echo "$outputDevice is an ALSA playback device" >&2
    outputParam=( "${outputParam[@]}" -f alsa )
}


cmd=( ffmpeg 
    -hide_banner 
    "${inputParam[@]}" 
    -i "$inputDevice" 
    "${outputParam[@]}" -ac 2 
    "$outputDevice"
)

echo "Executing >> ${cmd[@]}"
${cmd[@]}

exit

