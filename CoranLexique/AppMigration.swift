// AppMigration.swift
// CoranLexique — iOS 17+ · Plan de migration SwiftData
//
// Chaque version du schéma est déclarée ici.
// La migration V1 → V2 est légère (lightweight) : SwiftData ajoute
// automatiquement la colonne `surahNumbers` avec la valeur par défaut [].

import Foundation
import SwiftData

// MARK: - Schéma V1 — version originale sans surahNumbers

enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [AppSchemaV1.WordModel.self] }

    @Model
    final class WordModel {
        @Attribute(.unique) var id: UUID
        var arabic: String
        var transliteration: String
        var meaning: String
        var root: String
        var category: WordCategory
        var frequency: Int
        var masteryLevel: Int

        init(
            id: UUID = UUID(),
            arabic: String,
            transliteration: String,
            meaning: String,
            root: String,
            category: WordCategory,
            frequency: Int,
            masteryLevel: Int = 0
        ) {
            self.id              = id
            self.arabic          = arabic
            self.transliteration = transliteration
            self.meaning         = meaning
            self.root            = root
            self.category        = category
            self.frequency       = frequency
            self.masteryLevel    = masteryLevel
        }
    }
}

// MARK: - Schéma V2 — ajout de surahNumbers

enum AppSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [WordModel.self] }
}

// MARK: - Plan de migration

enum AppMigrationPlan: SchemaMigrationPlan {

    static var schemas: [any VersionedSchema.Type] {
        [AppSchemaV1.self, AppSchemaV2.self]
    }

    static var stages: [MigrationStage] { [migrateV1toV2] }

    /// Migration légère V1 → V2 : SwiftData ajoute la colonne `surahNumbers`
    /// avec la valeur par défaut `[]` sans toucher aux données existantes.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: AppSchemaV1.self,
        toVersion: AppSchemaV2.self
    )
}
