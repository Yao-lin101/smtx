import SwiftUI

struct MainTabView: View {
    @StateObject private var cloudRouter = NavigationRouter()   // 云模板的路由
    @StateObject private var localRouter = NavigationRouter()   // 本地模板的路由
    @StateObject private var profileRouter = NavigationRouter() // 个人中心的路由
    @StateObject private var userStore = UserStore.shared
    @State private var selectedTab = 1  // 默认选中本地模板页
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 云模板页（预留）
            NavigationStack(path: $cloudRouter.path) {
                CloudTemplatesView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .languageSection, .templateDetail, .createTemplate, .recording:
                            // 云模板功能尚未实现
                            EmptyView()
                        case .profile, .profileDetail, .settings, .help, .about, .avatarPreview, .emailRegister:
                            // 这些路由在云模板页面不需要处理
                            EmptyView()
                        }
                    }
            }
            .environmentObject(cloudRouter)  // 云模板使用 cloudRouter
            .tabItem {
                Label("云模板", systemImage: "cloud")
            }
            .tag(0)
            
            // 本地模板页
            NavigationStack(path: $localRouter.path) {
                LocalTemplatesView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .languageSection(let language):
                            LanguageSectionView(language: language)
                        case .templateDetail(let templateId):
                            TemplateDetailView(templateId: templateId)
                        case .createTemplate(let language, let templateId):
                            CreateTemplateView(language: language, existingTemplateId: templateId)
                        case .recording(let templateId, let recordId):
                            if let template = try? TemplateStorage.shared.loadTemplate(templateId: templateId) {
                                RecordingView(template: template, recordId: recordId)
                            }
                        case .profile, .profileDetail, .settings, .help, .about, .avatarPreview, .emailRegister:
                            // 这些路由在本地模板页面不需要处理
                            EmptyView()
                        }
                    }
            }
            .environmentObject(localRouter)  // 本地模板使用 localRouter
            .tabItem {
                Label("本地", systemImage: "folder")
            }
            .tag(1)
            
            // 个人中心
            NavigationStack(path: $profileRouter.path) {
                ProfileView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .profileDetail:
                            ProfileDetailView()
                        case .settings:
                            SettingsView()
                        case .help:
                            HelpView()
                        case .about:
                            AboutView()
                        case .avatarPreview(let imageURL):
                            AvatarPreviewView(imageURL: imageURL)
                        case .emailRegister:
                            EmailRegisterView()
                        case .languageSection, .templateDetail, .createTemplate, .recording, .profile:
                            // 这些路由在个人中心不需要处理
                            EmptyView()
                        }
                    }
            }
            .environmentObject(profileRouter)  // 个人中心使用 profileRouter
            .tabItem {
                Label("我的", systemImage: "person")
            }
            .tag(2)
        }
        .environmentObject(userStore)
    }
}

#Preview {
    MainTabView()
} 
