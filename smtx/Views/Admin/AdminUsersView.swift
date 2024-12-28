import SwiftUI

struct AdminUsersView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.badge.gearshape")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("用户管理功能开发中")
                .font(.headline)
            
            Text("该功能将在后续版本中推出")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("用户管理")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AdminUsersView()
    }
} 