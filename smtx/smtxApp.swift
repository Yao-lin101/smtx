//
//  smtxApp.swift
//  smtx
//
//  Created by Enkidu ㅤ on 2024/12/23.
//

import SwiftUI

@main
struct smtxApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
