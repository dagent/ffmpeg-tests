#! /bin/bash
#

#audioCard="hw:0"    # verona
audioCard="hw:3"    # KittyHo

cmd=( ffmpeg
  ### Global
    -y -hide_banner -thread_queue_size 1024

  # Audio input
    -f alsa -ac 2
        -i "$audioCard"

  # Video input
    -f v4l2 
    -video_size 640x480 -framerate 30
    #-ts 1
    -input_format yuyv422
        -i /dev/video0 

 # Output
   -force_key_frames 00:00:00.000
   # -r 25
   # -acodec libfdk_aac
   # -b:a 128k
   # -vcodec libx264
    SYNCTEST.mp4

 # player
   #-force_key_frames 00:00:00.000
    -pix_fmt yuv420p
    -f xv "$0"

)

echo -ne "\n### Executing > ${cmd[@]} <\n\n"

"${cmd[@]}" 

