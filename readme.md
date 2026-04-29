# CLI-based Screen Recording (for macOS)

## Features

* built-in muxing support
* set resolution (default: same as screen)
* set (target) fps
* set audio input
* flag for system-audio
* simple gain setting (`--system-gain 0.35` can balance lower mic volume)
* see your input devices

## Background

I tried doing this with `ffmpeg`, but it caused audio underruns I could not (and want not) resolve. Still looking for a CLI option, and this is a light implementation over native APIs. 

