// CoranLexiqueApp.swift
// CoranLexique — iOS 17+ · Point d'entrée de l'application
//
// Ajouter ce fichier à la cible Xcode ET inclure `words.json`
// dans le bundle ("Add Files to Target" → cocher la cible).

import SwiftUI
import SwiftData

@main
struct CoranLexiqueApp: App {

    /// Container SwiftData partagé pour toute l'application.
    /// Stockage persistant sur le disque de l'appareil.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([WordModel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("CoranLexique — impossible de créer le ModelContainer : \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            WordListView()
        }
        .modelContainer(sharedModelContainer)
    }
}
