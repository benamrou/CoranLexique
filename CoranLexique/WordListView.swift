// WordListView.swift
// CoranLexique — iOS 17+ · SwiftUI + SwiftData
// Vue principale : liste filtrée + chips catégorie + tableau de bord + navigation

import SwiftUI
import SwiftData

// MARK: - Couleur sémantique par catégorie (extension UI uniquement)

extension WordCategory {
    var accentColor: Color {
        switch self {
        case .verb:      return .blue
        case .noun:      return .green
        case .particle:  return .orange
        case .adjective: return .purple
        case .pronoun:   return .pink
        }
    }
}

// MARK: - Search infrastructure

/// Copie légère d'un mot — données textuelles uniquement, sûre pour Task.detached (Sendable).
private struct SearchItem: Sendable {
    let id:              UUID
    let arabic:          String
    let transliteration: String
    let meaning:         String
    let root:            String
    let category:        WordCategory
}

/// Clé composite pour .task(id:) — déclenche le filtre sur texte OU catégorie.
private struct FilterKey: Equatable {
    let text:     String
    let category: String  // rawValue ou "" si nil
}

// MARK: - WordListView

struct WordListView: View {

    @Environment(\.modelContext) private var modelContext

    /// Tous les mots, triés par fréquence décroissante.
    @Query(sort: [SortDescriptor(\WordModel.frequency, order: .reverse)])
    private var allWords: [WordModel]

    @State private var selectedCategory:   WordCategory? = nil
    @State private var searchText:         String        = ""
    @State private var filteredWords:      [WordModel]   = []   // résultat async du filtre
    @State private var searchItems:        [SearchItem]  = []   // index léger pour thread secondaire
    @State private var isDashboardVisible: Bool          = true
    @State private var isQuizPresented:    Bool          = false
    @State private var isAboutPresented:   Bool          = false

    /// Affichage immédiat : allWords quand aucun filtre actif, sinon résultat async.
    private var displayedWords: [WordModel] {
        searchText.isEmpty && selectedCategory == nil ? allWords : filteredWords
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Chips de filtrage ──────────────────────────────────────
                CategoryFilterBar(selectedCategory: $selectedCategory)

                // ── Tableau de bord (rétractable) ─────────────────────────
                if isDashboardVisible {
                    DashboardStatsView(words: allWords)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Divider()

                // ── Liste des mots ─────────────────────────────────────────
                List(Array(displayedWords.enumerated()), id: \.element.id) { index, word in
                    NavigationLink {
                        WordPagerView(words: displayedWords, startIndex: index)
                    } label: {
                        WordRowView(word: word)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.visible)
                }
                .listStyle(.plain)
                .animation(.easeInOut(duration: 0.2), value: displayedWords.count)

            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Arabe, translittération, signification…"
            )
            .task(id: FilterKey(text: searchText, category: selectedCategory?.rawValue ?? "")) {
                let query = searchText
                let cat   = selectedCategory

                // Sans texte : filtre catégorie uniquement, pas de debounce nécessaire
                guard !query.isEmpty else {
                    filteredWords = cat == nil ? allWords : allWords.filter { $0.category == cat }
                    return
                }

                // Debounce 250 ms pour la recherche textuelle
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }

                // Capture les données légères — sûr pour Task.detached
                let items = searchItems
                let allW  = allWords

                // Comparaisons string sur thread secondaire
                let matchingIDs: Set<UUID> = await Task.detached(priority: .userInitiated) {
                    var ids = Set<UUID>()
                    for item in items {
                        guard cat == nil || item.category == cat else { continue }
                        if item.arabic.contains(query)
                            || item.transliteration.range(of: query, options: .caseInsensitive) != nil
                            || item.meaning.range(of: query, options: .caseInsensitive) != nil
                            || item.root.range(of: query, options: .caseInsensitive) != nil {
                            ids.insert(item.id)
                        }
                    }
                    return ids
                }.value

                guard !Task.isCancelled else { return }
                filteredWords = allW.filter { matchingIDs.contains($0.id) }
            }
            .onChange(of: allWords) { _, words in
                // Reconstruire l'index en arrière-plan pour ne pas bloquer l'UI
                Task {
                    searchItems = words.map {
                        SearchItem(id: $0.id, arabic: $0.arabic, transliteration: $0.transliteration,
                                   meaning: $0.meaning, root: $0.root, category: $0.category)
                    }
                }
            }
            .navigationTitle("CoranLexique")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {

                // Bouton Quiz (barre gauche)
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isQuizPresented = true
                    } label: {
                        Label("Quiz", systemImage: "brain.head.profile")
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .accessibilityLabel("Lancer un quiz")
                }

                // Bascule Tableau de bord (barre droite)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            isDashboardVisible.toggle()
                        }
                    } label: {
                        Image(systemName: isDashboardVisible ? "chart.bar.fill" : "chart.bar")
                    }
                    .accessibilityLabel(
                        isDashboardVisible ? "Masquer la progression" : "Afficher la progression"
                    )
                }

                // Bouton À propos (barre droite)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAboutPresented = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("À propos")
                }
            }
            // ── Présentation du quiz en fullscreen ───────────────────────
            .fullScreenCover(isPresented: $isQuizPresented) {
                QuizView(words: allWords)
            }
            // ── Présentation de la fiche À propos ─────────────────────────
            .sheet(isPresented: $isAboutPresented) {
                AboutView()
            }
        }
        .onAppear {
            DataImporter.importIfNeeded(context: modelContext)
            DataImporter.migrateSurahDataIfNeeded(context: modelContext)
        }
        .task {
            // Construction de l'index après le premier rendu — ne bloque pas l'UI
            searchItems = allWords.map {
                SearchItem(id: $0.id, arabic: $0.arabic, transliteration: $0.transliteration,
                           meaning: $0.meaning, root: $0.root, category: $0.category)
            }
        }
    }
}

// MARK: - CategoryFilterBar

struct CategoryFilterBar: View {
    @Binding var selectedCategory: WordCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {

                CategoryChip(
                    label:      "Tous",
                    systemIcon: "square.grid.2x2.fill",
                    isSelected: selectedCategory == nil,
                    color:      .accentColor
                ) {
                    withAnimation(.snappy(duration: 0.25)) { selectedCategory = nil }
                }

                ForEach(WordCategory.allCases) { category in
                    CategoryChip(
                        label:      category.rawValue,
                        systemIcon: category.systemIcon,
                        isSelected: selectedCategory == category,
                        color:      category.accentColor
                    ) {
                        withAnimation(.snappy(duration: 0.25)) {
                            selectedCategory = (selectedCategory == category) ? nil : category
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - CategoryChip

struct CategoryChip: View {
    let label:      String
    let systemIcon: String
    let isSelected: Bool
    let color:      Color
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemIcon)
                    .font(.caption)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(.secondarySystemBackground))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .clipShape(Capsule())
            .shadow(color: isSelected ? color.opacity(0.35) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - DashboardStatsView

struct DashboardStatsView: View {
    let words: [WordModel]

    private struct CategoryStat: Identifiable {
        let id:       WordCategory
        let category: WordCategory
        let mastered: Int
        let total:    Int
        var percentage: Double { total > 0 ? Double(mastered) / Double(total) : 0 }
    }

    @State private var sheetCategory: WordCategory? = nil

    private var stats: [CategoryStat] {
        WordCategory.allCases.compactMap { category in
            let subset = words.filter { $0.category == category }
            guard !subset.isEmpty else { return nil }
            let mastered = subset.filter { $0.masteryLevel >= 3 }.count
            return CategoryStat(id: category, category: category, mastered: mastered, total: subset.count)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                Label("Progression", systemImage: "trophy.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(words.count) mots au total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(stats) { stat in
                Button {
                    sheetCategory = stat.category
                } label: {
                    CategoryProgressRow(
                        category:   stat.category,
                        mastered:   stat.mastered,
                        total:      stat.total,
                        percentage: stat.percentage
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .sheet(item: $sheetCategory) { category in
            CategoryDetailView(
                category: category,
                words: words.filter { $0.category == category }
            )
        }
    }
}

// MARK: - CategoryProgressRow

struct CategoryProgressRow: View {
    let category:   WordCategory
    let mastered:   Int
    let total:      Int
    let percentage: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: category.systemIcon)
                    .foregroundStyle(category.accentColor)
                    .frame(width: 16)
                Text(category.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                // Compteur connus / total
                HStack(spacing: 3) {
                    Text("\(mastered)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(category.accentColor)
                    Text("/")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("\(total)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemFill))
                        .frame(height: 5)
                    Capsule()
                        .fill(category.accentColor)
                        .frame(width: max(4, geo.size.width * percentage), height: 5)
                }
            }
            .frame(height: 5)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - CategoryDetailView

struct CategoryDetailView: View {

    let category: WordCategory
    let words:    [WordModel]

    enum KnowledgeFilter: String, CaseIterable, Identifiable {
        case all     = "Tous"
        case known   = "Connus"
        case unknown = "À apprendre"

        var id: String { rawValue }

        var systemIcon: String {
            switch self {
            case .all:     return "square.grid.2x2.fill"
            case .known:   return "checkmark.circle.fill"
            case .unknown: return "circle"
            }
        }

        var color: Color {
            switch self {
            case .all:     return .accentColor
            case .known:   return .green
            case .unknown: return .orange
            }
        }
    }

    @State private var filter: KnowledgeFilter = .all
    @Environment(\.dismiss) private var dismiss

    private var knownWords:   [WordModel] { words.filter { $0.masteryLevel >= 3 } }
    private var unknownWords: [WordModel] { words.filter { $0.masteryLevel <  3 } }

    private var filteredWords: [WordModel] {
        switch filter {
        case .all:     return words
        case .known:   return knownWords
        case .unknown: return unknownWords
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Bande résumé connus / à apprendre ─────────────────────
                HStack(spacing: 12) {
                    KnowledgeBadge(
                        count:  knownWords.count,
                        total:  words.count,
                        label:  "Connus",
                        color:  .green,
                        icon:   "checkmark.circle.fill"
                    )
                    Spacer()
                    KnowledgeBadge(
                        count:  unknownWords.count,
                        total:  words.count,
                        label:  "À apprendre",
                        color:  .orange,
                        icon:   "circle"
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))

                // ── Barre de progression globale ──────────────────────────
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(.systemFill))
                            .frame(height: 4)
                        Rectangle()
                            .fill(category.accentColor)
                            .frame(
                                width: words.isEmpty ? 0
                                     : max(0, geo.size.width * Double(knownWords.count) / Double(words.count)),
                                height: 4
                            )
                    }
                }
                .frame(height: 4)

                // ── Chips de filtre ────────────────────────────────────────
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(KnowledgeFilter.allCases) { f in
                            CategoryChip(
                                label:      f.rawValue,
                                systemIcon: f.systemIcon,
                                isSelected: filter == f,
                                color:      f.color
                            ) {
                                withAnimation(.snappy(duration: 0.25)) { filter = f }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(.ultraThinMaterial)

                Divider()

                // ── Liste des mots filtrés ─────────────────────────────────
                if filteredWords.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: filter == .known ? "checkmark.circle" : "circle")
                            .font(.system(size: 40))
                            .foregroundStyle(filter.color.opacity(0.5))
                        Text(filter == .known
                             ? "Aucun mot maîtrisé pour l'instant"
                             : "Tous les mots de cette catégorie sont maîtrisés !")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    Spacer()
                } else {
                    List(Array(filteredWords.enumerated()), id: \.element.id) { index, word in
                        NavigationLink {
                            WordPagerView(words: filteredWords, startIndex: index)
                        } label: {
                            WordRowView(word: word)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.visible)
                    }
                    .listStyle(.plain)
                    .animation(.easeInOut(duration: 0.2), value: filteredWords.count)
                }
            }
            .navigationTitle(category.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - KnowledgeBadge

private struct KnowledgeBadge: View {
    let count: Int
    let total: Int
    let label: String
    let color: Color
    let icon:  String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(count) / \(total)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - WordRowView

struct WordRowView: View {
    let word: WordModel

    private var masteryColor: Color {
        switch word.masteryLevel {
        case 0:     return .red.opacity(0.85)
        case 1:     return .orange
        case 2:     return .yellow
        default:    return .green
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            VStack {
                Circle()
                    .fill(masteryColor)
                    .frame(width: 9, height: 9)
                    .padding(.top, 5)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {

                HStack(alignment: .firstTextBaseline) {
                    Text(word.arabic)
                        .font(.title3)
                        .fontWeight(.bold)
                        .environment(\.layoutDirection, .rightToLeft)
                    Spacer()
                    CategoryBadgeView(category: word.category)
                }

                Text(word.transliteration)
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.secondary)

                Text(word.meaning)
                    .font(.body)
                    .foregroundStyle(.primary)

                HStack(spacing: 14) {
                    if !word.root.isEmpty {
                        Label(word.root, systemImage: "tree.fill")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Label("×\(word.frequency)", systemImage: "repeat")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - CategoryBadgeView

struct CategoryBadgeView: View {
    let category: WordCategory

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: category.systemIcon)
                .font(.caption2)
            Text(category.rawValue)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(category.accentColor.opacity(0.12))
        .foregroundStyle(category.accentColor)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - AboutView

struct AboutView: View {

    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {

                // ── Icône + nom ────────────────────────────────────────────
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(.tint)
                                .padding(.top, 8)
                            Text("CoranLexique")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Version \(appVersion)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 12)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)

                // ── Contact & signalement ──────────────────────────────────
                Section(header: Text("Contact")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BBSYMPHONY LLC")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Pour signaler un problème ou proposer une amélioration :")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    Link(destination: URL(string: "mailto:products@bbsymphony.com")!) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(.tint)
                            Text("products@bbsymphony.com")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // ── Avertissement traductions ──────────────────────────────
                Section(header: Text("Avertissement")) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .padding(.top, 2)
                        Text("Les traductions proposées dans cette application sont susceptibles de contenir des approximations. Nous nous efforçons de les améliorer en continu — n'hésitez pas à nous signaler toute erreur via le contact ci-dessus.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // ── Informations légales ───────────────────────────────────
                Section(header: Text("Informations")) {
                    LabeledContent("Éditeur", value: "BBSYMPHONY LLC")
                    LabeledContent("Données", value: "Corpus coranique (domaine public)")
                }

            }
            .navigationTitle("À propos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let config    = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: WordModel.self, configurations: config)
    DataImporter.insertSampleData(into: container.mainContext)
    return WordListView()
        .modelContainer(container)
}
