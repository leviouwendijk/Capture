# CLI-based Screen Recording (for macOS)

## Features

* built-in muxing support with timeline offset handling
* screen recording
* camera recording
* composed screen + camera recording
* microphone recording
* optional system-audio capture
* separate or mixed audio tracks
* gain controls for microphone and system audio
* configurable final output path
* configurable workspace root for intermediate recording files
* fixed-duration recording with `--duration`
* live recording for `record`, `camera`, and `compose` when `--duration` is omitted
* device listing for displays, cameras, and audio inputs

## Examples

List available displays, cameras, and audio inputs:

```sh
capturer devices
````

Record the main display and microphone until stopped:

```sh
capturer record \
    --audio ext-in \
    --output ~/Desktop/recording.mov
```

Record a 30-second screen clip:

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

Use a named input device:

```sh
capturer record \
    --audio "Built-in Microphone" \
    --duration 10 \
    --output /tmp/builtin-mic.mov
```

Choose a final output path and a separate workspace root:

```sh
capturer record \
    --audio ext-in \
    --duration 30 \
    --output ~/Movies/Capture/final-recording.mov \
    --workdir /Volumes/FastScratch/Capture
```

`--output` is the final exported recording.

`--workdir` is only for intermediate files such as temporary screen video, microphone audio, system audio, composed video, and retained partial files after a failed export.

Use `CAPTURE_WORKDIR` as the default workspace root:

```sh
CAPTURE_WORKDIR=/Volumes/FastScratch/Capture \
capturer record \
    --audio ext-in \
    --duration 30 \
    --output ~/Movies/Capture/recording.mov
```

A command-line `--workdir` takes precedence over `CAPTURE_WORKDIR`.

Record screen, microphone, and system audio as separate audio tracks:

```sh
capturer record \
    --audio ext-in \
    --system-audio \
    --audio-layout separate \
    --output /tmp/separate-audio.mov
```

`separate` is the cheapest path: passthrough muxing, with no audio render pass.

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

`mixed` renders microphone and system audio into one track before muxing.

Lower the system audio relative to the microphone:

```sh
capturer record \
    --audio ext-in \
    --system-audio \
    --system-gain 0.35 \
    --output /tmp/balanced-audio.mov
```

Raise the mic audio while lowering system audio:

```sh
capturer record \
    --audio ext-in \
    --system-audio \
    --system-gain 0.35 \
    --mic-gain 1.5 \
    --output /tmp/balanced-audio.mov
```

Do not pass a non-default `--system-gain` without `--system-audio`:

```sh
capturer record \
    --audio ext-in \
    --system-gain 0.35 \
    --output /tmp/invalid.mov
```

That fails early with:

```text
Cannot use --system-gain without --system-audio. Add --system-audio or remove --system-gain.
```

Record camera and microphone until stopped:

```sh
capturer camera \
    --camera "Studio Display Camera" \
    --audio ext-in \
    --output ~/Desktop/camera.mov
```

Record a fixed-duration camera clip:

```sh
capturer camera \
    --camera "Studio Display Camera" \
    --audio ext-in \
    --duration 10 \
    --fps 30 \
    --quality standard \
    --mic-gain 1.5 \
    --output ~/Desktop/camera.mov
```

Record camera with a dedicated workspace root:

```sh
capturer camera \
    --camera "Studio Display Camera" \
    --audio ext-in \
    --duration 10 \
    --output ~/Desktop/camera.mov \
    --workdir /Volumes/FastScratch/Capture
```

Compose screen and camera with the camera overlaid in the bottom-right corner:

```sh
capturer compose \
    --camera "Studio Display Camera" \
    --audio ext-in \
    --layout overlay \
    --overlay-source camera \
    --overlay-width 0.24 \
    --overlay-x right \
    --overlay-y bottom \
    --overlay-margin 32 \
    --output ~/Desktop/composed-overlay.mov
```

Compose a fixed-duration overlay recording with system audio:

```sh
capturer compose \
    --camera "Studio Display Camera" \
    --audio ext-in \
    --layout overlay \
    --overlay-source camera \
    --overlay-width 0.24 \
    --overlay-x right \
    --overlay-y bottom \
    --system-audio \
    --audio-layout mixed \
    --mic-gain 2.0 \
    --system-gain 0.30 \
    --duration 30 \
    --output ~/Desktop/composed-overlay.mov
```

Compose screen and camera side by side:

```sh
capturer compose \
    --camera "Studio Display Camera" \
    --audio ext-in \
    --layout side-by-side \
    --gap 24 \
    --duration 30 \
    --output ~/Desktop/side-by-side.mov
```

Use the screen as the overlay source on top of the camera:

```sh
capturer compose \
    --camera "Studio Display Camera" \
    --audio ext-in \
    --layout overlay \
    --overlay-source screen \
    --overlay-width 0.30 \
    --overlay-x right \
    --overlay-y top \
    --duration 30 \
    --output ~/Desktop/camera-with-screen-overlay.mov
```

Compose with an explicit workspace root:

```sh
capturer compose \
    --camera "Studio Display Camera" \
    --audio ext-in \
    --layout overlay \
    --overlay-width 0.24 \
    --overlay-x right \
    --overlay-y bottom \
    --system-audio \
    --system-gain 0.30 \
    --mic-gain 2.0 \
    --duration 30 \
    --output ~/Desktop/composed-overlay.mov \
    --workdir /Volumes/FastScratch/Capture
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

Trigger the retained-partial-recording failure path:

```sh
capturer test fail
```

## Background

I tried doing this with `ffmpeg`, but it caused audio underruns I could not and do not want to resolve. This is a light implementation over native macOS APIs.

## Ideas

* [ ] multi-input support for audio and screens
* [ ] multi-output rendering, summing, gain, and routing
* [ ] prepending sine wave in recording and video flicker for synchronization
* [ ] live input gain modification
* [ ] live metering
* [x] loss-less failure behavior for partial recording files
* [x] workspace/tempdir override
* [x] recording failure as system notifications
* [-] make ins, outs, sinks reusable components
* [ ] overwrite-confirmation, explicit --overwrite flag for override of overwrite-confirmatio step
* [ ] fix continuity camera latent failures
* [ ] refactor to reduce duplications
