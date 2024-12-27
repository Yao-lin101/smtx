import SwiftUI
import PhotosUI

struct ProfileView: View {
    @StateObject private var userStore = UserStore.shared
    @State private var showingEmailRegister = false
    @State private var emailPrefix = ""
    @State private var selectedDomain = "@qq.com"
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingProfileDetail = false
    
    // 头像相关状态
    @State private var showingImagePicker = false
    @State private var showingImageCropper = false
    @State private var selectedImage: PhotosPickerItem?
    @State private var tempUIImage: UIImage?
    @State private var isUploadingAvatar = false
    
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
        NavigationStack {
            if userStore.isAuthenticated {
                // 已登录状态
                ScrollView {
                    VStack(spacing: 24) {
                        // 用户头像和基本信息
                        VStack(spacing: 16) {
                            PhotosPicker(selection: $selectedImage,
                                       matching: .images,
                                       photoLibrary: .shared()) {
                                if let user = userStore.currentUser {
                                    if let avatar = user.avatar, !avatar.isEmpty {
                                        AsyncImage(url: URL(string: avatar)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 100, height: 100)
                                                .clipShape(Circle())
                                                .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                                        } placeholder: {
                                            ProgressView()
                                                .frame(width: 100, height: 100)
                                        }
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 100, height: 100)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .onChange(of: selectedImage) { newValue in
                                Task {
                                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        tempUIImage = uiImage
                                        showingImageCropper = true
                                        selectedImage = nil
                                    }
                                }
                            }
                            .padding(.top, 20)
                            
                            if let user = userStore.currentUser {
                                VStack(spacing: 8) {
                                    Text(user.username)
                                        .font(.title2)
                                        .bold()
                                    
                                    Text(user.email)
                                        .foregroundColor(.secondary)
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
                                action: { showingProfileDetail = true }
                            )
                            Divider()
                            MenuRow(
                                icon: "gear", 
                                title: "设置",
                                action: {
                                    // TODO: 实现设置功能
                                }
                            )
                            Divider()
                            MenuRow(
                                icon: "questionmark.circle", 
                                title: "帮助与反馈",
                                action: {
                                    // TODO: 实现帮助与反馈功能
                                }
                            )
                            Divider()
                            MenuRow(
                                icon: "info.circle", 
                                title: "关于",
                                action: {
                                    // TODO: 实现关于功能
                                }
                            )
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
                .sheet(isPresented: $showingProfileDetail) {
                    ProfileDetailView()
                        .environmentObject(userStore)
                }
                .sheet(isPresented: $showingImageCropper) {
                    if let image = tempUIImage {
                        ImageCropperView(image: image, aspectRatio: 1) { croppedImage in
                            uploadAvatar(croppedImage)
                        }
                    }
                }
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
                        VStack(spacing: 8) {  // 将邮箱和密码输入框放在一起，间距设为8
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
            }
        }
        .navigationTitle("个人中心")
        .sheet(isPresented: $showingEmailRegister) {
            EmailRegisterView()
        }
        .alert("提示", isPresented: $showingAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
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
    
    private func uploadAvatar(_ image: UIImage) {
        Task {
            do {
                isUploadingAvatar = true
                let updatedUser = try await AuthService.shared.uploadAvatar(image)
                await MainActor.run {
                    userStore.updateUserInfo(updatedUser)
                    isUploadingAvatar = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                    isUploadingAvatar = false
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