import AVFoundation

@MainActor
class VoiceGuidanceService: ObservableObject {
    static let shared = VoiceGuidanceService()

    @Published var isEnabled = false
    @Published var volume: Float = 0.8

    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        guard isEnabled else { return }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.volume = volume
        utterance.pitchMultiplier = 1.0

        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .word)
        }

        synthesizer.speak(utterance)
    }

    func speakDirection(_ instruction: String, distance: String) {
        speak("In \(distance), \(instruction)")
    }

    func speakMilestone(_ text: String) {
        speak(text)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
