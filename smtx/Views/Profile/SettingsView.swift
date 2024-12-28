import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section("通用设置") {
                Text("暂未开放")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("设置")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
} 