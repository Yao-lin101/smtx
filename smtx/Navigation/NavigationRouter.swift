import SwiftUI

class NavigationRouter: ObservableObject {
    @Published var path = NavigationPath()
    @Published var currentRoute: Route = .languageSection("")
    
    func navigate(to route: Route) {
        currentRoute = route
        path.append(route)
    }
    
    func navigateBack() {
        path.removeLast()
        if let last = (path as Any as? [Route])?.last {
            currentRoute = last
        } else {
            currentRoute = .languageSection("")
        }
    }
    
    func updateCurrentTemplate(_ templateId: String) {
        if case let .createTemplate(language, _) = currentRoute {
            currentRoute = .createTemplate(language, templateId)
        }
    }
} 