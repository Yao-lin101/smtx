import SwiftUI

// 九宫格辅助线视图
struct GridLines: View {
    let rect: CGRect
    
    var body: some View {
        ZStack {
            // 垂直线
            ForEach(1...2, id: \.self) { i in
                Rectangle()
                    .fill(.white.opacity(0.5))
                    .frame(width: 1)
                    .offset(x: rect.width * CGFloat(i) / 3 - rect.width / 2)
            }
            
            // 水平线
            ForEach(1...2, id: \.self) { i in
                Rectangle()
                    .fill(.white.opacity(0.5))
                    .frame(height: 1)
                    .offset(y: rect.height * CGFloat(i) / 3 - rect.height / 2)
            }
        }
        .frame(width: rect.width, height: rect.height)
    }
}

// 图片裁剪视图
struct ImageCropperView: View {
    let image: UIImage
    let aspectRatio: CGFloat // 宽高比例，例如16:9为1.777...
    let onCrop: (UIImage) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var initialScale: CGFloat = 1
    
    init(image: UIImage, aspectRatio: CGFloat = 16/9, onCrop: @escaping (UIImage) -> Void) {
        self.image = image
        self.aspectRatio = aspectRatio
        self.onCrop = onCrop
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let viewWidth = geometry.size.width
                let viewHeight = geometry.size.height
                
                // 计算裁剪框的尺寸
                let cropWidth = viewWidth * 0.9 // 留一些边距
                let cropHeight = cropWidth / aspectRatio
                let cropRect = CGRect(
                    x: (viewWidth - cropWidth) / 2,
                    y: (viewHeight - cropHeight) / 2,
                    width: cropWidth,
                    height: cropHeight
                )
                
                // 计算图片的初始缩放比例
                let imageAspect = image.size.width / image.size.height
                let cropAspect = cropWidth / cropHeight
                
                // 计算图片在视图中的实际尺寸
                let imageViewSize: CGSize = {
                    if imageAspect > cropAspect {
                        // 图片比裁剪框更宽，以裁剪框高度为基准
                        let height = cropHeight
                        let width = height * imageAspect
                        return CGSize(width: width, height: height)
                    } else {
                        // 图片比裁剪框更窄，以裁剪框宽度为基准
                        let width = cropWidth
                        let height = width / imageAspect
                        return CGSize(width: width, height: height)
                    }
                }()
                
                ZStack {
                    Color.black
                    
                    // 裁剪区域遮罩
                    Rectangle()
                        .fill(.black.opacity(0.5))
                        .overlay(
                            Rectangle()
                                .frame(width: cropRect.width, height: cropRect.height)
                                .blendMode(.destinationOut)
                        )
                        .compositingGroup()
                    
                    // 图片
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: imageViewSize.width, height: imageViewSize.height)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    var newOffset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                    
                                    // 计算图片的实际尺寸
                                    let scaledWidth = imageViewSize.width * scale
                                    let scaledHeight = imageViewSize.height * scale
                                    
                                    // 计算最大允许的偏移量
                                    let maxOffsetX = max(0, (scaledWidth - cropWidth) / 2)
                                    let maxOffsetY = max(0, (scaledHeight - cropHeight) / 2)
                                    
                                    // 限制偏移范围
                                    newOffset.width = max(-maxOffsetX, min(maxOffsetX, newOffset.width))
                                    newOffset.height = max(-maxOffsetY, min(maxOffsetY, newOffset.height))
                                    
                                    offset = newOffset
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = max(1, value)
                                }
                                .onEnded { _ in
                                    // 确保缩放后图片仍然覆盖裁剪区域
                                    let minScale = max(
                                        cropWidth / imageViewSize.width,
                                        cropHeight / imageViewSize.height
                                    )
                                    scale = max(minScale, scale)
                                    
                                    // 调整偏移量确保图片覆盖裁剪区域
                                    let scaledWidth = imageViewSize.width * scale
                                    let scaledHeight = imageViewSize.height * scale
                                    
                                    let maxOffsetX = max(0, (scaledWidth - cropWidth) / 2)
                                    let maxOffsetY = max(0, (scaledHeight - cropHeight) / 2)
                                    
                                    offset.width = max(-maxOffsetX, min(maxOffsetX, offset.width))
                                    offset.height = max(-maxOffsetY, min(maxOffsetY, offset.height))
                                    lastOffset = offset
                                }
                        )
                    
                    // 裁剪框
                    Rectangle()
                        .stroke(.white, lineWidth: 2)
                        .frame(width: cropRect.width, height: cropRect.height)
                    
                    // 九宫格辅助线
                    GridLines(rect: cropRect)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("取消")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        cropImage()
                    }) {
                        Text("完成")
                    }
                }
            }
        }
    }
    
    private func cropImage() {
        // 计算实际的裁剪区域
        let imageSize = image.size
        let imageAspect = imageSize.width / imageSize.height
        
        var drawRect = CGRect.zero
        var cropRect = CGRect.zero
        
        if imageAspect > aspectRatio {
            // 图片更宽，需要裁剪两边
            let newWidth = imageSize.height * aspectRatio
            let xOffset = (imageSize.width - newWidth) / 2
            drawRect = CGRect(x: -xOffset, y: 0, width: imageSize.width, height: imageSize.height)
            cropRect = CGRect(x: 0, y: 0, width: newWidth, height: imageSize.height)
        } else {
            // 图片更高，需要裁剪上下
            let newHeight = imageSize.width / aspectRatio
            let yOffset = (imageSize.height - newHeight) / 2
            drawRect = CGRect(x: 0, y: -yOffset, width: imageSize.width, height: imageSize.height)
            cropRect = CGRect(x: 0, y: 0, width: imageSize.width, height: newHeight)
        }
        
        // 应用缩放和偏移
        let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
        let offsetTransform = CGAffineTransform(translationX: offset.width, y: offset.height)
        let finalTransform = scaleTransform.concatenating(offsetTransform)
        
        // 创建裁剪上下文
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        
        let renderer = UIGraphicsImageRenderer(size: cropRect.size, format: format)
        let croppedImage = renderer.image { context in
            context.cgContext.setFillColor(UIColor.black.cgColor)
            context.cgContext.fill(cropRect)
            
            context.cgContext.concatenate(finalTransform)
            image.draw(in: drawRect)
        }
        
        onCrop(croppedImage)
        dismiss()
    }
} 