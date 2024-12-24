import SwiftUI

enum Route: Hashable {
    case languageSection(String)
    case templateDetail(TemplateFile)
    case createTemplate(String, TemplateFile? = nil)
    case recording(TemplateFile)
    case recordDetail(String, RecordData)
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .languageSection(let language):
            hasher.combine(0)
            hasher.combine(language)
        case .templateDetail(let template):
            hasher.combine(1)
            hasher.combine(template.metadata.id)
        case .createTemplate(let language, let template):
            hasher.combine(2)
            hasher.combine(language)
            hasher.combine(template)
        case .recording(let template):
            hasher.combine(3)
            hasher.combine(template.metadata.id)
        case .recordDetail(let templateId, let record):
            hasher.combine(4)
            hasher.combine(templateId)
            hasher.combine(record.id)
        }
    }
    
    static func == (lhs: Route, rhs: Route) -> Bool {
        switch (lhs, rhs) {
        case (.languageSection(let l), .languageSection(let r)):
            return l == r
        case (.templateDetail(let l), .templateDetail(let r)):
            return l.metadata.id == r.metadata.id
        case (.createTemplate(let l1, let l2), .createTemplate(let r1, let r2)):
            return l1 == r1 && l2 == r2
        case (.recording(let l), .recording(let r)):
            return l.metadata.id == r.metadata.id
        case (.recordDetail(let l1, let l2), .recordDetail(let r1, let r2)):
            return l1 == r1 && l2.id == r2.id
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
    
    func updateCurrentTemplate(_ template: TemplateFile) {
        if case let .createTemplate(language, _) = currentRoute {
            currentRoute = .createTemplate(language, template)
        }
    }
} 