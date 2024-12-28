import SwiftUI

struct AdminUsersView: View {
    @StateObject private var viewModel = AdminViewModel()
    @State private var searchText = ""
    @State private var userToToggle: User?
    @State private var showingConfirmation = false
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        List {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索 UID", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        searchTask?.cancel()
                        searchTask = Task {
                            await viewModel.searchUsers(query: searchText)
                        }
                    }
                if !searchText.isEmpty {
                    Button(action: { 
                        searchText = ""
                        Task {
                            await viewModel.searchUsers(query: "")
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .listRowInsets(EdgeInsets())
            .padding(.horizontal)
            
            // 用户列表
            if viewModel.users.isEmpty && !viewModel.isLoading {
                Text(searchText.isEmpty ? "暂无用户" : "未找到相关用户")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.users) { user in
                    UserRow(user: user) {
                        userToToggle = user
                        showingConfirmation = true
                    }
                    .task {
                        await viewModel.loadMoreIfNeeded(currentUser: user)
                    }
                }
                
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .alert("确认操作", isPresented: $showingConfirmation) {
            Button("取消", role: .cancel) { }
            Button(userToToggle?.isActive == true ? "封禁" : "解封", role: .destructive) {
                if let user = userToToggle {
                    Task {
                        await viewModel.toggleUserBan(uid: user.uid)
                    }
                }
            }
        } message: {
            if let user = userToToggle {
                Text("确定要\(user.isActive ? "封禁" : "解封")用户「\(user.username)」吗？")
            }
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .navigationTitle("用户管理")
    }
}

struct UserRow: View {
    let user: User
    let onToggleBan: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(user.username)
                        .font(.headline)
                    if !user.isActive {
                        Text("已封禁")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                    }
                }
                Text(user.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("UID: \(user.uid)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onToggleBan) {
                Image(systemName: user.isActive ? "lock.open" : "lock")
                    .foregroundColor(user.isActive ? .blue : .red)
                    .font(.title2)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        AdminUsersView()
    }
} 