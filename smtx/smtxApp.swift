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
        let defaultSections = [
            ("2b473e8d5271466d82e906f272eb2527", "English"),
            ("8d0cd170b08649608a1433b43904f757", "中文"),
            ("aefd30d18168415da9a9322abc9976f4", "日本語"),
            ("b16d3b28a6014523b086819184e29030", "한국어"),
            ("b6145c6594d4478f81ad61effbba243b", "Français"),
            ("d8c41b4af55948d690300bb625cd4fb3", "Deutsch")
        ]
        
        defaultSections.forEach { (cloudSectionId, name) in
            _ = try? TemplateStorage.shared.createLanguageSection(name: name, cloudSectionId: cloudSectionId)
        }
    }
}
