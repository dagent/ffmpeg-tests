#! /bin/bash

# Install v4l2loopback module if not loaded.  Defaults to creating /dev/video3 and /dev/video4 loopback devices.


type -p pd || pd () {
    ${DEBUG:-false} && echo -ne "[$progn-${BASH_LINENO[0]}] $*\n" >&2 ; true
}


# modCheck checks if the v4l2loopback module is loaded and sets VID1, VID2, and modOptions if not.
modCheck () {
    if lsmod | grep -q v4l2loopback ; then
        pd "v4l2loopback module is already loaded."
        ${DEBUG:-false} && {
            cd /sys/devices/virtual/video4linux/ 
            for dev in video* ; do
                echo "--- Device: /dev/$dev ---" >&2
                v4l2-ctl -d "/dev/$dev" --info 2>&1 | sed 's/^/    /' >&2   
            done
        }
        return 0
    else
        pd "v4l2loopback module is not loaded."
        ${DEBUG:-false} && modinfo -n v4l2loopback

        # Get the next available video number for loopback devices
        VID1=${VID1:-$( vids=( /dev/video* ) ; echo $(( ${vids[-1]#/dev/video} +1 )) )}
        VID2=${VID2:-$(( VID1 + 1 ))}
        modOptions=(video_nr=$VID1,$VID2 card_label='loopback1','loopback2')
        pd "Next available video numbers for loopback devices: $VID1 and $VID2"

        return 1
    fi
}

modLoad () {
    modCheck && return 0
    echo "Attempting to load v4l2loopback module with sudo privileges..." >&2
    if sudo modprobe v4l2loopback "${modOptions[@]}" ; then
        pd "v4l2loopback module loaded successfully."
        return 0
    else
        pd "Failed to load v4l2loopback module."
        return 1
    fi
}

modDelete () {
    if modCheck ; then
        echo "Attempting to remove v4l2loopback module with sudo privileges..." >&2
        if sudo modprobe -r v4l2loopback ; then
            pd "v4l2loopback module removed successfully."
            modCheck
            return 0
        else
            pd "Failed to remove v4l2loopback module."
            return 1
        fi
    else
        pd "v4l2loopback module is not loaded, nothing to remove."
        return 0
    fi
}

main () {

    progn=${0##*/}  # basename

    case "$1" in
        remove) modDelete ; exit $? ;;
        *) ;;
    esac

    modLoad || {
        pd "Error: Unable to load v4l2loopback module. Exiting."
        exit 1
    }

    pd "To remove the v4l2loopback module, run this script with the 'remove' argument: $0 remove"

}

return &> /dev/null || main "$@"  # Run main() if called as a script
