// WordDetailView.swift
// CoranLexique — iOS 17+ · Détail du mot + validation de la compréhension
//
// Cette vue sert à la fois de fiche de révision et d'outil de validation manuelle.
// L'utilisateur peut y tester sa lecture/compréhension avant de valider son niveau.

import SwiftUI
import SwiftData
import AVFoundation

// MARK: - Niveau de maîtrise (pour l'affichage)

private extension Int {
    /// Libellé textuel du niveau de maîtrise (0–4)
    var masteryLabel: String {
        switch self {
        case 0:  return "Nouveau"
        case 1:  return "Débutant"
        case 2:  return "Intermédiaire"
        case 3:  return "Avancé"
        default: return "Maîtrisé"
        }
    }

    /// Icône SF Symbols associée au niveau
    var masteryIcon: String {
        switch self {
        case 0:  return "circle"
        case 1:  return "circle.fill"
        case 2:  return "circle.fill"
        case 3:  return "star.fill"
        default: return "checkmark.seal.fill"
        }
    }

    /// Couleur du niveau
    var masteryColor: Color {
        switch self {
        case 0:  return .gray
        case 1:  return .red.opacity(0.85)
        case 2:  return .orange
        case 3:  return .yellow
        default: return .green
        }
    }
}

// MARK: - WordReader

/// Lecture vocale one-shot d'un mot arabe.
@Observable
@MainActor
final class WordReader: NSObject, AVSpeechSynthesizerDelegate {
    private(set) var isSpeaking = false
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ arabic: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: arabic)
        utterance.voice = preferredArabicVoice()
        utterance.rate  = 0.38
        utterance.pitchMultiplier = 0.95
        utterance.volume = 1.0
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    private func preferredArabicVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix("ar") && $0.gender == .male
        }
        let best = voices.max { lhs, rhs in
            qualityRank(lhs.quality) < qualityRank(rhs.quality)
        }
        return best ?? AVSpeechSynthesisVoice(language: "ar-SA")
    }

    private func qualityRank(_ q: AVSpeechSynthesisVoiceQuality) -> Int {
        switch q {
        case .enhanced: return 2
        case .default:  return 1
        default:        return 0
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}

// MARK: - WordDetailView

struct WordDetailView: View {
    @Bindable var word: WordModel
    @Environment(\.modelContext) private var modelContext

    /// Contrôle l'affichage du sens (auto-test)
    @State private var isMeaningRevealed: Bool = false
    @State private var flashColor: Color = .clear
    @State private var bouncePositive: Bool = false
    @State private var bounceNegative: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // ── En-tête arabe ─────────────────────────────────────────
                ArabicHeaderCard(word: word)

                // ── Auto-test : cacher/révéler le sens ───────────────────
                SelfTestSection(
                    word:              word,
                    isMeaningRevealed: $isMeaningRevealed
                )

                // ── Validation de la compréhension ───────────────────────
                if isMeaningRevealed {
                    ValidationSection(
                        word:            word,
                        onKnow:          { handleValidation(knew: true) },
                        onReview:        { handleValidation(knew: false) },
                        bouncePositive:  bouncePositive,
                        bounceNegative:  bounceNegative
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // ── Informations linguistiques ────────────────────────────
                LinguisticInfoSection(word: word)

                // ── Progression globale du mot ────────────────────────────
                MasteryHistorySection(word: word)

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        // Flash de feedback (vert / rouge) sur tout l'écran
        .background(flashColor.ignoresSafeArea().animation(.easeOut(duration: 0.5), value: flashColor))
        .navigationTitle(word.transliteration)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: word.masteryLevel) { _, _ in
            isMeaningRevealed = false  // Réinitialise pour la prochaine session
        }
    }

    // MARK: - Validation manuelle

    private func handleValidation(knew: Bool) {
        let oldLevel = word.masteryLevel

        if knew {
            word.masteryLevel = min(4, oldLevel + 1)
            flashColor = .green.opacity(0.12)
            bouncePositive = true
        } else {
            word.masteryLevel = max(0, oldLevel - 1)
            flashColor = .red.opacity(0.12)
            bounceNegative = true
        }

        try? modelContext.save()

        // Efface le flash après 0.6 s
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation { flashColor = .clear }
            bouncePositive = false
            bounceNegative = false
        }
    }
}

// MARK: - ArabicHeaderCard

private struct ArabicHeaderCard: View {
    let word: WordModel
    @State private var reader = WordReader()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Contenu centré
            VStack(spacing: 10) {
                CategoryBadgeView(category: word.category)

                Text(word.arabic)
                    .font(.system(size: 72, weight: .bold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .environment(\.layoutDirection, .rightToLeft)

                Text(word.transliteration)
                    .font(.title2)
                    .italic()
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)

            // Bouton lecture — coin supérieur droit
            Button {
                reader.speak(word.arabic)
            } label: {
                Image(systemName: reader.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                    .font(.body.weight(.medium))
                    .symbolEffect(.variableColor.iterative, isActive: reader.isSpeaking)
                    .foregroundStyle(reader.isSpeaking ? Color.accentColor : .secondary)
                    .frame(width: 36, height: 36)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(14)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - SelfTestSection

private struct SelfTestSection: View {
    let word:              WordModel
    @Binding var isMeaningRevealed: Bool

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Test de lecture", systemImage: "eye")
                    .font(.headline)
                Spacer()
                if isMeaningRevealed {
                    Button {
                        withAnimation(.spring(response: 0.3)) { isMeaningRevealed = false }
                    } label: {
                        Image(systemName: "eye.slash")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Zone sens — masquée jusqu'au tap
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    isMeaningRevealed = true
                }
            } label: {
                Group {
                    if isMeaningRevealed {
                        VStack(spacing: 6) {
                            Text(word.meaning)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.primary)
                        }
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                    } else {
                        HStack {
                            Image(systemName: "eye.fill")
                            Text("Appuie pour révéler le sens")
                                .font(.body)
                        }
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 64)
                .padding()
                .background(isMeaningRevealed
                    ? Color(.tertiarySystemBackground)
                    : Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    if !isMeaningRevealed {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1.5)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isMeaningRevealed)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - ValidationSection

private struct ValidationSection: View {
    let word:           WordModel
    let onKnow:         () -> Void
    let onReview:       () -> Void
    let bouncePositive: Bool
    let bounceNegative: Bool

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Validation", systemImage: "checkmark.seal")
                    .font(.headline)
                Spacer()
                Text("Niveau actuel : \(word.masteryLevel.masteryLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Est-ce que tu connais ce mot ?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                // Bouton "À retravailler"
                Button(action: onReview) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("À retravailler")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.12))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .scaleEffect(bounceNegative ? 0.94 : 1.0)
                .animation(.spring(response: 0.25), value: bounceNegative)
                .disabled(word.masteryLevel == 0)
                .opacity(word.masteryLevel == 0 ? 0.45 : 1)

                // Bouton "Je connais"
                Button(action: onKnow) {
                    HStack {
                        Image(systemName: "hand.thumbsup.fill")
                        Text("Je connais !")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .scaleEffect(bouncePositive ? 0.94 : 1.0)
                .animation(.spring(response: 0.25), value: bouncePositive)
                .disabled(word.masteryLevel == 4)
                .opacity(word.masteryLevel == 4 ? 0.45 : 1)
            }

            // Indicateur de progression à 5 niveaux
            MasteryLevelStepper(currentLevel: word.masteryLevel)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - MasteryLevelStepper

private struct MasteryLevelStepper: View {
    let currentLevel: Int
    private let levels = [0, 1, 2, 3, 4]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(levels, id: \.self) { level in
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(level <= currentLevel ? level.masteryColor : Color(.systemFill))
                            .frame(width: 28, height: 28)
                        if level <= currentLevel {
                            Image(systemName: level.masteryIcon)
                                .font(.caption2)
                                .foregroundStyle(.white)
                        }
                    }
                    Text(level.masteryLabel)
                        .font(.system(size: 9))
                        .foregroundStyle(level == currentLevel ? .primary : .tertiary)
                        .fontWeight(level == currentLevel ? .semibold : .regular)
                }
                .frame(maxWidth: .infinity)

                if level < 4 {
                    Rectangle()
                        .fill(level < currentLevel ? currentLevel.masteryColor : Color(.systemFill))
                        .frame(height: 2)
                        .offset(y: -10)
                }
            }
        }
        .padding(.top, 4)
        .animation(.easeInOut(duration: 0.3), value: currentLevel)
    }
}

// MARK: - LinguisticInfoSection

private struct LinguisticInfoSection: View {
    let word: WordModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Informations linguistiques", systemImage: "text.book.closed")
                .font(.headline)

            VStack(spacing: 10) {
                InfoRow(label: "Catégorie",        value: word.category.rawValue,  icon: word.category.systemIcon)
                InfoRow(label: "Translittération", value: word.transliteration,    icon: "character.phonetic")
                if !word.root.isEmpty {
                    InfoRow(label: "Racine",        value: word.root,               icon: "tree.fill")
                }
                InfoRow(label: "Fréquence",
                        value: "×\(word.frequency) occurrences dans le Coran",
                        icon: "repeat")
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    let icon:  String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - MasteryHistorySection

private struct MasteryHistorySection: View {
    let word: WordModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Niveau de maîtrise", systemImage: "chart.bar.fill")
                .font(.headline)

            HStack(alignment: .center, spacing: 16) {
                // Icône principale
                ZStack {
                    Circle()
                        .fill(word.masteryLevel.masteryColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: word.masteryLevel.masteryIcon)
                        .font(.title2)
                        .foregroundStyle(word.masteryLevel.masteryColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(word.masteryLevel.masteryLabel)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(masteryDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                MasteryDots(level: word.masteryLevel)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var masteryDescription: String {
        switch word.masteryLevel {
        case 0: return "Pas encore rencontré en quiz"
        case 1: return "Reconnu une fois"
        case 2: return "En cours d'apprentissage"
        case 3: return "Bien assimilé"
        default: return "Pleinement maîtrisé"
        }
    }
}

// MARK: - WordPagerView
// Conteneur de navigation par swipe dans la liste courante.

struct WordPagerView: View {
    let words: [WordModel]
    @State private var selection: Int

    init(words: [WordModel], startIndex: Int) {
        self.words = words
        self._selection = State(initialValue: startIndex)
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(Array(words.enumerated()), id: \.element.id) { index, word in
                WordDetailView(word: word)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text("\(selection + 1) / \(words.count)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
