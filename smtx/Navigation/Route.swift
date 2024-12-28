import Foundation

enum Route: Hashable {
    // 模板相关路由
    case languageSection(String)
    case templateDetail(String)
    case createTemplate(String, String?)
    case recording(String, String?)
    
    // 个人中心路由
    case profile
    case profileDetail
    case settings
    case about
    case help
    case avatarPreview(String)
    case emailRegister  // 添加注册路由
    
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
        case .profile:
            hasher.combine(4)
        case .profileDetail:
            hasher.combine(5)
        case .settings:
            hasher.combine(6)
        case .about:
            hasher.combine(7)
        case .help:
            hasher.combine(8)
        case .avatarPreview(let url):
            hasher.combine(9)
            hasher.combine(url)
        case .emailRegister:
            hasher.combine(10)
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
        case (.profile, .profile),
             (.profileDetail, .profileDetail),
             (.settings, .settings),
             (.about, .about),
             (.help, .help):
            return true
        case (.avatarPreview(let l), .avatarPreview(let r)):
            return l == r
        case (.emailRegister, .emailRegister):
            return true
        default:
            return false
        }
    }
} 