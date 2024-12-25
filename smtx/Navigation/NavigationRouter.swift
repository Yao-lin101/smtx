import SwiftUI
import CoreData

enum Route: Hashable {
    case languageSection(String)
    case templateDetail(String)
    case createTemplate(String, String? = nil)
    case recording(String, String? = nil)
    case recordDetail(String, String)
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .languageSection(let language):
            hasher.combine(0)
            hasher.combine(language)
        case .templateDetail(let templateId):
            hasher.combine(1)
            hasher.combine(templateId)
        case .createTemplate(let language, let templateId):
            hasher.combine(2)
            hasher.combine(language)
            hasher.combine(templateId)
        case .recording(let templateId, let recordId):
            hasher.combine(3)
            hasher.combine(templateId)
            hasher.combine(recordId)
        case .recordDetail(let templateId, let recordId):
            hasher.combine(4)
            hasher.combine(templateId)
            hasher.combine(recordId)
        }
    }
    
    static func == (lhs: Route, rhs: Route) -> Bool {
        switch (lhs, rhs) {
        case (.languageSection(let l), .languageSection(let r)):
            return l == r
        case (.templateDetail(let l), .templateDetail(let r)):
            return l == r
        case (.createTemplate(let l1, let l2), .createTemplate(let r1, let r2)):
            return l1 == r1 && l2 == r2
        case (.recording(let l1, let l2), .recording(let r1, let r2)):
            return l1 == r1 && l2 == r2
        case (.recordDetail(let l1, let l2), .recordDetail(let r1, let r2)):
            return l1 == r1 && l2 == r2
        default:
            return false
        }
    }
}

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