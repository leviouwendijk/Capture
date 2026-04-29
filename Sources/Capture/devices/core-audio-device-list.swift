import CoreAudio
import Foundation

struct CoreAudioDeviceList: Sendable {
    func inputDevices() throws -> [CaptureDevice] {
        try audioDeviceIDs()
            .filter {
                try hasInputStreams(
                    $0
                )
            }
            .map {
                try inputDevice(
                    $0
                )
            }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare(
                    $1.name
                ) == .orderedAscending
            }
    }
}

private extension CoreAudioDeviceList {
    func audioDeviceIDs() throws -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var byteCount: UInt32 = 0
        try check(
            AudioObjectGetPropertyDataSize(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &byteCount
            ),
            message: "Could not read CoreAudio device list size."
        )

        let count = Int(byteCount) / MemoryLayout<AudioDeviceID>.size

        guard count > 0 else {
            return []
        }

        var devices = [AudioDeviceID](
            repeating: 0,
            count: count
        )

        try check(
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &byteCount,
                &devices
            ),
            message: "Could not read CoreAudio device list."
        )

        return devices
    }

    func hasInputStreams(
        _ deviceID: AudioDeviceID
    ) throws -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var byteCount: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(
            deviceID,
            &address,
            0,
            nil,
            &byteCount
        )

        guard status == noErr else {
            return false
        }

        let count = Int(byteCount) / MemoryLayout<AudioStreamID>.size
        return count > 0
    }

    func inputDevice(
        _ deviceID: AudioDeviceID
    ) throws -> CaptureDevice {
        let name = try stringProperty(
            deviceID,
            selector: kAudioObjectPropertyName,
            scope: kAudioObjectPropertyScopeGlobal,
            fallback: "Audio Input \(deviceID)"
        )

        let uid = try stringProperty(
            deviceID,
            selector: kAudioDevicePropertyDeviceUID,
            scope: kAudioObjectPropertyScopeGlobal,
            fallback: String(deviceID)
        )

        let sampleRate = try? doubleProperty(
            deviceID,
            selector: kAudioDevicePropertyNominalSampleRate,
            scope: kAudioObjectPropertyScopeGlobal
        )

        let detail: String?

        if let sampleRate {
            detail = "\(Int(sampleRate)) Hz"
        } else {
            detail = nil
        }

        return CaptureDevice(
            id: uid,
            name: name,
            kind: .audio_input,
            detail: detail
        )
    }

    func stringProperty(
        _ deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        fallback: String
    ) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        var value: Unmanaged<CFString>?
        var byteCount = UInt32(
            MemoryLayout<Unmanaged<CFString>?>.size
        )

        let status = withUnsafeMutablePointer(
            to: &value
        ) {
            AudioObjectGetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                &byteCount,
                $0
            )
        }

        guard status == noErr,
              let value else {
            return fallback
        }

        return value.takeUnretainedValue() as String
    }

    func doubleProperty(
        _ deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) throws -> Double {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        var value = Float64(0)
        var byteCount = UInt32(
            MemoryLayout<Float64>.size
        )

        try check(
            AudioObjectGetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                &byteCount,
                &value
            ),
            message: "Could not read CoreAudio numeric property."
        )

        return Double(value)
    }

    func check(
        _ status: OSStatus,
        message: String
    ) throws {
        guard status == noErr else {
            throw CaptureError.deviceDiscovery(
                "\(message) OSStatus=\(status)"
            )
        }
    }
}
