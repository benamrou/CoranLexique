// WordModel.swift
// CoranLexique — iOS 17+ · SwiftData
// Modèle de données principal + énumération des catégories grammaticales

import Foundation
import SwiftData

// MARK: - WordCategory

/// Catégories grammaticales reconnues par l'application.
/// Conforme à Codable pour le stockage SwiftData et le décodage JSON.
enum WordCategory: String, Codable, CaseIterable, Hashable, Identifiable {
    var id: String { rawValue }
    case verb      = "Verbe"
    case noun      = "Nom"
    case particle  = "Particule"
    case adjective = "Adjectif"
    case pronoun   = "Pronom"

    /// Icône SF Symbols associée à la catégorie.
    var systemIcon: String {
        switch self {
        case .verb:      return "bolt.fill"
        case .noun:      return "tag.fill"
        case .particle:  return "link"
        case .adjective: return "paintbrush.fill"
        case .pronoun:   return "person.fill"
        }
    }
}

// MARK: - WordModel

/// Entité SwiftData représentant un mot coranique.
/// L'unicité est garantie par l'attribut `id` (UUID).
@Model
final class WordModel {

    /// Identifiant unique — contraint à l'unicité par SwiftData.
    @Attribute(.unique) var id: UUID

    /// Texte en arabe (ex. : "الله").
    var arabic: String

    /// Translittération phonétique latine (ex. : "Allāh").
    var transliteration: String

    /// Signification(s) en français.
    var meaning: String

    /// Racine trilatère arabe (ex. : "أله"). Vide si non applicable.
    var root: String

    /// Catégorie grammaticale (Verbe, Nom, Particule, Adjectif, Pronom).
    var category: WordCategory

    /// Nombre d'occurrences dans le Coran.
    var frequency: Int

    /// Niveau de maîtrise : 0 = Nouveau · 1 = Débutant · 2 = Intermédiaire · 3+ = Maîtrisé
    var masteryLevel: Int

    /// Numéros des sourates (1–114) dans lesquelles ce mot apparaît. Vide = présent partout (N/A).
    var surahNumbers: [Int]

    init(
        id: UUID = UUID(),
        arabic: String,
        transliteration: String,
        meaning: String,
        root: String,
        category: WordCategory,
        frequency: Int,
        masteryLevel: Int = 0,
        surahNumbers: [Int] = []
    ) {
        self.id              = id
        self.arabic          = arabic
        self.transliteration = transliteration
        self.meaning         = meaning
        self.root            = root
        self.category        = category
        self.frequency       = frequency
        self.masteryLevel    = masteryLevel
        self.surahNumbers    = surahNumbers
    }
}
