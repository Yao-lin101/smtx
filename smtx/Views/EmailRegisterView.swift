import SwiftUI

struct EmailRegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.userStore) private var userStore
    
    // 表单数据
    @State private var emailPrefix = ""
    @State private var selectedDomain = "@qq.com"
    @State private var verificationCode = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    // UI 状态
    @State private var isRequestingCode = false
    @State private var isRegistering = false
    @State private var countdown = 0
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
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
    
    var isEmailValid: Bool {
        !emailPrefix.isEmpty && emailPrefix.range(of: "^[a-zA-Z0-9_-]+$", options: .regularExpression) != nil
    }
    
    var isPasswordValid: Bool {
        let passwordRegex = "^(?=.*[A-Za-z])(?=.*\\d)[A-Za-z\\d]{8,20}$"
        return password.range(of: passwordRegex, options: .regularExpression) != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 邮箱输入区域
                Section {
                    HStack(spacing: 0) {
                        TextField("邮箱前缀", text: $emailPrefix)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .textContentType(.emailAddress)
                            .disabled(isRequestingCode || countdown > 0)
                        
                        Picker("", selection: $selectedDomain) {
                            ForEach(emailDomains, id: \.self) { domain in
                                Text(domain).tag(domain)
                            }
                        }
                        .labelsHidden()
                        .disabled(isRequestingCode || countdown > 0)
                    }
                } header: {
                    Text("邮箱地址")
                } footer: {
                    Text("请使用真实邮箱，验证后不可修改")
                }
                
                // 验证码区域
                Section {
                    HStack {
                        TextField("验证码", text: $verificationCode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                        
                        Spacer()
                        
                        if isRequestingCode {
                            ProgressView()
                        } else {
                            Button(action: requestVerificationCode) {
                                if countdown > 0 {
                                    Text("\(countdown)秒后重试")
                                        .foregroundColor(.gray)
                                } else {
                                    Text("获取验证码")
                                        .foregroundColor(.blue)
                                }
                            }
                            .disabled(countdown > 0 || !isEmailValid)
                        }
                    }
                }
                
                // 密码设置区域
                Section {
                    SecureField("设置密码", text: $password)
                        .textContentType(.newPassword)
                    
                    SecureField("确认密码", text: $confirmPassword)
                        .textContentType(.newPassword)
                } header: {
                    Text("密码")
                } footer: {
                    Group {
                        if !password.isEmpty && !isPasswordValid {
                            Text("密码必须包含字母和数字，长度8-20位")
                                .foregroundColor(.red)
                        } else if !confirmPassword.isEmpty && password != confirmPassword {
                            Text("两次输入的密码不一致")
                                .foregroundColor(.red)
                        } else {
                            Text("密码长度8-20位，必须包含字母和数字")
                        }
                    }
                }
            }
            .navigationTitle("邮箱注册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(isRegistering)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isRegistering {
                        ProgressView()
                    } else {
                        Button("注册") {
                            register()
                        }
                        .disabled(!canRegister)
                    }
                }
            }
            .alert("提示", isPresented: $showingAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onDisappear {
                // 清理倒计时
                countdown = 0
            }
        }
    }
    
    private var canRegister: Bool {
        isEmailValid &&
        !verificationCode.isEmpty &&
        isPasswordValid &&
        password == confirmPassword &&
        !isRegistering
    }
    
    private func requestVerificationCode() {
        guard isEmailValid else {
            alertMessage = "请输入有效的邮箱地址"
            showingAlert = true
            return
        }
        
        isRequestingCode = true
        
        Task {
            do {
                try await AuthService.shared.sendVerificationCode(email: email)
                await MainActor.run {
                    isRequestingCode = false
                    countdown = 60
                    startCountdown()
                }
            } catch {
                await MainActor.run {
                    isRequestingCode = false
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
    
    private func startCountdown() {
        guard countdown > 0 else { return }
        
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                countdown -= 1
                startCountdown()
            }
        }
    }
    
    private func register() {
        isRegistering = true
        
        Task {
            do {
                let response = try await AuthService.shared.register(
                    email: email,
                    password: password,
                    code: verificationCode
                )
                await MainActor.run {
                    isRegistering = false
                    userStore.handleRegisterSuccess(
                        user: response.user,
                        accessToken: response.access,
                        refreshToken: response.refresh
                    )
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isRegistering = false
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
}

#Preview {
    EmailRegisterView()
} 