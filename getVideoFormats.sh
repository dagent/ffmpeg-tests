#!/bin/bash

progn=${0%/}
device="/dev/video0"

usage () {
    cat <<_EOL_

$progn [-d device]

Print out video formats using various methods.  Device defaults to $device .

_EOL_

exit
}

while [ -n "$1" ] ; do
    case "$1" in
        -h) usage ;;
        -d) shift 
            [ -z "$1" ] && {
                echo -en "\nNo parameter in -d.\n"
                usage
            }
                device="$1"
            ;;
    esac
    shift
done

echo; echo "--- List Devices ---" ; echo
v4l2-ctl --list-devices

echo; echo "--- $device capabilities ---" ; echo
ffmpeg -hide_banner -f v4l2 -list_formats all -i $device -f xv

echo; echo "--- $device controls ---" ; echo
v4l2-ctl -d $device -L

echo; echo "--- $device current settings ---" ; echo
ffprobe -hide_banner $device
echo
v4l2-ctl -d $device -V


echo; exit 0

