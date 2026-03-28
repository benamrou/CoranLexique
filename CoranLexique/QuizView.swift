// QuizView.swift
// CoranLexique — iOS 17+ · Système de quiz & assimilation
//
// Flux UX :
//   1. Paramètres  — l'utilisateur configure le quiz (nb questions, catégorie, focus).
//   2. Quiz        — questions à choix multiples avec feedback animé.
//   3. Résultat    — score + récap + option de réviser les mots manqués.

import SwiftUI
import SwiftData

// MARK: - SurahInfo

struct SurahInfo: Identifiable {
    let id:     Int
    let name:   String
    let arabic: String

    static func name(for number: Int) -> String {
        all.first { $0.id == number }?.name ?? "Sourate \(number)"
    }

    // swiftlint:disable line_length
    static let all: [SurahInfo] = [
        SurahInfo(id:   1, name: "Al-Fatiha",       arabic: "الفاتحة"),
        SurahInfo(id:   2, name: "Al-Baqara",        arabic: "البقرة"),
        SurahInfo(id:   3, name: "Âl 'Imran",        arabic: "آل عمران"),
        SurahInfo(id:   4, name: "An-Nisa",           arabic: "النساء"),
        SurahInfo(id:   5, name: "Al-Maïda",          arabic: "المائدة"),
        SurahInfo(id:   6, name: "Al-An'am",          arabic: "الأنعام"),
        SurahInfo(id:   7, name: "Al-A'raf",          arabic: "الأعراف"),
        SurahInfo(id:   8, name: "Al-Anfal",          arabic: "الأنفال"),
        SurahInfo(id:   9, name: "At-Tawba",          arabic: "التوبة"),
        SurahInfo(id:  10, name: "Yunus",             arabic: "يونس"),
        SurahInfo(id:  11, name: "Hud",               arabic: "هود"),
        SurahInfo(id:  12, name: "Yusuf",             arabic: "يوسف"),
        SurahInfo(id:  13, name: "Ar-Ra'd",           arabic: "الرعد"),
        SurahInfo(id:  14, name: "Ibrahim",           arabic: "إبراهيم"),
        SurahInfo(id:  15, name: "Al-Hijr",           arabic: "الحجر"),
        SurahInfo(id:  16, name: "An-Nahl",           arabic: "النحل"),
        SurahInfo(id:  17, name: "Al-Isra",           arabic: "الإسراء"),
        SurahInfo(id:  18, name: "Al-Kahf",           arabic: "الكهف"),
        SurahInfo(id:  19, name: "Maryam",            arabic: "مريم"),
        SurahInfo(id:  20, name: "Taha",              arabic: "طه"),
        SurahInfo(id:  21, name: "Al-Anbiya",         arabic: "الأنبياء"),
        SurahInfo(id:  22, name: "Al-Hajj",           arabic: "الحج"),
        SurahInfo(id:  23, name: "Al-Mu'minun",       arabic: "المؤمنون"),
        SurahInfo(id:  24, name: "An-Nur",            arabic: "النور"),
        SurahInfo(id:  25, name: "Al-Furqan",         arabic: "الفرقان"),
        SurahInfo(id:  26, name: "Ash-Shu'ara",       arabic: "الشعراء"),
        SurahInfo(id:  27, name: "An-Naml",           arabic: "النمل"),
        SurahInfo(id:  28, name: "Al-Qasas",          arabic: "القصص"),
        SurahInfo(id:  29, name: "Al-'Ankabut",       arabic: "العنكبوت"),
        SurahInfo(id:  30, name: "Ar-Rum",            arabic: "الروم"),
        SurahInfo(id:  31, name: "Luqman",            arabic: "لقمان"),
        SurahInfo(id:  32, name: "As-Sajda",          arabic: "السجدة"),
        SurahInfo(id:  33, name: "Al-Ahzab",          arabic: "الأحزاب"),
        SurahInfo(id:  34, name: "Saba'",             arabic: "سبأ"),
        SurahInfo(id:  35, name: "Fatir",             arabic: "فاطر"),
        SurahInfo(id:  36, name: "Ya-Sin",            arabic: "يس"),
        SurahInfo(id:  37, name: "As-Saffat",         arabic: "الصافات"),
        SurahInfo(id:  38, name: "Sad",               arabic: "ص"),
        SurahInfo(id:  39, name: "Az-Zumar",          arabic: "الزمر"),
        SurahInfo(id:  40, name: "Ghafir",            arabic: "غافر"),
        SurahInfo(id:  41, name: "Fussilat",          arabic: "فصلت"),
        SurahInfo(id:  42, name: "Ash-Shura",         arabic: "الشورى"),
        SurahInfo(id:  43, name: "Az-Zukhruf",        arabic: "الزخرف"),
        SurahInfo(id:  44, name: "Ad-Dukhan",         arabic: "الدخان"),
        SurahInfo(id:  45, name: "Al-Jathiya",        arabic: "الجاثية"),
        SurahInfo(id:  46, name: "Al-Ahqaf",          arabic: "الأحقاف"),
        SurahInfo(id:  47, name: "Muhammad",          arabic: "محمد"),
        SurahInfo(id:  48, name: "Al-Fath",           arabic: "الفتح"),
        SurahInfo(id:  49, name: "Al-Hujurat",        arabic: "الحجرات"),
        SurahInfo(id:  50, name: "Qaf",               arabic: "ق"),
        SurahInfo(id:  51, name: "Adh-Dhariyat",      arabic: "الذاريات"),
        SurahInfo(id:  52, name: "At-Tur",            arabic: "الطور"),
        SurahInfo(id:  53, name: "An-Najm",           arabic: "النجم"),
        SurahInfo(id:  54, name: "Al-Qamar",          arabic: "القمر"),
        SurahInfo(id:  55, name: "Ar-Rahman",         arabic: "الرحمن"),
        SurahInfo(id:  56, name: "Al-Waqi'a",         arabic: "الواقعة"),
        SurahInfo(id:  57, name: "Al-Hadid",          arabic: "الحديد"),
        SurahInfo(id:  58, name: "Al-Mujadila",       arabic: "المجادلة"),
        SurahInfo(id:  59, name: "Al-Hashr",          arabic: "الحشر"),
        SurahInfo(id:  60, name: "Al-Mumtahana",      arabic: "الممتحنة"),
        SurahInfo(id:  61, name: "As-Saf",            arabic: "الصف"),
        SurahInfo(id:  62, name: "Al-Jumu'a",         arabic: "الجمعة"),
        SurahInfo(id:  63, name: "Al-Munafiqun",      arabic: "المنافقون"),
        SurahInfo(id:  64, name: "At-Taghabun",       arabic: "التغابن"),
        SurahInfo(id:  65, name: "At-Talaq",          arabic: "الطلاق"),
        SurahInfo(id:  66, name: "At-Tahrim",         arabic: "التحريم"),
        SurahInfo(id:  67, name: "Al-Mulk",           arabic: "الملك"),
        SurahInfo(id:  68, name: "Al-Qalam",          arabic: "القلم"),
        SurahInfo(id:  69, name: "Al-Haqqa",          arabic: "الحاقة"),
        SurahInfo(id:  70, name: "Al-Ma'arij",        arabic: "المعارج"),
        SurahInfo(id:  71, name: "Nuh",               arabic: "نوح"),
        SurahInfo(id:  72, name: "Al-Jinn",           arabic: "الجن"),
        SurahInfo(id:  73, name: "Al-Muzzammil",      arabic: "المزمل"),
        SurahInfo(id:  74, name: "Al-Muddathir",      arabic: "المدثر"),
        SurahInfo(id:  75, name: "Al-Qiyama",         arabic: "القيامة"),
        SurahInfo(id:  76, name: "Al-Insan",          arabic: "الإنسان"),
        SurahInfo(id:  77, name: "Al-Mursalat",       arabic: "المرسلات"),
        SurahInfo(id:  78, name: "An-Naba'",          arabic: "النبأ"),
        SurahInfo(id:  79, name: "An-Nazi'at",        arabic: "النازعات"),
        SurahInfo(id:  80, name: "Abasa",             arabic: "عبس"),
        SurahInfo(id:  81, name: "At-Takwir",         arabic: "التكوير"),
        SurahInfo(id:  82, name: "Al-Infitar",        arabic: "الانفطار"),
        SurahInfo(id:  83, name: "Al-Mutaffifin",     arabic: "المطففين"),
        SurahInfo(id:  84, name: "Al-Inshiqaq",       arabic: "الانشقاق"),
        SurahInfo(id:  85, name: "Al-Buruj",          arabic: "البروج"),
        SurahInfo(id:  86, name: "At-Tariq",          arabic: "الطارق"),
        SurahInfo(id:  87, name: "Al-A'la",           arabic: "الأعلى"),
        SurahInfo(id:  88, name: "Al-Ghashiya",       arabic: "الغاشية"),
        SurahInfo(id:  89, name: "Al-Fajr",           arabic: "الفجر"),
        SurahInfo(id:  90, name: "Al-Balad",          arabic: "البلد"),
        SurahInfo(id:  91, name: "Ash-Shams",         arabic: "الشمس"),
        SurahInfo(id:  92, name: "Al-Layl",           arabic: "الليل"),
        SurahInfo(id:  93, name: "Ad-Duha",           arabic: "الضحى"),
        SurahInfo(id:  94, name: "Ash-Sharh",         arabic: "الشرح"),
        SurahInfo(id:  95, name: "At-Tin",            arabic: "التين"),
        SurahInfo(id:  96, name: "Al-'Alaq",          arabic: "العلق"),
        SurahInfo(id:  97, name: "Al-Qadr",           arabic: "القدر"),
        SurahInfo(id:  98, name: "Al-Bayyina",        arabic: "البينة"),
        SurahInfo(id:  99, name: "Az-Zalzala",        arabic: "الزلزلة"),
        SurahInfo(id: 100, name: "Al-'Adiyat",        arabic: "العاديات"),
        SurahInfo(id: 101, name: "Al-Qari'a",         arabic: "القارعة"),
        SurahInfo(id: 102, name: "At-Takathur",       arabic: "التكاثر"),
        SurahInfo(id: 103, name: "Al-'Asr",           arabic: "العصر"),
        SurahInfo(id: 104, name: "Al-Humaza",         arabic: "الهمزة"),
        SurahInfo(id: 105, name: "Al-Fil",            arabic: "الفيل"),
        SurahInfo(id: 106, name: "Quraysh",           arabic: "قريش"),
        SurahInfo(id: 107, name: "Al-Ma'un",          arabic: "الماعون"),
        SurahInfo(id: 108, name: "Al-Kawthar",        arabic: "الكوثر"),
        SurahInfo(id: 109, name: "Al-Kafirun",        arabic: "الكافرون"),
        SurahInfo(id: 110, name: "An-Nasr",           arabic: "النصر"),
        SurahInfo(id: 111, name: "Al-Masad",          arabic: "المسد"),
        SurahInfo(id: 112, name: "Al-Ikhlas",         arabic: "الإخلاص"),
        SurahInfo(id: 113, name: "Al-Falaq",          arabic: "الفلق"),
        SurahInfo(id: 114, name: "An-Nas",            arabic: "الناس"),
    ]
    // swiftlint:enable line_length
}

// MARK: - QuizFocusMode

enum QuizFocusMode: String, CaseIterable, Identifiable {
    case all  = "Tous les mots"
    case weak = "À retravailler"      // masteryLevel < 3
    case new  = "Nouveaux seulement"  // masteryLevel == 0

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all:  return "square.grid.2x2.fill"
        case .weak: return "exclamationmark.circle.fill"
        case .new:  return "circle"
        }
    }
}

// MARK: - QuizQuestion (modèle en mémoire, non persisté)

struct QuizQuestion: Identifiable {
    let id      = UUID()
    let word:     WordModel
    let choices:  [String]
    let correct:  String

    /// Construit N questions en privilégiant les mots peu maîtrisés.
    static func build(from words: [WordModel], count: Int = 10) -> [QuizQuestion] {
        guard words.count >= 4 else { return [] }

        let n           = min(count, words.count)
        let nLow        = Int(Double(n) * 0.7)
        let lowMastery  = Array(words.filter { $0.masteryLevel < 3 }.shuffled().prefix(nLow))
        let highMastery = Array(words.filter { $0.masteryLevel >= 3 }.shuffled().prefix(n - lowMastery.count))
        var selected    = (lowMastery + highMastery)
        // Si la répartition 70/30 ne suffit pas (tous les mots au même niveau),
        // compléter avec les mots restants pour atteindre n questions.
        if selected.count < n {
            let usedIDs = Set(selected.map { $0.id })
            let extra   = words.filter { !usedIDs.contains($0.id) }.shuffled().prefix(n - selected.count)
            selected   += extra
        }
        selected = selected.shuffled()

        return selected.map { word in
            let wrongs  = words.filter { $0.id != word.id }.shuffled().prefix(3).map { $0.meaning }
            let choices = ([word.meaning] + wrongs).shuffled()
            return QuizQuestion(word: word, choices: choices, correct: word.meaning)
        }
    }
}

// MARK: - QuizView

struct QuizView: View {
    let words: [WordModel]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    // ── Réglages persistés ─────────────────────────────────────────────────
    @AppStorage("quiz.questionCount")  private var questionCount:  Int    = 10
    @AppStorage("quiz.focusModeRaw")   private var focusModeRaw:   String = QuizFocusMode.all.rawValue
    @AppStorage("quiz.categoryRaw")    private var categoryRaw:    String = ""
    @AppStorage("quiz.selectedSurah")  private var selectedSurah:  Int    = 0  // 0 = toutes

    // ── Phase ──────────────────────────────────────────────────────────────
    private enum QuizPhase: Equatable { case settings, playing, finished }
    @State private var phase: QuizPhase = .settings

    // ── État du quiz ───────────────────────────────────────────────────────
    @State private var questions:      [QuizQuestion] = []
    @State private var currentIndex:   Int    = 0
    @State private var selectedAnswer: String? = nil
    @State private var showFeedback:   Bool   = false
    @State private var score:          Int    = 0
    @State private var wrongWords:     [WordModel] = []

    // ── Réglages calculés ─────────────────────────────────────────────────
    private var focusMode: QuizFocusMode {
        QuizFocusMode(rawValue: focusModeRaw) ?? .all
    }
    private var categoryFilter: WordCategory? {
        categoryRaw.isEmpty ? nil : WordCategory(rawValue: categoryRaw)
    }
    private var eligibleWords: [WordModel] {
        var result = words
        if let cat = categoryFilter {
            result = result.filter { $0.category == cat }
        }
        if selectedSurah != 0 {
            result = result.filter { $0.surahNumbers.contains(selectedSurah) }
        }
        switch focusMode {
        case .all:  break
        case .weak: result = result.filter { $0.masteryLevel < 3 }
        case .new:  result = result.filter { $0.masteryLevel == 0 }
        }
        return result
    }
    private var currentQuestion: QuizQuestion? {
        currentIndex < questions.count ? questions[currentIndex] : nil
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .settings:
                    settingsBody
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal:   .move(edge: .leading).combined(with: .opacity)
                        ))
                case .playing:
                    playingBody
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal:   .opacity
                        ))
                case .finished:
                    QuizSummaryView(
                        score:         score,
                        questions:     questions,
                        wrongWords:    wrongWords,
                        onRestart:     { launchQuiz(from: eligibleWords) },
                        onRetryMissed: { launchQuiz(from: wrongWords) },
                        onDismiss:     { dismiss() }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .opacity
                    ))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: phase)
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Quitter") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var navTitle: String {
        switch phase {
        case .settings: return "Paramètres"
        case .playing:  return "Quiz"
        case .finished: return "Résultat"
        }
    }

    // MARK: - Settings body

    private var settingsBody: some View {
        Form {

            // ── Nombre de questions ────────────────────────────────────────
            Section("Nombre de questions") {
                Picker("Questions", selection: $questionCount) {
                    ForEach([5, 10, 15, 20, 30, 50], id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                .pickerStyle(.segmented)
            }

            // ── Filtre par catégorie ───────────────────────────────────────
            Section("Catégorie") {
                Picker("Catégorie", selection: $categoryRaw) {
                    Text("Toutes").tag("")
                    ForEach(WordCategory.allCases) { cat in
                        Label(cat.rawValue, systemImage: cat.systemIcon).tag(cat.rawValue)
                    }
                }
            }

            // ── Mode de focus ──────────────────────────────────────────────
            Section("Mode de focus") {
                Picker("Focus", selection: $focusModeRaw) {
                    ForEach(QuizFocusMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.icon).tag(mode.rawValue)
                    }
                }
            }

            // ── Par sourate ────────────────────────────────────────────────
            Section("Par sourate") {
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
                                .lineLimit(1)
                        }
                    }
                }
                if selectedSurah != 0 {
                    Button {
                        selectedSurah = 0
                    } label: {
                        Label("Effacer le filtre sourate", systemImage: "xmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
            }

            // ── Résumé + lancement ─────────────────────────────────────────
            Section {
                let count    = eligibleWords.count
                let planned  = min(questionCount, count)
                let canStart = count >= 4

                HStack {
                    Label("Questions prévues", systemImage: "questionmark.circle")
                    Spacer()
                    Text(canStart ? "\(planned)" : "Pas assez de mots")
                        .fontWeight(.semibold)
                        .foregroundStyle(canStart ? Color.primary : Color.red)
                }

                Button {
                    launchQuiz(from: eligibleWords)
                } label: {
                    Label("Lancer le quiz", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canStart)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }
        }
    }

    // MARK: - Playing body

    @ViewBuilder
    private var playingBody: some View {
        if questions.isEmpty {
            NotEnoughWordsView { dismiss() }
        } else if let question = currentQuestion {
            VStack(spacing: 0) {
                QuizProgressHeader(
                    current: currentIndex + 1,
                    total:   questions.count,
                    score:   score
                )
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                QuizCardView(
                    question:       question,
                    selectedAnswer: $selectedAnswer,
                    showFeedback:   showFeedback,
                    onSelect:       { answer in selectAnswer(answer, for: question) }
                )
                .padding(.horizontal, 20)

                Spacer()

                if showFeedback {
                    Button(action: nextQuestion) {
                        HStack {
                            Text(currentIndex + 1 < questions.count
                                 ? "Question suivante"
                                 : "Voir mon résultat")
                            Image(systemName: "arrow.right")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .id(currentIndex)
        }
    }

    // MARK: - Actions

    private func launchQuiz(from sourceWords: [WordModel]) {
        questions      = QuizQuestion.build(from: sourceWords, count: questionCount)
        currentIndex   = 0
        score          = 0
        wrongWords     = []
        selectedAnswer = nil
        showFeedback   = false
        withAnimation(.easeInOut(duration: 0.3)) { phase = .playing }
    }

    private func selectAnswer(_ answer: String, for question: QuizQuestion) {
        guard !showFeedback else { return }
        selectedAnswer = answer

        let correct = answer == question.correct
        if correct {
            score += 1
        } else if !wrongWords.contains(where: { $0.id == question.word.id }) {
            wrongWords.append(question.word)
        }

        let word = question.word
        word.masteryLevel = correct
            ? min(4, word.masteryLevel + 1)
            : max(0, word.masteryLevel - 1)
        try? modelContext.save()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            showFeedback = true
        }
    }

    private func nextQuestion() {
        let isLast = currentIndex + 1 >= questions.count
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            selectedAnswer = nil
            showFeedback   = false
            if isLast {
                phase = .finished
            } else {
                currentIndex += 1
            }
        }
    }
}

// MARK: - QuizProgressHeader

private struct QuizProgressHeader: View {
    let current: Int
    let total:   Int
    let score:   Int

    private var progress: Double { Double(current) / Double(total) }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Question \(current) / \(total)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    Text("\(score)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemFill)).frame(height: 6)
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - QuizCardView

private struct QuizCardView: View {
    let question:       QuizQuestion
    @Binding var selectedAnswer: String?
    let showFeedback:   Bool
    let onSelect:       (String) -> Void

    var body: some View {
        VStack(spacing: 24) {

            VStack(spacing: 8) {
                Text("Que signifie ce mot ?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(question.word.arabic)
                    .font(.system(size: 56, weight: .bold, design: .default))
                    .environment(\.layoutDirection, .rightToLeft)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(question.word.transliteration)
                    .font(.title3)
                    .italic()
                    .foregroundStyle(.secondary)

                if !question.word.root.isEmpty {
                    Label(question.word.root, systemImage: "tree.fill")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 20)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(spacing: 12) {
                ForEach(question.choices, id: \.self) { choice in
                    ChoiceButton(
                        text:  choice,
                        state: buttonState(for: choice),
                        onTap: { onSelect(choice) }
                    )
                }
            }
        }
    }

    private func buttonState(for choice: String) -> ChoiceButtonState {
        guard showFeedback else {
            return selectedAnswer == choice ? .selected : .idle
        }
        if choice == question.correct { return .correct }
        if choice == selectedAnswer   { return .wrong }
        return .dimmed
    }
}

// MARK: - ChoiceButton

private enum ChoiceButtonState { case idle, selected, correct, wrong, dimmed }

private struct ChoiceButton: View {
    let text:  String
    let state: ChoiceButtonState
    let onTap: () -> Void

    private var bgColor: Color {
        switch state {
        case .idle:     return Color(.secondarySystemBackground)
        case .selected: return Color.accentColor.opacity(0.15)
        case .correct:  return Color.green.opacity(0.18)
        case .wrong:    return Color.red.opacity(0.18)
        case .dimmed:   return Color(.secondarySystemBackground).opacity(0.5)
        }
    }

    private var borderColor: Color {
        switch state {
        case .idle:     return Color.clear
        case .selected: return Color.accentColor
        case .correct:  return Color.green
        case .wrong:    return Color.red
        case .dimmed:   return Color.clear
        }
    }

    private var icon: String? {
        switch state {
        case .correct: return "checkmark.circle.fill"
        case .wrong:   return "xmark.circle.fill"
        default:       return nil
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(text)
                    .font(.body)
                    .fontWeight(state == .correct || state == .wrong ? .semibold : .regular)
                    .foregroundStyle(state == .dimmed ? Color.secondary : Color.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundStyle(state == .correct ? Color.green : Color.red)
                        .font(.title3)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .disabled(state == .dimmed || state == .correct || state == .wrong)
        .scaleEffect(state == .selected ? 0.98 : 1.0)
        .animation(.spring(response: 0.25), value: state)
    }
}

// MARK: - QuizSummaryView

struct QuizSummaryView: View {
    let score:         Int
    let questions:     [QuizQuestion]
    let wrongWords:    [WordModel]
    let onRestart:     () -> Void
    let onRetryMissed: () -> Void
    let onDismiss:     () -> Void

    private var total:      Int    { questions.count }
    private var percentage: Double { total > 0 ? Double(score) / Double(total) : 0 }

    private var grade: (label: String, icon: String, color: Color) {
        switch percentage {
        case 0.9...: return ("Excellent !",       "trophy.fill",                   .yellow)
        case 0.7...: return ("Très bien !",        "star.fill",                     .green)
        case 0.5...: return ("Bonne progression",  "chart.line.uptrend.xyaxis",     .blue)
        default:     return ("À retravailler",      "book.fill",                     .orange)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {

                // ── Score principal ────────────────────────────────────────
                VStack(spacing: 12) {
                    Image(systemName: grade.icon)
                        .font(.system(size: 56))
                        .foregroundStyle(grade.color)
                        .symbolEffect(.bounce)

                    Text(grade.label)
                        .font(.title)
                        .fontWeight(.bold)

                    Text("\(score) / \(total) bonnes réponses")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Text("\(Int(percentage * 100)) %")
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundStyle(grade.color)
                }
                .padding(.top, 32)

                Divider()

                // ── Récapitulatif mot par mot ──────────────────────────────
                VStack(alignment: .leading, spacing: 0) {
                    Text("Récapitulatif")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    ForEach(questions) { q in
                        SummaryRowView(question: q)
                    }
                }

                // ── Boutons d'action ───────────────────────────────────────
                VStack(spacing: 12) {

                    // Réviser les mots manqués
                    if !wrongWords.isEmpty {
                        Button(action: onRetryMissed) {
                            Label(
                                wrongWords.count >= 4
                                    ? "Réviser les \(wrongWords.count) mots manqués"
                                    : "\(wrongWords.count) mot(s) manqué(s) — trop peu pour un quiz",
                                systemImage: "arrow.counterclockwise.circle.fill"
                            )
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.opacity(wrongWords.count >= 4 ? 0.15 : 0.08))
                            .foregroundStyle(wrongWords.count >= 4 ? .orange : .secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .disabled(wrongWords.count < 4)
                    }

                    // Nouveau quiz
                    Button(action: onRestart) {
                        Label("Nouveau quiz", systemImage: "arrow.clockwise")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Button(action: onDismiss) {
                        Text("Retour à la liste")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Résultat")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
    }
}

private struct SummaryRowView: View {
    let question: QuizQuestion

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: masteryIcon)
                .foregroundStyle(masteryColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(question.word.arabic)
                    .font(.body)
                    .fontWeight(.semibold)
                    .environment(\.layoutDirection, .rightToLeft)
                Text(question.word.meaning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            MasteryDots(level: question.word.masteryLevel)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        Divider().padding(.leading, 52)
    }

    private var masteryIcon: String {
        question.word.masteryLevel >= 3 ? "checkmark.circle.fill" : "circle"
    }
    private var masteryColor: Color {
        question.word.masteryLevel >= 3 ? .green : Color(.systemFill)
    }
}

// MARK: - MasteryDots (réutilisé dans WordDetailView)

struct MasteryDots: View {
    let level:    Int
    let maxLevel: Int = 4

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<maxLevel, id: \.self) { i in
                Circle()
                    .fill(i < level ? masteryColor(for: level) : Color(.systemFill))
                    .frame(width: 7, height: 7)
            }
        }
    }

    private func masteryColor(for level: Int) -> Color {
        switch level {
        case 1: return .red.opacity(0.8)
        case 2: return .orange
        case 3: return .yellow
        default: return .green
        }
    }
}

// MARK: - SurahPickerView

struct SurahPickerView: View {
    @Binding var selectedSurah: Int
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    private var filtered: [SurahInfo] {
        guard !searchText.isEmpty else { return SurahInfo.all }
        return SurahInfo.all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.arabic.contains(searchText)
                || "\($0.id)".hasPrefix(searchText)
        }
    }

    var body: some View {
        List {
            // Option "Toutes les sourates"
            Button {
                selectedSurah = 0
                dismiss()
            } label: {
                HStack {
                    Label("Toutes les sourates", systemImage: "square.grid.2x2.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    if selectedSurah == 0 {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }

            // 114 sourates
            ForEach(filtered) { surah in
                Button {
                    selectedSurah = surah.id
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Text("\(surah.id)")
                            .font(.caption)
                            .monospacedDigit()
                            .frame(width: 28, alignment: .trailing)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(surah.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(surah.arabic)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .environment(\.layoutDirection, .rightToLeft)
                        }
                        Spacer()
                        if selectedSurah == surah.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
        }
        .navigationTitle("Choisir une sourate")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Nom ou numéro…")
    }
}

// MARK: - NotEnoughWordsView

private struct NotEnoughWordsView: View {
    let onDismiss: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Pas assez de mots")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Sélectionne une autre catégorie ou un autre mode pour obtenir au moins 4 mots.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Button("Retour aux paramètres", action: onDismiss)
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }
}
