## Do not add it here

```text id="mj7txr"
CoreAudioWAVRecordingPipeline
CoreAudioInputStream
WAVAudioSink
ChainAudioSink
ScreenCaptureSystemAudioWriter
ScreenCaptureSystemAudioStreamOutput
CameraVideoStreamOutput
CameraVideoSink implementations
CaptureAudioInputSession.start()
CaptureAudioInputSession.stop()
CaptureAudioInputSession.runUntilStopped()
CaptureAudioInputSession.runUntilCancelled()
```

Those are lower-level input/sink/stream pieces. Putting wake-state ownership there makes nested sessions stack assertions everywhere. Put it at the public recorder/session boundary.

Final build check:

```sh id="b1vopi"
swift build
swift run ctest
pmset -g assertions
```
