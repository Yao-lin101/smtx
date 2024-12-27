import SwiftUI

struct AvatarPreviewView: View {
    let imageURL: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            AsyncImage(url: URL(string: imageURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } placeholder: {
                ProgressView()
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
            }
        }
        .gesture(
            TapGesture()
                .onEnded { _ in
                    dismiss()
                }
        )
    }
}

#Preview {
    AvatarPreviewView(imageURL: "https://example.com/avatar.jpg")
} 