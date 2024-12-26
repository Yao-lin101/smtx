//
//  smtxApp.swift
//  smtx
//
//  Created by Enkidu ㅤ on 2024/12/23.
//

import SwiftUI

@main
struct smtxApp: App {
    @AppStorage("isFirstLaunch") private var isFirstLaunch = true
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    if isFirstLaunch {
                        setupInitialLanguageSections()
                        isFirstLaunch = false
                    }
                }
        }
    }
    
    private func setupInitialLanguageSections() {
        let defaultLanguages = [
            "English",
            "Français",
            "日本語",
            "Deutsch",
            "한국어"
        ]
        
        defaultLanguages.forEach { language in
            TemplateStorage.shared.addLanguageSection(language)
        }
    }
}
