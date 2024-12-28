import SwiftUI

struct AdminPanelView: View {
    @EnvironmentObject private var router: NavigationRouter
    
    var body: some View {
        List {
            Section {
                NavigationLink(value: Route.adminUsers) {
                    Label("用户管理", systemImage: "person.2")
                }
                
                NavigationLink(value: Route.adminLanguageSections) {
                    Label("语言分区管理", systemImage: "folder.badge.gearshape")
                }
            } header: {
                Text("系统管理")
            }
        }
        .navigationTitle("后台管理")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AdminPanelView()
            .environmentObject(NavigationRouter())
    }
} 