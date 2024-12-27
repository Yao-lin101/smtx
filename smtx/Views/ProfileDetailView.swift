import SwiftUI
import PhotosUI

// 1. 头像部分组件
struct AvatarSection: View {
    let avatar: String?
    let onImageSelect: () -> Void
    
    var body: some View {
        VStack {
            Button(action: onImageSelect) {
                if let avatar = avatar, !avatar.isEmpty {
                    AsyncImage(url: URL(string: avatar)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .foregroundColor(.blue)
                }
            }
            
            Text("点击更换头像")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.top, 20)
    }
}

// 2. 用户信息部分组件
struct UserInfoSection: View {
    let user: User
    let onEditUsername: () -> Void
    let onEditBio: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            InfoRow(title: "昵称", content: user.username, isEditable: true, onEdit: onEditUsername)
            Divider()
            
            InfoRow(title: "简介", content: user.bio ?? "未设置", isEditable: true, onEdit: onEditBio)
            Divider()
            
            InfoRow(title: "UID", content: user.uid)
            Divider()
            
            InfoRow(title: "邮箱", content: user.email, showBindButton: !user.isEmailVerified)
            Divider()
            
            InfoRow(title: "微信", content: user.wechatId ?? "未绑定", showBindButton: user.wechatId == nil)
        }
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

// 3. 主视图
struct ProfileDetailView: View {
    @EnvironmentObject var userStore: UserStore
    @Environment(\.dismiss) var dismiss
    @State private var showingImagePicker = false
    @State private var showingImageCropper = false
    @State private var selectedImage: PhotosPickerItem?
    @State private var tempUIImage: UIImage?
    @State private var isUploadingAvatar = false
    @State private var editingUsername = false
    @State private var editingBio = false
    @State private var newUsername = ""
    @State private var newBio = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingToast = false
    @State private var showingBioEditor = false
    @State private var toastType: ToastView.ToastType = .success
    
    private let usernameMaxLength = 20  // 添加用户名最大长度常量
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let user = userStore.currentUser {
                        AvatarSection(
                            avatar: user.avatar,
                            onImageSelect: { showingImagePicker = true }
                        )
                        
                        UserInfoSection(
                            user: user,
                            onEditUsername: { startEditingUsername() },
                            onEditBio: { startEditingBio() }
                        )
                    }
                }
            }
            .navigationTitle("个人资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") { dismiss() }
                }
            }
            .photosPicker(isPresented: $showingImagePicker,
                         selection: $selectedImage,
                         matching: .images,
                         photoLibrary: .shared())
            .onChange(of: selectedImage) { newValue in
                handleImageSelected(newValue)
            }
            .sheet(isPresented: $showingImageCropper) {
                if let image = tempUIImage {
                    ImageCropperView(image: image, aspectRatio: 1) { croppedImage in
                        uploadAvatar(croppedImage)
                    }
                }
            }
            .alert("修改昵称", isPresented: $editingUsername) {
                TextField("请输入新昵称", text: Binding(
                    get: { newUsername },
                    set: { newValue in
                        if newValue.count <= usernameMaxLength {
                            newUsername = newValue
                        }
                    }
                ))
                Button("取消", role: .cancel) { }
                Button("确定") { updateUsername(newUsername) }
            } message: {
                Text("1-20个字符")  // 修改提示信息
            }
            .sheet(isPresented: $showingBioEditor) {
                BioEditView(bio: $newBio) { updatedBio in
                    updateBio(updatedBio)
                }
            }
            .alert("提示", isPresented: $showingAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .toast(isPresented: $showingToast, message: alertMessage, type: toastType)
        }
    }
    
    // MARK: - Private Methods
    private func handleImageSelected(_ item: PhotosPickerItem?) {
        Task {
            if let data = try? await item?.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    tempUIImage = uiImage
                    showingImageCropper = true
                }
            }
        }
    }
    
    private func startEditingUsername() {
        newUsername = userStore.currentUser?.username ?? ""
        editingUsername = true
    }
    
    private func startEditingBio() {
        newBio = userStore.currentUser?.bio ?? ""
        showingBioEditor = true
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
    
    private func showToast(_ message: String, type: ToastView.ToastType = .success) {
        alertMessage = message
        toastType = type
        withAnimation(.spring()) {
            showingToast = true
        }
        // 2秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring()) {
                showingToast = false
            }
        }
    }
    
    private func updateUsername(_ username: String) {
        if username.isEmpty {
            showToast("昵称不能为空", type: .error)
            return
        }
        if username.count > usernameMaxLength {
            showToast("昵称不能超过20个字符", type: .error)
            return
        }
        
        Task {
            do {
                let updatedUser = try await AuthService.shared.updateProfile(["username": username])
                await MainActor.run {
                    userStore.updateUserInfo(updatedUser)
                    showToast("昵称更新成功", type: .success)
                }
            } catch {
                await MainActor.run {
                    if let authError = error as? AuthError {
                        showToast(authError.localizedDescription, type: .error)
                    } else {
                        showToast(error.localizedDescription, type: .error)
                    }
                }
            }
        }
    }
    
    private func updateBio(_ bio: String) {
        if bio.count > 200 {
            showToast("简介不能超过200字", type: .error)
            return
        }
        
        Task {
            do {
                let updatedUser = try await AuthService.shared.updateProfile(["bio": bio])
                await MainActor.run {
                    userStore.updateUserInfo(updatedUser)
                    showToast("简介更新成功", type: .success)
                }
            } catch {
                await MainActor.run {
                    if let authError = error as? AuthError {
                        showToast(authError.localizedDescription, type: .error)
                    } else {
                        showToast(error.localizedDescription, type: .error)
                    }
                }
            }
        }
    }
}

// 保持 InfoRow 不变
struct InfoRow: View {
    let title: String
    let content: String
    var isEditable: Bool = false
    var showBindButton: Bool = false
    var onEdit: (() -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundColor(.gray)
                .frame(width: 60, alignment: .leading)
            
            if isEditable {
                HStack {
                    Text(content)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.leading)
                        .lineLimit(title == "简介" ? 4 : 1)  // 简介最多显示4行，其他内容1行
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture {
                            onEdit?()
                        }
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                        .onTapGesture {
                            onEdit?()
                        }
                }
            } else {
                HStack {
                    Text(content)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.leading)
                        .lineLimit(title == "简介" ? 4 : 1)  // 简介最多显示4行，其他内容1行
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if showBindButton {
                        Button("绑定") {
                            // TODO: 实现绑定功能
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
    }
}

struct BioEditView: View {
    @Binding var bio: String
    @Environment(\.dismiss) var dismiss
    let onSave: (String) -> Void
    
    // 添加最大字符数限制
    private let maxCharCount = 200
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                TextEditor(text: Binding(
                    get: { bio },
                    set: { newValue in
                        // 限制输入长度
                        if newValue.count <= maxCharCount {
                            bio = newValue
                        }
                    }
                ))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .background(Color(.systemBackground))
                
                // 添加字符计数显示
                HStack {
                    Spacer()
                    Text("\(bio.count)/\(maxCharCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.trailing)
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle("编辑简介")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave(bio)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileDetailView()
        .environmentObject(UserStore.shared)
} 