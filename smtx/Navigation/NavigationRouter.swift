import SwiftUI

enum Route: Hashable {
    case languageSection(String)
    case templateDetail(Template)
    case createTemplate(String)
    case recordDetail(VoiceRecord)
    case recording(Template)
}

class NavigationRouter: ObservableObject {
    @Published var path = NavigationPath()
    @Published var presentedSheet: Route?
    
    func navigate(to route: Route) {
        path.append(route)
    }
    
    func navigateBack() {
        path.removeLast()
    }
    
    func navigateToRoot() {
        path.removeLast(path.count)
    }
    
    func presentSheet(_ route: Route) {
        presentedSheet = route
    }
    
    func dismissSheet() {
        presentedSheet = nil
    }
} 