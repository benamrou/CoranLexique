import SwiftUI
import AVFoundation

// MARK: - MemorizationSpeaker

@MainActor
@Observable
final class MemorizationSpeaker: NSObject {

    // MARK: State
    enum Phase {
        case idle, playing, paused, finished
    }

    private(set) var phase: Phase = .idle
    private(set) var currentWord: WordModel? = nil
    private(set) var currentRepetition: Int = 0   // 1-based, shown in UI
    private(set) var currentWordIndex: Int = 0    // 0-based

    // MARK: Configuration
    var words: [WordModel] = []
    var repetitions: Int = 2      // per word
    var pauseSeconds: Double = 1.5
    var loop: Bool = false

    // MARK: Private
    private let synthesizer = AVSpeechSynthesizer()
    private var arabicVoice: AVSpeechSynthesisVoice?
    private var frenchVoice: AVSpeechSynthesisVoice?
    private var playTask: Task<Void, Never>? = nil
    private var utteranceFinishedContinuation: CheckedContinuation<Void, Never>? = nil

    // MARK: Init
    override init() {
        super.init()
        synthesizer.delegate = self
        arabicVoice = Self.preferredMaleVoice(for: "ar-SA") ?? AVSpeechSynthesisVoice(language: "ar-SA")
        frenchVoice = Self.preferredMaleVoice(for: "fr-FR") ?? AVSpeechSynthesisVoice(language: "fr-FR")
    }

    // MARK: - Voice selection

    private static func preferredMaleVoice(for language: String) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix(language.prefix(2)) && $0.gender == .male
        }
        // Prefer enhanced / premium quality
        return voices.sorted { lhs, rhs in
            qualityRank(lhs.quality) > qualityRank(rhs.quality)
        }.first
    }

    private static func qualityRank(_ q: AVSpeechSynthesisVoiceQuality) -> Int {
        switch q {
        case .enhanced: return 2
        case .default:  return 1
        default:        return 0
        }
    }

    // MARK: - Playback control

    func play() {
        guard phase != .playing else { return }
        if phase == .paused {
            synthesizer.continueSpeaking()
            phase = .playing
            return
        }
        phase = .playing
        playTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    func pause() {
        guard phase == .playing else { return }
        synthesizer.pauseSpeaking(at: .word)
        phase = .paused
    }

    func stop() {
        playTask?.cancel()
        playTask = nil
        synthesizer.stopSpeaking(at: .immediate)
        utteranceFinishedContinuation?.resume()
        utteranceFinishedContinuation = nil
        phase = .idle
        currentWord = nil
        currentWordIndex = 0
        currentRepetition = 0
    }

    // MARK: - Loop

    private func runLoop() async {
        guard !words.isEmpty else { phase = .finished; return }

        repeat {
            for (index, word) in words.enumerated() {
                if Task.isCancelled { return }
                currentWordIndex = index
                currentWord = word

                for rep in 1...max(1, repetitions) {
                    if Task.isCancelled { return }
                    currentRepetition = rep

                    // Speak Arabic
                    await speakIfNotCancelled(word.arabic, voice: arabicVoice)
                    if Task.isCancelled { return }

                    // Brief pause between languages
                    try? await Task.sleep(for: .milliseconds(400))
                    if Task.isCancelled { return }

                    // Speak French meaning — each definition part separately
                    let rawFrench = word.meaning.isEmpty ? word.transliteration : word.meaning
                    let parts = Self.splitDefinitions(rawFrench)
                    for (i, part) in parts.enumerated() {
                        await speakIfNotCancelled(part, voice: frenchVoice)
                        if Task.isCancelled { return }
                        // Pause between definition parts (shorter than inter-word pause)
                        if i < parts.count - 1 {
                            try? await Task.sleep(for: .milliseconds(700))
                            if Task.isCancelled { return }
                        }
                    }

                    // Pause between repetitions (except last)
                    if rep < repetitions {
                        try? await Task.sleep(for: .seconds(pauseSeconds))
                        if Task.isCancelled { return }
                    }
                }

                // Pause between words
                if index < words.count - 1 {
                    try? await Task.sleep(for: .seconds(pauseSeconds))
                }
            }
        } while loop && !Task.isCancelled

        if !Task.isCancelled {
            phase = .finished
        }
    }

    /// Découpe une définition en parties distinctes sur les séparateurs , / ; —
    /// Exemple : "aller, venir / partir" → ["aller", "venir", "partir"]
    private static func splitDefinitions(_ text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",/;—")
        let parts = text.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? [text] : parts
    }

    private func speakIfNotCancelled(_ text: String, voice: AVSpeechSynthesisVoice?) async {
        guard !Task.isCancelled, !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = 0.42
        utterance.pitchMultiplier = 0.95
        utterance.volume = 1.0
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            utteranceFinishedContinuation = continuation
            synthesizer.speak(utterance)
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension MemorizationSpeaker: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.utteranceFinishedContinuation?.resume()
            self?.utteranceFinishedContinuation = nil
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.utteranceFinishedContinuation?.resume()
            self?.utteranceFinishedContinuation = nil
        }
    }
}

// MARK: - MemorizationView

struct MemorizationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // All words from store passed in
    let allWords: [WordModel]

    // Settings persistence
    @AppStorage("mem.categoryRaw")   private var categoryRaw:   String = ""
    @AppStorage("mem.selectedSurah") private var selectedSurah: Int    = 0  // 0 = toutes
    @AppStorage("mem.repetitions")   private var repetitions:   Int    = 2
    @AppStorage("mem.pauseIndex")    private var pauseIndex:     Int    = 1  // index into pauseOptions
    @AppStorage("mem.loop")          private var loop:           Bool   = false

    // Speaker
    @State private var speaker = MemorizationSpeaker()
    @State private var phase: ViewPhase = .settings

    private enum ViewPhase { case settings, playing }

    // MARK: Pause options
    private let pauseOptions: [(label: String, value: Double)] = [
        ("0.5 s", 0.5), ("1 s", 1.0), ("1.5 s", 1.5), ("2 s", 2.0), ("3 s", 3.0)
    ]

    // MARK: Category
    private var selectedCategory: WordCategory? {
        WordCategory(rawValue: categoryRaw)
    }

    private var filteredWords: [WordModel] {
        var result = allWords
        // Filtre catégorie
        if let cat = selectedCategory {
            result = result.filter { $0.category == cat }
        }
        // Filtre sourate — exclut les mots ubiquitaires [0] et non-assignés []
        if selectedSurah != 0 {
            result = result.filter { $0.surahNumbers.contains(selectedSurah) }
        }
        return result
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            Group {
                if phase == .settings {
                    settingsView
                } else {
                    playerView
                }
            }
            .navigationTitle("Mémorisation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        speaker.stop()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Settings Phase

    private var settingsView: some View {
        Form {
            // Filtres section
            Section(header: Text("Liste de mots")) {
                // Catégorie
                Picker("Catégorie", selection: $categoryRaw) {
                    Text("Toutes les catégories").tag("")
                    ForEach(WordCategory.allCases, id: \.rawValue) { cat in
                        let count = allWords.filter { $0.category == cat }.count
                        Text("\(cat.rawValue) (\(count))").tag(cat.rawValue)
                    }
                }
                .pickerStyle(.navigationLink)

                // Sourate
                NavigationLink {
                    SurahPickerView(selectedSurah: $selectedSurah)
                } label: {
                    HStack {
                        Label("Sourate", systemImage: "book.closed")
                        Spacer()
                        if selectedSurah == 0 {
                            Text("Toutes")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("S.\(selectedSurah) — \(SurahInfo.name(for: selectedSurah))")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Effacer filtre sourate si actif
                if selectedSurah != 0 {
                    Button(role: .destructive) {
                        selectedSurah = 0
                    } label: {
                        Label("Retirer le filtre sourate", systemImage: "xmark.circle")
                    }
                }

                // Résumé
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                    Text("\(filteredWords.count) mot\(filteredWords.count == 1 ? "" : "s") sélectionné\(filteredWords.count == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }

            // Repetitions section
            Section(header: Text("Répétitions par mot")) {
                Picker("Répétitions", selection: $repetitions) {
                    Text("1×").tag(1)
                    Text("2×").tag(2)
                    Text("3×").tag(3)
                    Text("5×").tag(5)
                }
                .pickerStyle(.segmented)
            }

            // Pause section
            Section(header: Text("Pause entre les répétitions")) {
                Picker("Pause", selection: $pauseIndex) {
                    ForEach(pauseOptions.indices, id: \.self) { i in
                        Text(pauseOptions[i].label).tag(i)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Loop section
            Section {
                Toggle("Lecture en boucle", isOn: $loop)
            } footer: {
                Text("Répète la liste indéfiniment jusqu'à l'arrêt manuel.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // Start button
            Section {
                Button(action: startPlayback) {
                    HStack {
                        Spacer()
                        Image(systemName: "headphones")
                        Text("Démarrer la mémorisation")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .disabled(filteredWords.isEmpty)
                .foregroundStyle(filteredWords.isEmpty ? .secondary : Color.accentColor)
            }
        }
    }

    // MARK: - Player Phase

    private var playerView: some View {
        VStack(spacing: 0) {
            // Progress bar
            if !speaker.words.isEmpty {
                ProgressView(value: Double(speaker.currentWordIndex + 1),
                             total: Double(speaker.words.count))
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            Spacer()

            // Word card
            if let word = speaker.currentWord {
                wordCard(word)
            } else if speaker.phase == .finished {
                finishedCard
            } else {
                ProgressView()
                    .scaleEffect(1.5)
            }

            Spacer()

            // Controls
            controlBar

            // Info footer
            if !speaker.words.isEmpty && speaker.currentWord != nil {
                Text("Mot \(speaker.currentWordIndex + 1) / \(speaker.words.count)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
        }
        .onChange(of: speaker.phase) { _, newPhase in
            if newPhase == .finished && !loop {
                // keep player visible, show finished card
            }
        }
    }

    private func wordCard(_ word: WordModel) -> some View {
        VStack(spacing: 20) {
            // Repetition badge
            if speaker.repetitions > 1 {
                Text("Répétition \(speaker.currentRepetition) / \(speaker.repetitions)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }

            // Arabic
            Text(word.arabic)
                .font(.system(size: 52, weight: .bold, design: .default))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .padding(.horizontal)

            // Transliteration
            if !word.transliteration.isEmpty {
                Text(word.transliteration)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .italic()
            }

            // French meaning
            if !word.meaning.isEmpty {
                Text(word.meaning)
                    .font(.title2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .padding(.horizontal)
            }

            // Category chip
            if !word.category.rawValue.isEmpty {
                Text(word.category.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
        .id(word.id)
        .animation(.easeInOut(duration: 0.3), value: word.id)
    }

    private var finishedCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Mémorisation terminée")
                .font(.title2)
                .fontWeight(.semibold)
            Text("\(speaker.words.count) mot\(speaker.words.count == 1 ? "" : "s") parcouru\(speaker.words.count == 1 ? "" : "s")")
                .foregroundStyle(.secondary)
        }
        .padding(32)
    }

    private var controlBar: some View {
        HStack(spacing: 32) {
            // Stop
            Button {
                speaker.stop()
                phase = .settings
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title2)
                    .frame(width: 56, height: 56)
                    .background(.quaternary, in: Circle())
            }
            .foregroundStyle(.primary)

            // Play / Pause
            Button {
                switch speaker.phase {
                case .playing:
                    speaker.pause()
                case .paused:
                    speaker.play()
                case .finished:
                    restartPlayback()
                default:
                    speaker.play()
                }
            } label: {
                Image(systemName: playPauseIcon)
                    .font(.system(size: 28, weight: .semibold))
                    .frame(width: 72, height: 72)
                    .background(Color.accentColor, in: Circle())
                    .foregroundStyle(.white)
            }

            // Restart
            Button {
                restartPlayback()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title2)
                    .frame(width: 56, height: 56)
                    .background(.quaternary, in: Circle())
            }
            .foregroundStyle(.primary)
        }
        .padding(.vertical, 24)
    }

    private var playPauseIcon: String {
        switch speaker.phase {
        case .playing: return "pause.fill"
        case .finished: return "arrow.counterclockwise"
        default: return "play.fill"
        }
    }

    // MARK: - Actions

    private func startPlayback() {
        let words = filteredWords.shuffled()
        speaker.words = words
        speaker.repetitions = repetitions
        speaker.pauseSeconds = pauseOptions[min(pauseIndex, pauseOptions.count - 1)].value
        speaker.loop = loop
        phase = .playing
        speaker.play()
    }

    private func restartPlayback() {
        speaker.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            speaker.play()
        }
    }
}
