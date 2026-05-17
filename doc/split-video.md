Fri May 15 03:17:29 PM PDT 2026

Splitting video

- First install v4l2loopback (and others)
    - `sudo apt install v4l2loopback-dkms v4l-utils ffmpeg`
- Insert module for 2 devices:
    - `sudo modprobe v4l2loopback devices=2` 
    - Finer controls are available.
- Listing the devices:
    - `v4l2-ctl --list-devices`  
    - And maybe do device settings here.
- Split input /dev/video0 to 2 devices:
    - `ffmpeg -f v4l2 -i /dev/video0 -f v4l2 /dev/video2 -f v4l2 /dev/video3`
    
    - Probably best to set devices raw and explicitly do sizes and codecs.

- Attach devices to video output
    - `ffplay /dev/video2`
    - `ffmpeg -f v4l2 -i /dev/video3 -f xv ""`

- Remove module when done:
    - `sudo rmmod v4l2loopback`



