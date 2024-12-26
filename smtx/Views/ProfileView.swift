import SwiftUI

struct ProfileView: View {
    @State private var showingEmailRegister = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 头部图标
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .foregroundColor(.gray)
                    .padding(.top, 60)
                
                Text("登录后体验更多功能")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 登录按钮
                VStack(spacing: 16) {
                    Button(action: {
                        showingEmailRegister = true
                    }) {
                        Text("邮箱注册")
                            .font(.headline)
                            .foregroundColor(.white)
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
                .padding(.bottom, 40)
            }
            .navigationTitle("个人中心")
            .sheet(isPresented: $showingEmailRegister) {
                EmailRegisterView()
            }
        }
    }
}

#Preview {
    ProfileView()
} 