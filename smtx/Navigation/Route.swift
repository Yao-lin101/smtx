import Foundation

enum Route: Hashable, Identifiable {
    // 模板相关路由
    case languageSection(String)
    case templateDetail(String)
    case createTemplate(String, String?)
    case recording(String, String?)
    
    // 云模板相关路由
    case cloudTemplateDetail(String)
    
    // 个人中心路由
    case profile
    case profileDetail
    case settings
    case about
    case help
    case avatarPreview(String)
    case emailRegister
    
    var id: String {
        switch self {
        case .languageSection(let language):
            return "languageSection-\(language)"
        case .templateDetail(let templateId):
            return "templateDetail-\(templateId)"
        case .createTemplate(let language, let templateId):
            return "createTemplate-\(language)-\(templateId ?? "new")"
        case .recording(let templateId, let recordId):
            return "recording-\(templateId)-\(recordId ?? "new")"
        case .profile:
            return "profile"
        case .profileDetail:
            return "profileDetail"
        case .settings:
            return "settings"
        case .about:
            return "about"
        case .help:
            return "help"
        case .avatarPreview(let url):
            return "avatarPreview-\(url)"
        case .emailRegister:
            return "emailRegister"
        case .cloudTemplateDetail(let uid):
            return "cloudTemplateDetail-\(uid)"
        }
    }
    
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
        case .cloudTemplateDetail(let uid):
            hasher.combine(11)
            hasher.combine(uid)
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
             (.help, .help),
             (.emailRegister, .emailRegister):
            return true
        case (.avatarPreview(let l), .avatarPreview(let r)):
            return l == r
        case (.cloudTemplateDetail(let l), .cloudTemplateDetail(let r)):
            return l == r
        default:
            return false
        }
    }
    
    var title: String {
        switch self {
        case .languageSection(let language):
            return language
        case .templateDetail:
            return "模板详情"
        case .createTemplate(_, let templateId):
            return templateId == nil ? "创建模板" : "编辑模板"
        case .recording:
            return "录音"
        case .profile:
            return "个人中心"
        case .profileDetail:
            return "个人资料"
        case .settings:
            return "设置"
        case .about:
            return "关于"
        case .help:
            return "帮助"
        case .avatarPreview:
            return "预览"
        case .emailRegister:
            return "邮箱注册"
        case .cloudTemplateDetail:
            return "模板详情"
        }
    }
} 