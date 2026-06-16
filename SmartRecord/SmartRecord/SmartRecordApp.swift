//
//  SmartRecordApp.swift
//  SmartRecord
//
//  Created by Nelle Rtcai on 6/15/26.
//

import SwiftUI
import SwiftData

@main
struct SmartRecordApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Project.self, ClickEvent.self, CursorSample.self, RenderSettings.self])
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
        }
        .modelContainer(sharedModelContainer)
    }
}
