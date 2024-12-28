import SwiftUI

struct CloudTemplatesView: View {
    @State private var showingComingSoon = true
    
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "cloud")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("云模板")
                        .font(.title2)
                        .bold()
                    
                    Text("即将推出")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
            
            Section("功能预览") {
                Label("模板同步", systemImage: "arrow.triangle.2.circlepath")
                Label("在线分享", systemImage: "square.and.arrow.up")
                Label("模板市场", systemImage: "bag")
                Label("收藏管理", systemImage: "star")
            }
            .foregroundColor(.secondary)
        }
        .alert("即将推出", isPresented: $showingComingSoon) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text("云模板功能正在开发中，敬请期待！")
        }
    }
}

#Preview {
    NavigationStack {
        CloudTemplatesView()
            .navigationTitle("云模板")
    }
} 