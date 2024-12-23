import SwiftUI
import PhotosUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct CreateTemplateView: View {
    let language: String
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var coverImage: Image?
    @State private var originalCoverImage: UIImage?
    @State private var timelineItems: [TimelineItemData] = []
    @State private var showingTimelineEditor = false
    @State private var showingCropper = false
    @State private var originalUIImage: UIImage?
    @State private var templateId: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("模板标题", text: $title)
                    coverImageSection
                }
                
                Section("时间轴项目") {
                    timelineItemsSection
                }
            }
            .navigationTitle("新建模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // 如果已经创建了模板，需要删除它
                        if let templateId = templateId {
                            try? TemplateStorage.shared.deleteTemplate(templateId: templateId)
                        }
                        dismiss()
                    }) {
                        Text("取消")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        createTemplate()
                    }) {
                        Text("创建")
                    }
                    .disabled(title.isEmpty || originalCoverImage == nil)
                }
            }
            .sheet(isPresented: $showingTimelineEditor) {
                TimelineEditorView(templateId: templateId ?? "", timelineItems: $timelineItems)
            }
            .sheet(isPresented: $showingCropper) {
                if let image = originalUIImage {
                    ImageCropperView(image: image) { croppedImage in
                        originalCoverImage = croppedImage
                        coverImage = Image(uiImage: croppedImage)
                        createTemplateIfNeeded(with: croppedImage)
                    }
                }
            }
        }
    }
    
    private var coverImageSection: some View {
        VStack(alignment: .leading) {
            Text("封面图片")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            PhotosPicker(selection: $selectedImage,
                       matching: .images,
                       photoLibrary: .shared()) {
                if let coverImage = coverImage {
                    coverImage
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 200)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        }
                }
            }
            .onChange(of: selectedImage) { newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        if let uiImage = UIImage(data: data) {
                            originalUIImage = uiImage
                            showingCropper = true
                            selectedImage = nil
                        }
                    }
                }
            }
        }
    }
    
    private var timelineItemsSection: some View {
        Group {
            if timelineItems.isEmpty {
                Text("点击下方按钮添加时间轴项目")
                    .foregroundColor(.secondary)
            } else {
                ForEach(timelineItems) { item in
                    TimelineItemRow(item: item)
                }
                .onDelete(perform: deleteTimelineItem)
            }
            
            Button(action: { showingTimelineEditor = true }) {
                Label("添加时间轴项目", systemImage: "plus.circle.fill")
            }
        }
    }
    
    private func createTemplateIfNeeded(with image: UIImage) {
        if templateId == nil {
            do {
                templateId = try TemplateStorage.shared.createTemplate(
                    title: title,
                    language: language,
                    coverImage: image
                )
            } catch {
                print("Error creating template: \(error)")
            }
        }
    }
    
    private func deleteTimelineItem(at offsets: IndexSet) {
        timelineItems.remove(atOffsets: offsets)
        
        // 更新模板的时间轴项目
        if let templateId = templateId {
            do {
                var template = try TemplateStorage.shared.loadTemplate(templateId: templateId)
                template.template.timelineItems = timelineItems.map { item in
                    TemplateData.TimelineItem(
                        id: item.id.uuidString,
                        timestamp: item.timestamp,
                        script: item.script,
                        image: item.imageURL?.lastPathComponent ?? ""
                    )
                }
                template.metadata.updatedAt = Date()
                try TemplateStorage.shared.saveTemplate(template)
            } catch {
                print("Error updating template: \(error)")
            }
        }
    }
    
    private func createTemplate() {
        guard let templateId = templateId else { return }
        
        do {
            var template = try TemplateStorage.shared.loadTemplate(templateId: templateId)
            template.template.title = title
            template.metadata.updatedAt = Date()
            
            // 更新总时长
            let totalDuration = timelineItems.map { $0.timestamp }.max() ?? 0
            template.template.totalDuration = totalDuration
            
            try TemplateStorage.shared.saveTemplate(template)
            dismiss()
        } catch {
            print("Error updating template: \(error)")
        }
    }
}

// 图片裁剪视图
struct ImageCropperView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var initialScale: CGFloat = 1
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let viewWidth = geometry.size.width
                let viewHeight = geometry.size.height
                
                // 计算16:9裁剪框的尺寸
                let cropWidth = viewWidth * 0.9 // 留一些边距
                let cropHeight = cropWidth * 9/16
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
        let cropAspect: CGFloat = 16.0 / 9.0
        
        var drawRect = CGRect.zero
        var cropRect = CGRect.zero
        
        if imageAspect > cropAspect {
            // 图片更宽，需要裁剪两边
            let newWidth = imageSize.height * cropAspect
            let xOffset = (imageSize.width - newWidth) / 2
            drawRect = CGRect(x: -xOffset, y: 0, width: imageSize.width, height: imageSize.height)
            cropRect = CGRect(x: 0, y: 0, width: newWidth, height: imageSize.height)
        } else {
            // 图片更高，需要裁剪上下
            let newHeight = imageSize.width / cropAspect
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

// 时间轴项目数据模型
struct TimelineItemData: Identifiable {
    let id = UUID()
    var script: String
    var imageURL: URL?
    var timestamp: Double
}

// 时间轴项目行视图
struct TimelineItemRow: View {
    let item: TimelineItemData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageURL = item.imageURL {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 100)
                }
            }
            
            Text(item.script)
                .font(.body)
            
            Text(String(format: "时间点：%.1f秒", item.timestamp))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// 时间轴编辑器视图
struct TimelineEditorView: View {
    let templateId: String
    @Environment(\.dismiss) private var dismiss
    @Binding var timelineItems: [TimelineItemData]
    @State private var script = ""
    @State private var timestamp = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var previewImage: Image?
    @State private var originalImage: UIImage?
    @State private var hasImage = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("图片") {
                    PhotosPicker(selection: $selectedImage,
                               matching: .images,
                               photoLibrary: .shared()) {
                        if let previewImage = previewImage {
                            previewImage
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 200)
                                .overlay {
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundColor(.secondary)
                                }
                        }
                    }
                }
                
                Section("台词") {
                    TextEditor(text: $script)
                        .frame(height: 100)
                }
                
                Section("时间点") {
                    TextField("时间（秒）", text: $timestamp)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("添加时间轴项目")
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
                        if let time = Double(timestamp),
                           !script.isEmpty,
                           let image = originalImage {
                            Task(priority: .userInitiated) {
                                do {
                                    let itemId = try TemplateStorage.shared.saveTimelineItem(
                                        templateId: templateId,
                                        timestamp: time,
                                        script: script,
                                        image: image
                                    )
                                    
                                    // 加载模板以获取新的时间轴项目URL
                                    let template = try TemplateStorage.shared.loadTemplate(templateId: templateId)
                                    if let item = template.template.timelineItems.last,
                                       let baseURL = TemplateStorage.shared.getTemplateDirectoryURL(templateId: templateId) {
                                        let imageURL = baseURL.appendingPathComponent(item.image)
                                        let timelineItem = TimelineItemData(
                                            script: script,
                                            imageURL: imageURL,
                                            timestamp: time
                                        )
                                        timelineItems.append(timelineItem)
                                        timelineItems.sort { $0.timestamp < $1.timestamp }
                                    }
                                    dismiss()
                                } catch {
                                    print("Error saving timeline item: \(error)")
                                }
                            }
                        }
                    }) {
                        Text("添加")
                    }
                    .disabled(script.isEmpty || timestamp.isEmpty || !hasImage)
                }
            }
            .onChange(of: selectedImage) { newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        originalImage = uiImage
                        previewImage = Image(uiImage: uiImage)
                        hasImage = true
                        selectedImage = nil
                    }
                }
            }
        }
    }
} 
