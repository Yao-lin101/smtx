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
            "英语",
            "法语",
            "日语",
            "德语",
            "韩语"
        ]
        
        defaultLanguages.forEach { language in
            TemplateStorage.shared.addLanguageSection(language)
        }
    }
}
