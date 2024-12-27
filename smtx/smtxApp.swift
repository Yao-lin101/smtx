//
//  smtxApp.swift
//  smtx
//
//  Created by Enkidu ㅤ on 2024/12/23.
//

import SwiftUI

@main
struct SmtxApp: App {
    @AppStorage("isFirstLaunch") private var isFirstLaunch = true
    @StateObject private var userStore = UserStore.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(userStore)
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
