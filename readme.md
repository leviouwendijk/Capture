# CLI-based Screen Recording (for macOS)

## Features

* built-in muxing support (with offset)
* set resolution (default: same as screen)
* set (target) fps
* set audio input
* flag for system-audio
* simple gain setting (`--system-gain 0.35` can balance a lower mic input volume)
* see your available input devices

## Examples

List available displays and audio inputs:

```sh
capturer devices
````

Record the main display with the default size and frame rate:

```sh
capturer record \
    --audio ext-in \
    --output ~/Desktop/recording.mov
```

Record a 30-second clip:

```sh
capturer record \
    --audio ext-in \
    --duration 30 \
    --output ~/Desktop/recording.mov
```

Record at 4K / 50 fps:

```sh
capturer record \
    --audio ext-in \
    --width 3840 \
    --height 2160 \
    --fps 50 \
    --quality standard \
    --output /tmp/4k.mov
```

Record screen, microphone, and system audio as separate audio tracks:

```sh
capturer record \
    --audio ext-in \
    --system-audio \
    --audio-layout separate \
    --output /tmp/separate-audio.mov
```

> `separate` = cheapest path: passthrough muxing, no audio render pass.

Record screen, microphone, and system audio mixed into one audio track:

```sh
capturer record \
    --audio ext-in \
    --system-audio \
    --audio-layout mixed \
    --mic-gain 1.0 \
    --system-gain 0.35 \
    --output /tmp/mixed-audio.mov
```
> `mixed` = rendered path: microphone and system audio are combined into one track before muxing (allowing gain adjustments).

Lower the system audio relative to the microphone:

```sh
capturer record \
    --audio ext-in \
    --system-audio \
    --system-gain 0.35 \
    --output /tmp/balanced-audio.mov
```

Also raise the mic audio:

```sh
capturer record \
    --audio ext-in \
    --system-audio \
    --system-gain 0.35 \
    --mic-gain 1.5 \
    --output /tmp/balanced-audio.mov
```

> Any `--mic-gain` or `--system-gain` value other than `1.0` forces the rendered mixed-audio path.

Use a named input device:

```sh
capturer record \
    --audio "Built-in Microphone" \
    --duration 10 \
    --output /tmp/builtin-mic.mov
```

Use an explicit bitrate instead of a quality preset:

```sh
capturer record \
    --audio ext-in \
    --width 3840 \
    --height 2160 \
    --fps 50 \
    --bitrate 45000000 \
    --output /tmp/high-bitrate.mov
```

Record video only:

```sh
capturer video \
    --duration 10 \
    --width 1920 \
    --height 1080 \
    --fps 30 \
    --quality standard \
    --output /tmp/video-only.mov
```

Test microphone capture only:

```sh
capturer audio \
    --audio ext-in \
    --duration 5 \
    --sample-rate 48000 \
    --channel 1 \
    --output /tmp/ext-in.wav
```

## Background

I tried doing this with `ffmpeg`, but it caused audio underruns I could not (and want not) resolve. Still looking for a CLI option, and this is a light implementation over native APIs. 

## Ideas

* [ ] multi-input support (audio, screens)
* [ ] multi-ouput rendering (summing, gain, routing (DSL?))
* [ ] prepending sine wave in recording, video flicker (synchronization)
* [ ] live input gain modification
* [ ] live metering
* [ ] loss-less failure behavior
* [ ] tempdir override (workspace setting for enough tempdir storage)
* [x] recording failure as system notifications (basic osascript version)
