import AVFoundation

internal struct CaptureMuxedAudioTrack {
    let track: AVMutableCompositionTrack
    let input: CaptureMuxAudioInput
}
