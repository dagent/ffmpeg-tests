## Some tests for ffmpeg

There are some bash and systems calls to deal with running multiple ffmpeg instances to get things done.  Main goal is to have a camera video-only display running, and toggle recording of video and audio -- with audio coming from an arbitrary source.

**v4l2loopbackInit** -- Neccesary to multiplex a Video4Linux camera for display and recording.  Other scripts source it to check on module status and device names to use for multiplexing.

**cameraInit.sh** -- Starts up the camera and multiplexes the output to devices setup by the above module.  Uses ffmpeg.  Error checking so that only one process will run.  See **-h** for more.

**captureInit.sh** -- Two video capture modes -- display and record.  With checks to that only one process runs at a time.

**play_audio.sh** -- For grabbing audio

**mergeAV.sh** -- Starts recording video and audio using **captureInit.sh record** and **play_audio.sh**, merging them when process ends.

**variable_storer.sh** -- some utility functions for cross scripting utilities to keep track of audio/video parameters.  Aspirational for now... (also **conf**)

See the **verona** script for use.

