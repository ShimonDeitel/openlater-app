import Foundation
import AVFoundation

/// Thin wrapper over AVAudioRecorder/AVAudioPlayer for voice-memo capsules. Records
/// straight to a local .m4a file under `MediaStore.directory` — never streamed or
/// uploaded anywhere.
@MainActor
final class VoiceRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordedDuration: TimeInterval = 0
    @Published var permissionDenied = false

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var levelTimer: Timer?
    private(set) var pendingFilename: String?

    func requestPermission(_ completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            return
        }
        let filename = MediaStore.reservedVoiceFilename()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            let rec = try AVAudioRecorder(url: MediaStore.url(for: filename), settings: settings)
            rec.record()
            recorder = rec
            pendingFilename = filename
            isRecording = true
            recordedDuration = 0
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self, let recorder = self.recorder else { return }
                self.recordedDuration = recorder.currentTime
            }
        } catch {
            pendingFilename = nil
        }
    }

    @discardableResult
    func stopRecording() -> String? {
        recorder?.stop()
        recorder = nil
        levelTimer?.invalidate()
        levelTimer = nil
        isRecording = false
        return pendingFilename
    }

    func discardPending() {
        stopRecording()
        MediaStore.delete(pendingFilename)
        pendingFilename = nil
    }

    func play(filename: String) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            player = try AVAudioPlayer(contentsOf: MediaStore.url(for: filename))
            player?.delegate = self
            player?.play()
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    func stopPlayback() {
        player?.stop()
        isPlaying = false
    }
}

extension VoiceRecorder: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.isPlaying = false }
    }
}
