// DatabaseInitializer.swift
// CoranLexique — iOS 17+ · SwiftData
// Service d'importation initiale des données (Mass Load)

import Foundation
import SwiftData

// MARK: - DTO (Data Transfer Object) pour le décodage JSON

/// Structure miroir du JSON — tous les champs non-essentiels sont optionnels
/// pour assurer la robustesse lors de l'import de fichiers partiels.
struct WordDTO: Decodable {
    let id:              String?
    let arabic:          String
    let transliteration: String
    let meaning:         String
    let root:            String
    let category:        String
    let frequency:       Int
    let masteryLevel:    Int?
    let surahNumbers:    [Int]   // "surah" dans le JSON : [Int] → tel quel · ["N/A"] → [0] · [] → []

    enum CodingKeys: String, CodingKey {
        case id, arabic, transliteration, meaning, root, category, frequency, masteryLevel
        case surahNumbers = "surah"
    }

    init(from decoder: Decoder) throws {
        let c       = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decodeIfPresent(String.self, forKey: .id)
        arabic          = try c.decode(String.self,          forKey: .arabic)
        transliteration = try c.decode(String.self,          forKey: .transliteration)
        meaning         = try c.decode(String.self,          forKey: .meaning)
        root            = try c.decode(String.self,          forKey: .root)
        category        = try c.decode(String.self,          forKey: .category)
        frequency       = try c.decode(Int.self,             forKey: .frequency)
        masteryLevel    = try c.decodeIfPresent(Int.self,    forKey: .masteryLevel)
        // "surah" est soit [Int] (sourates spécifiques), soit ["N/A"] (mot ubiquitaire),
        // soit [] (sourate inconnue / non assignée).
        // • [Int]   → stocké tel quel
        // • ["N/A"] → decode([Int]) échoue, on stocke [0] comme sentinelle "ubiquitaire"
        // • []      → decode([Int]) réussit avec [], stocké [] (exclu des filtres par sourate)
        if let nums = try? c.decode([Int].self, forKey: .surahNumbers) {
            surahNumbers = nums          // [Int] ou []
        } else {
            surahNumbers = [0]           // ["N/A"] → sentinelle ubiquitaire
        }
    }
}

// MARK: - DataImporter

/// Responsable du chargement initial du dictionnaire coranique dans SwiftData.
///
/// Stratégie :
/// 1. Vérifie que la base est vide avant tout import (évite les doublons).
/// 2. Cherche `words.json` dans le bundle de l'application.
/// 3. Si absent, insère les données de démonstration embarquées.
///
/// - Important: Marqué `@MainActor` car `ModelContext` doit être utilisé
///   sur le thread principal dans les applications SwiftData/SwiftUI.
@MainActor
final class DataImporter {

    // MARK: - API publique

    /// Point d'entrée principal — à appeler dans `onAppear` de la vue racine.
    /// Ne fait rien si la base contient déjà au moins un enregistrement.
    static func importIfNeeded(context: ModelContext) {
        guard isDatabaseEmpty(context: context) else {
            print("DataImporter: base déjà peuplée — import ignoré.")
            return
        }

        if let url = Bundle.main.url(forResource: "words", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            decode(data: data, into: context)
        } else {
            print("DataImporter: 'words.json' introuvable dans le bundle — chargement des données de démonstration.")
            insertSampleData(into: context)
        }
    }

    /// Importe depuis une chaîne JSON brute (utile pour les tests unitaires).
    /// Respecte la même contrainte d'idempotence : n'importe que si la base est vide.
    static func importFromJSONString(_ jsonString: String, context: ModelContext) {
        guard isDatabaseEmpty(context: context) else { return }
        guard let data = jsonString.data(using: .utf8) else {
            print("DataImporter: conversion String → Data échouée.")
            return
        }
        decode(data: data, into: context)
    }

    // MARK: - Privé

    private static func isDatabaseEmpty(context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<WordModel>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        return count == 0
    }

    /// Décode un tableau JSON de `WordDTO` et insère les `WordModel` correspondants.
    private static func decode(data: Data, into context: ModelContext) {
        do {
            let dtos = try JSONDecoder().decode([WordDTO].self, from: data)
            for dto in dtos {
                let category = WordCategory(rawValue: dto.category) ?? .noun
                let word = WordModel(
                    id:              UUID(uuidString: dto.id ?? "") ?? UUID(),
                    arabic:          dto.arabic,
                    transliteration: dto.transliteration,
                    meaning:         dto.meaning,
                    root:            dto.root,
                    category:        category,
                    frequency:       dto.frequency,
                    masteryLevel:    dto.masteryLevel ?? 0,
                    surahNumbers:    dto.surahNumbers
                )
                context.insert(word)
            }
            try context.save()
            print("DataImporter: ✅ \(dtos.count) mots importés avec succès.")
        } catch {
            print("DataImporter: ❌ Erreur lors du décodage — \(error.localizedDescription)")
        }
    }

    /// Jeu de données de démonstration — couvre les 5 catégories grammaticales
    /// avec les mots les plus fréquents du Coran.
    static func insertSampleData(into context: ModelContext) {
        let samples: [(arabic: String, translit: String, meaning: String, root: String, cat: WordCategory, freq: Int)] = [
            // Noms
            ("الله",    "Allāh",    "Dieu (Allah)",             "أله",  .noun,      2699),
            ("رَبّ",    "rabb",     "Seigneur",                  "ربب",  .noun,       970),
            ("كِتَاب",  "kitāb",    "Livre",                     "كتب",  .noun,       255),
            ("نَبِيّ",  "nabī",     "Prophète",                  "نبأ",  .noun,        75),
            ("يَوم",    "yawm",     "Jour",                      "يوم",  .noun,       405),
            ("نَاس",    "nās",      "Les gens / Humanité",       "نوس",  .noun,       241),
            ("أَرض",    "arḍ",      "Terre",                     "أرض",  .noun,       461),
            // Verbes
            ("قَالَ",   "qāla",     "Il a dit",                  "قول",  .verb,      1722),
            ("كَانَ",   "kāna",     "Il était / Il fut",         "كون",  .verb,      1360),
            ("جَعَلَ",  "jaʿala",   "Il a fait / créé",          "جعل",  .verb,       346),
            ("آمَنَ",   "āmana",    "Il a cru",                  "أمن",  .verb,       537),
            ("عَمِلَ",  "ʿamila",   "Il a œuvré",                "عمل",  .verb,       360),
            // Particules
            ("مِن",     "min",      "De / Parmi / Depuis",       "",     .particle,  3226),
            ("فِي",     "fī",       "Dans / En",                 "",     .particle,  1706),
            ("عَلَى",   "ʿalā",     "Sur / Contre",              "",     .particle,  1461),
            ("إِلَى",   "ilā",      "Vers / À",                  "",     .particle,  1488),
            ("إِنَّ",   "inna",     "Certes / Vraiment",         "",     .particle,  1448),
            ("لَا",     "lā",       "Non / Pas",                 "",     .particle,  1710),
            // Adjectifs
            ("عَظِيم",  "ʿaẓīm",    "Grand / Immense",           "عظم",  .adjective,  159),
            ("كَبِير",  "kabīr",    "Grand / Important",         "كبر",  .adjective,   97),
            ("رَحِيم",  "raḥīm",    "Très Miséricordieux",       "رحم",  .adjective,   95),
            ("كَرِيم",  "karīm",    "Noble / Généreux",          "كرم",  .adjective,   27),
            // Pronoms
            ("هُوَ",    "huwa",     "Lui / Il",                  "",     .pronoun,    714),
            ("هُم",     "hum",      "Eux / Ils",                 "",     .pronoun,    354),
            ("أَنتَ",   "anta",     "Toi / Tu",                  "",     .pronoun,    195),
            ("نَحنُ",   "naḥnu",    "Nous",                      "",     .pronoun,    110),
        ]

        for item in samples {
            let word = WordModel(
                arabic:          item.arabic,
                transliteration: item.translit,
                meaning:         item.meaning,
                root:            item.root,
                category:        item.cat,
                frequency:       item.freq
            )
            context.insert(word)
        }
        try? context.save()
        print("DataImporter: ✅ \(samples.count) mots de démonstration chargés.")
    }

    // MARK: - Migration sourate

    /// Met à jour les surahNumbers en place pour tous les appareils (sans supprimer la progression).
    static func migrateSurahDataIfNeeded(context: ModelContext) {
        let versionKey = "data.surahVersion"
        guard UserDefaults.standard.integer(forKey: versionKey) < 4 else { return }

        guard let url  = Bundle.main.url(forResource: "words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dtos = try? JSONDecoder().decode([WordDTO].self, from: data) else { return }

        // Deux index : UUID (principal) et arabic (fallback si UUID manquant)
        var byUUID:   [UUID:   [Int]] = [:]
        var byArabic: [String: [Int]] = [:]
        for dto in dtos {
            if let uuid = UUID(uuidString: dto.id ?? "") {
                byUUID[uuid] = dto.surahNumbers
            }
            byArabic[dto.arabic] = dto.surahNumbers
        }

        let descriptor = FetchDescriptor<WordModel>()
        guard let allWords = try? context.fetch(descriptor) else { return }

        var updated = 0
        for word in allWords {
            let nums = byUUID[word.id] ?? byArabic[word.arabic]
            guard let nums else { continue }
            word.surahNumbers = nums   // toujours écraser — évite le bug de comparaison [Int] SwiftData
            updated += 1
        }

        try? context.save()
        print("DataImporter: ✅ Sourates mises à jour pour \(updated) mots.")
        UserDefaults.standard.set(4, forKey: versionKey)
    }
}
