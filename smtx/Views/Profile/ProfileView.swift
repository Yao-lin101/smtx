import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var router: NavigationRouter
    @State private var showingEmailRegister = false
    @State private var emailPrefix = ""
    @State private var selectedDomain = "@qq.com"
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingProfileDetail = false
    @State private var showingAvatarPreview = false
    
    // 邮箱域名选项
    let emailDomains = [
        "@qq.com",
        "@163.com",
        "@126.com",
        "@gmail.com",
        "@outlook.com",
        "@hotmail.com"
    ]
    
    var email: String {
        emailPrefix + selectedDomain
    }
    
    var body: some View {
        if userStore.isAuthenticated {
            // 已登录状态
            ScrollView {
                VStack(spacing: 24) {
                    // 用户头像和基本信息
                    VStack(spacing: 16) {
                        if let user = userStore.currentUser {
                            if let avatar = user.avatar, !avatar.isEmpty {
                                Button {
                                    showingAvatarPreview = true
                                } label: {
                                    CachedAsyncImage(url: URL(string: avatar)) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 100, height: 100)
                                                .clipShape(Circle())
                                                .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                                        case .empty, .failure:
                                            Image(systemName: "person.circle.fill")
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 100, height: 100)
                                                .foregroundColor(.blue)
                                        @unknown default:
                                            ProgressView()
                                                .frame(width: 100, height: 100)
                                        }
                                    }
                                }
                                .sheet(isPresented: $showingAvatarPreview) {
                                    AvatarPreviewView(imageURL: avatar)
                                }
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 100, height: 100)
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(spacing: 8) {
                                Text(user.username)
                                    .font(.title2)
                                    .bold()
                                
                                Text(user.bio ?? "这个人很懒，什么都没写")
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color(.systemBackground))
                    
                    // 用户数据统计
                    HStack(spacing: 0) {
                        StatisticView(title: "模板", value: "0")
                        Divider()
                        StatisticView(title: "录音", value: "0")
                        Divider()
                        StatisticView(title: "收藏", value: "0")
                    }
                    .frame(height: 80)
                    .background(Color(.systemBackground))
                    
                    // 功能列表
                    VStack(spacing: 0) {
                        MenuRow(
                            icon: "person.fill", 
                            title: "个人资料",
                            action: { router.navigate(to: .profileDetail) }
                        )
                        Divider()
                        MenuRow(
                            icon: "gear", 
                            title: "设置",
                            action: { router.navigate(to: .settings) }
                        )
                        Divider()
                        MenuRow(
                            icon: "questionmark.circle", 
                            title: "帮助与反馈",
                            action: { router.navigate(to: .help) }
                        )
                        Divider()
                        MenuRow(
                            icon: "info.circle", 
                            title: "关于",
                            action: { router.navigate(to: .about) }
                        )
                        Divider()
                        if let user = userStore.currentUser {
                            if user.isSuperuser {
                                MenuRow(
                                    icon: "gearshape.2.fill",
                                    title: "后台管理",
                                    action: { router.navigate(to: .adminPanel) }
                                )
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    
                    // 退出登录按钮
                    Button(action: {
                        userStore.logout()
                    }) {
                        Text("退出登录")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
        } else {
            // 未登录状态
            VStack(spacing: 24) {
                // 头部图标
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .foregroundColor(.gray)
                    .padding(.top, 40)
                
                // 登录表单
                VStack(spacing: 16) {
                    VStack(spacing: 8) {  // 邮箱和密码输入框放在一起，间距设为8
                        // 邮箱输入区域
                        HStack(spacing: 0) {
                            TextField("邮箱前缀", text: $emailPrefix)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .textContentType(.emailAddress)
                                .disabled(isLoggingIn)
                            
                            Picker("", selection: $selectedDomain) {
                                ForEach(emailDomains, id: \.self) { domain in
                                    Text(domain).tag(domain)
                                }
                            }
                            .labelsHidden()
                            .disabled(isLoggingIn)
                        }
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                        // 隐藏的自动填充阻止器
                        Section {
                            HStack {
                                TextField("", text: .constant(""))
                                    .disabled(true)
                            }
                        }
                        .frame(height: 0)
                        
                        SecureField("密码", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(isLoggingIn)
                    }
                    
                    Button(action: login) {
                        if isLoggingIn {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white)
                                Text("登录")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(emailPrefix.isEmpty || password.isEmpty || isLoggingIn ? Color.blue.opacity(0.5) : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(emailPrefix.isEmpty || password.isEmpty || isLoggingIn)
                }
                .padding(.horizontal, 20)
                
                Text("还没有账号？")
                    .foregroundColor(.secondary)
                
                // 注册按钮
                VStack(spacing: 16) {
                    Button(action: {
                        showingEmailRegister = true
                    }) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.white)
                            Text("邮箱注册")
                                .foregroundColor(.white)
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        // TODO: 实现微信登录功能
                    }) {
                        HStack {
                            Image(systemName: "message.fill")
                                .foregroundColor(.white)
                            Text("微信登录")
                                .foregroundColor(.white)
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.green)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 20)
                Spacer()
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingEmailRegister) {
                EmailRegisterView()
            }
            .alert("提示", isPresented: $showingAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func login() {
        isLoggingIn = true
        
        Task {
            do {
                let response = try await AuthService.shared.login(
                    email: email,
                    password: password
                )
                
                // 更新用户状态
                await MainActor.run {
                    userStore.handleLoginSuccess(
                        user: response.user,
                        accessToken: response.access,
                        refreshToken: response.refresh
                    )
                    
                    // 清空表单
                    emailPrefix = ""
                    password = ""
                    isLoggingIn = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    showingAlert = true
                    isLoggingIn = false
                }
            }
        }
    }
}

// 统计数据视图
struct StatisticView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .bold()
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// 菜单行视图
struct MenuRow: View {
    let icon: String
    let title: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.footnote)
            }
            .padding(.horizontal, 20)
            .frame(height: 44)
        }
    }
}

#Preview {
    ProfileView()
} 