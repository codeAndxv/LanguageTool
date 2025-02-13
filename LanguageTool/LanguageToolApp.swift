//
//  LanguageToolApp.swift
//  LanguageTool
//
//  Created by 华子 on 2025/2/12.
//

import SwiftUI
import SwiftData

@main
struct LanguageToolApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)
        }
        
        // 添加设置窗口
        Settings {
            SettingsView()
                .modelContainer(sharedModelContainer)
        }
    }
}
