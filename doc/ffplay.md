## ffplay options I like

- `-autoexit` will quit when over
- `-hide_banner` for terminal output cleanliness

- display a time stamp in the viewer:
    `ffplay -vf "drawtext=text='%{pts\:hms}':box=1:x=(w-tw)/2:y=h-(2*lh)" input.mp4`
...

## ffplay key bindings

- <space> or p : Play/pause
- q or ESC : quit
- w : some kind of spectrogram/graph
- a : cycle audio channel
- v : cycle video channel
- s : stops and skips forward frame
- f : full screen
- c : cycle program
- m : mute
- L/R arrows : back/forward ~5s
- U/D arrows : back/forward ~60s


