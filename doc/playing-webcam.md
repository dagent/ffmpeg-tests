
Some ways to display /dev/video0 using CLI

mplayer tv:// -tv driver=v4l2:device=/dev/video0:width=1280:height=720:fps=30:outfmt=yuy2

ffplay -hide_banner /dev/video0 -fflags nobuffer -flags low_delay -framedro

ffmpeg -hide_banner -loglevel fatal -f v4l2 -i /dev/video0 -f xv "/dev/video0" 

vlc v4l2:///dev/video0

