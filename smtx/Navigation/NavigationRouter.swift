import SwiftUI

@MainActor
class NavigationRouter: ObservableObject {
    @Published var path = NavigationPath()
    @Published var sheet: Route?
    @Published var fullScreenCover: Route?
    @Published var currentRoute: Route = .languageSection("")
    
    func navigate(to route: Route) {
        currentRoute = route
        path.append(route)
    }
    
    func navigateBack() {
        path.removeLast()
    }
    
    func navigate(to route: Route, presentAsSheet: Bool) {
        switch route {
        case .emailRegister:
            sheet = route
        case .avatarPreview:
            fullScreenCover = route
        default:
            path.append(route)
        }
        
        if let last = (path as Any as? [Route])?.last {
            currentRoute = last
        } else {
            currentRoute = .languageSection("")
        }
    }
    
    func updateCurrentTemplate(_ templateId: String) {
        if case let .createTemplate(sectionId, _) = currentRoute {
            currentRoute = .createTemplate(sectionId, templateId)
        }
    }
    
    func dismiss() {
        sheet = nil
        fullScreenCover = nil
    }
    
    func pop() {
        path.removeLast()
    }
    
    func popToRoot() {
        path.removeLast(path.count)
    }
    
    @ViewBuilder
    func view(for route: Route) -> some View {
        switch route {
        case .languageSection(let language):
            LanguageSectionView(language: language)
        case .templateDetail(let templateId):
            TemplateDetailView(templateId: templateId)
        case .createTemplate(let sectionId, let templateId):
            CreateTemplateView(sectionId: sectionId, existingTemplateId: templateId)
        case .recording(let templateId, let recordId):
            if let template = try? TemplateStorage.shared.loadTemplate(templateId: templateId) {
                RecordingView(template: template, recordId: recordId)
            }
        case .profile:
            ProfileView()
        case .profileDetail:
            ProfileDetailView()
        case .settings:
            SettingsView()
        case .about:
            AboutView()
        case .help:
            HelpView()
        case .avatarPreview(let url):
            AvatarPreviewView(imageURL: url)
        case .emailRegister:
            EmailRegisterView()
        case .cloudTemplateDetail(let uid):
            CloudTemplateDetailView(uid: uid)
        case .adminPanel:
            AdminPanelView()
        case .adminUsers:
            AdminUsersView()
        case .adminLanguageSections:
            AdminLanguageSectionsView()
        }
    }
} 