import SwiftUI

enum Route: Hashable {
    case languageSection(String)
    case templateDetail(TemplateFile)
    case createTemplate(String)
    case recordDetail(templateId: String, record: RecordData)
    case recording(TemplateFile)
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .languageSection(let language):
            hasher.combine(0)
            hasher.combine(language)
        case .templateDetail(let template):
            hasher.combine(1)
            hasher.combine(template.metadata.id)
        case .createTemplate(let language):
            hasher.combine(2)
            hasher.combine(language)
        case .recordDetail(let templateId, let record):
            hasher.combine(3)
            hasher.combine(templateId)
            hasher.combine(record.id)
        case .recording(let template):
            hasher.combine(4)
            hasher.combine(template.metadata.id)
        }
    }
    
    static func == (lhs: Route, rhs: Route) -> Bool {
        switch (lhs, rhs) {
        case (.languageSection(let l), .languageSection(let r)):
            return l == r
        case (.templateDetail(let l), .templateDetail(let r)):
            return l.metadata.id == r.metadata.id
        case (.createTemplate(let l), .createTemplate(let r)):
            return l == r
        case (.recordDetail(let l1, let l2), .recordDetail(let r1, let r2)):
            return l1 == r1 && l2.id == r2.id
        case (.recording(let l), .recording(let r)):
            return l.metadata.id == r.metadata.id
        default:
            return false
        }
    }
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