#! /bin/bash

# Start an ffmplay process to display or record video from a loopback device.

_now=$(printf "%(%Y%m%d-%H%M%S)T" -1)
progn=${0##*/}  # basename
cd ${0%/*} # Need to be in dirname for this script to work
ofilen="$_now.mkv"

pe () {
    echo "$progn: $@" >&2
}

[ -f /tmp/cameraInit.sh-vars.txt ] && . /tmp/cameraInit.sh-vars.txt 

VID1=${VID1:-10} # Base number for display loopback devices.
VID2=${VID2:-11} # Base number for record loopback devices.
DISPLAY_INPUT="/dev/video${VID1}" # Loopback video device to display.
RECORD_INPUT="/dev/video${VID2}" # Loopback video device to record.

usage () {
    cat <<_EOL_ 

Usage: $progn [display|record] <options>

    Start an ffmplay process to display video from a loopback device,
    or ffmpeg to record video from a loopback device.

    Options:        
    -q                          Remove display/record from loopback device
                                and exit if not in use.

    -f                          Force remove display/record from loopback device
                                without checking if it is in use.

    -i device                   Loopback video device to display/record.
                                Should be created by cameraInit.sh.

                                Current device settings:
                                DISPLAY_INPUT=$DISPLAY_INPUT
                                RECORD_INPUT=$RECORD_INPUT

    -o filename                 Output filename for recording. Default is
                                YYYYMMDD-HHMM.mkv in the current directory. 

_EOL_

    exit 1

}

mode="$1" ; shift

case "$mode" in
    display) inputDev="$DISPLAY_INPUT" ;;
    record) inputDev="$RECORD_INPUT" ;; 
    *)  usage ;;
esac

PIDFILE="/tmp/${progn}-${mode}.pid"

# Handle command line options.
while getopts "qfd:o:" opt; do
    case $opt in
        q)  # Remove display/record from loopback device and exit if not in use.
            if [ -f $PIDFILE ] ; then
                PID=$(cat $PIDFILE)
                if ps -p $PID > /dev/null 2>&1 ; then
                    pe "At line $LINENO -- $mode process with PID $PID is still running. Removing $mode from loopback device." 
                    kill -TERM $PID || {
                        pe "Error killing $mode process with PID $PID. Exiting." 
                        exit 1
                    }
                    rm -f $PIDFILE
                    exit 0
                else
                    pe "At line $LINENO -- $mode process with PID $PID is not running. Removing PID file." 
                    rm -f $PIDFILE
                    exit 0
                fi
            else
                pe "At line $LINENO -- $mode not running. Nothing to remove." 
                exit 0
            fi
            ;;
        f)  # Force remove display from loopback device without checking if it is in use.
            if [ -f $PIDFILE ] ; then
                PID=$(cat $PIDFILE)
                if ps -p $PID > /dev/null 2>&1 ; then
                    pe "At line $LINENO -- $mode process with PID $PID is still running. Force removing $mode from loopback device." 
                    kill -TERM $PID || {
                        pe "Error killing $mode process with PID $PID. Exiting." 
                        exit 1
                    }
                    rm -f $PIDFILE
                    exit 0
                else
                    pe "At line $LINENO -- $mode process with PID $PID is not running. Removing PID file." 
                    rm -f $PIDFILE
                    exit 0
                fi
            else
                pe "At line $LINENO -- $mode not running. Nothing to remove." 
                exit 0
            fi
            ;;
        i)  inputDev="$OPTARG" ;;
        o)  ofilen="$OPTARG" ;;
        *)  usage ;;
    esac
done
shift $((OPTIND -1))    

# Check if mode is already running.
[ -f $PIDFILE ] && {
    pe "At line $LINENO -- $mode already running. Use -q to remove." ; exit 1 ; }

# cameraInit.sh running?
[ -f /tmp/cameraInit.sh.pid ] || {
    pe "cameraInit.sh not running -- exiting." ; exit 1 ; }

# Check if loopback video device exists.
[ -c $inputDev ] || {
    pe "At line $LINENO -- loopback video device $inputDev not found." ; exit 1 ; }

main() {

    case "$mode" in
        display) pe "Starting display from $inputDev..." 
                ffplay -hide_banner -loglevel error $inputDev & 
                ;;
        record) pe "Starting record from $inputDev..." 
                ffmpeg -hide_banner -loglevel error -nostdin -f v4l2 -i $inputDev -c copy -f matroska $ofilen &
                ;;
    esac
    PID=$!
    pe "Started ${mode}ing with PID $PID" 
    pe $PID > $PIDFILE    

    cleanup() {
        trap - HUP TERM INT EXIT
        $0 $mode -q
    }

    trap cleanup HUP TERM INT EXIT

    wait $PID

}

main &
mainPid=$!
pe "Started main function in background with PID $mainPid" 

