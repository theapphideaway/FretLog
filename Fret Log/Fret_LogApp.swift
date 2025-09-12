//
//  Fret_LogApp.swift
//  Fret Log
//
//  Created by ian schoenrock on 9/12/25.
//

import SwiftUI

@main
struct Fret_LogApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
