#! /bin/bash

# Start an ffmplay process to display or record video from a loopback device.

_now=$(printf "%(%Y%m%d-%H%M%S)T" -1)
progn=${0##*/}  # basename
cd "${0%/*}" || exit 1 # Need to be in dirname for this script to work
ofilen="$_now.mkv"

pi () {
    echo "[$progn] $*" >&2
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

removeFromLoopback () {

    # Remove display/record from loopback device and exit if not in use.
    pi "$mode: request to quit"
    if [ -f $PIDFILE ] ; then
        PID=$(cat $PIDFILE)
        # Sometimes ffmpeg just doesn't listen...
        for sig in TERM HUP INT QUIT KILL ; do
            if ps -p $PID > /dev/null 2>&1 ; then
                pi "L$LINENO -- $mode process with PID $PID" \
                    " is still running. Killing with -$sig." 
                kill -$sig $PID 
                sleep .1
            else
                pi "L$LINENO -- $mode process with PID $PID is "\
                    "not running. Removing PID file." 
                [ -f $PIDFILE ] && rm $PIDFILE
                exit 0
            fi
        done
        # If we get here, something's wrong
        pi "!!! Can't stop $PID; bailing !!!" ; exit 2
    else
        pi "at $LINENO - $mode no pid file; apparently not running."
        pi "Nothing to remove." 
        exit 0
    fi

}

# Handle command line options.
while getopts "qi:o:" opt; do
    case $opt in
        q) removeFromLoopback ;;
        i)  inputDev="$OPTARG" ;;
        o)  ofilen="$OPTARG" ;;
        *)  usage ;;
    esac
done
shift $((OPTIND -1))    

# Check if mode is already running.  We return success.
[ -f "$PIDFILE" ] && {
    pi "At line $LINENO -- $mode already running. Use -q to remove." ; exit 0 ; }

# cameraInit.sh running?
[ -f /tmp/cameraInit.sh.pid ] || {
    pi "cameraInit.sh not running -- exiting." ; exit 1 ; }

# Check if loopback video device exists.
[ -c "$inputDev" ] || {
    pi "At line $LINENO -- loopback video device $inputDev not found." ; exit 1 ; }

main() {

    case "$mode" in
        display) pi "Starting display from $inputDev..." 
                ffplay -hide_banner -loglevel error "$inputDev" & 
                ;;
        record) pi "Starting record from $inputDev..." 
                ffmpeg -hide_banner -loglevel error -nostdin -f v4l2 -i "$inputDev" -c copy -f matroska "$ofilen" &
                ;;
    esac
    PID=$!
    pi "Started ${mode}ing with PID $PID" 
    echo $PID > $PIDFILE

    cleanup() {
        trap - TERM 
        pi "($mode) Trap signal [$1] rcvd, cleanup called."
        $0 $mode -q
    }

    ignore () {
        pi "($mode) ignoring kill signal $1"
    }

    trap 'cleanup TERM' TERM 
    trap 'ignore HUP' HUP
    trap 'ignore EXIT' EXIT
    trap 'ignore INT' INT

    wait $PID
    # We got here because ffplay or ffmpeg exited
    pi "$mode - $PID exited."
    [ -f $PIDFILE ] && rm $PIDFILE

}

main &
mainPid=$!

pi "Started main() $mode function in background with PID $mainPid" 


