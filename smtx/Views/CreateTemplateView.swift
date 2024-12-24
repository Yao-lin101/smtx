import SwiftUI
import PhotosUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct CreateTemplateView: View {
    let language: String
    let existingTemplate: TemplateFile?
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
    @State private var selectedMinutes = 0
    @State private var selectedSeconds = 5
    
    private let minutesRange = 0...10 // 0-10分钟
    private let secondsRange = 0...59 // 0-59秒
    
    init(language: String, existingTemplate: TemplateFile? = nil) {
        self.language = language
        self.existingTemplate = existingTemplate
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("模板标题", text: $title)
                    coverImageSection
                    
                    // 时长选择器
                    HStack {
                        Text("时长")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        
                        // 分钟选择器
                        Picker("", selection: $selectedMinutes) {
                            ForEach(minutesRange, id: \.self) { minute in
                                Text("\(minute)").tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 50)
                        .clipped()
                        Text("分")
                        
                        // 秒数选择器
                        Picker("", selection: $selectedSeconds) {
                            ForEach(secondsRange, id: \.self) { second in
                                Text("\(second)").tag(second)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 50)
                        .clipped()
                        Text("秒")
                    }
                    .onChange(of: selectedMinutes) { _ in
                        validateDuration()
                    }
                    .onChange(of: selectedSeconds) { _ in
                        validateDuration()
                    }
                }
                
                Section("时间轴项目") {
                    timelineItemsSection
                }
            }
            .navigationTitle(existingTemplate != nil ? "编辑模板" : "新建模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        if existingTemplate == nil, let templateId = templateId {
                            try? TemplateStorage.shared.deleteTemplate(templateId: templateId)
                        }
                        dismiss()
                    }) {
                        Text("取消")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        saveTemplate()
                    }) {
                        Text(existingTemplate != nil ? "保存" : "创建")
                    }
                    .disabled(title.isEmpty || originalCoverImage == nil)
                }
            }
            .sheet(isPresented: $showingTimelineEditor) {
                TimelineEditorView(
                    templateId: templateId ?? "",
                    totalDuration: Double(selectedMinutes * 60 + selectedSeconds),
                    timelineItems: $timelineItems
                )
            }
            .sheet(isPresented: $showingCropper) {
                if let image = originalUIImage {
                    ImageCropperView(image: image) { croppedImage in
                        originalCoverImage = croppedImage
                        coverImage = Image(uiImage: croppedImage)
                        if existingTemplate == nil {
                            createTemplateIfNeeded(with: croppedImage)
                        }
                    }
                }
            }
            .onAppear {
                loadExistingTemplate()
            }
        }
    }
    
    private func validateDuration() {
        let totalSeconds = selectedMinutes * 60 + selectedSeconds
        
        // 确保不小于最小时长（5秒）
        if totalSeconds < 5 {
            selectedSeconds = 5
            selectedMinutes = 0
            return
        }
        
        // 确保不小于最后一个时间节点
        if let lastTimestamp = timelineItems.map({ $0.timestamp }).max() {
            let requiredSeconds = Int(ceil(lastTimestamp))
            let requiredMinutes = requiredSeconds / 60
            let requiredRemainingSeconds = requiredSeconds % 60
            
            if totalSeconds < requiredSeconds {
                selectedMinutes = requiredMinutes
                selectedSeconds = requiredRemainingSeconds
            }
        }
    }
    
    private func loadExistingTemplate() {
        guard let template = existingTemplate else { return }
        
        // 加载模板数据
        title = template.template.title
        templateId = template.metadata.id
        
        // 设置时长
        let duration = template.template.totalDuration
        selectedMinutes = Int(duration) / 60
        selectedSeconds = Int(duration) % 60
        
        // 加载封面图片
        if let baseURL = TemplateStorage.shared.getTemplateDirectoryURL(templateId: template.metadata.id),
           let imageData = try? Data(contentsOf: baseURL.appendingPathComponent(template.template.coverImage)),
           let uiImage = UIImage(data: imageData) {
            originalCoverImage = uiImage
            coverImage = Image(uiImage: uiImage)
        }
        
        // 加载时间轴项目
        timelineItems = template.template.timelineItems.map { item in
            let imageURL = TemplateStorage.shared.getTemplateDirectoryURL(templateId: template.metadata.id)?
                .appendingPathComponent(item.image)
            return TimelineItemData(
                script: item.script,
                imageURL: imageURL,
                timestamp: item.timestamp
            )
        }
    }
    
    private func saveTemplate() {
        if existingTemplate != nil {
            updateExistingTemplate()
        } else {
            createTemplateIfNeeded(with: originalCoverImage!)
        }
    }
    
    private func updateExistingTemplate() {
        guard let templateId = templateId,
              let coverImage = originalCoverImage else { return }
        
        do {
            var template = try TemplateStorage.shared.loadTemplate(templateId: templateId)
            
            // 更新基本信息
            template.template.title = title
            template.metadata.updatedAt = Date()
            template.template.totalDuration = Double(selectedMinutes * 60 + selectedSeconds)
            
            // 保存封面图片
            if let imageData = coverImage.jpegData(compressionQuality: 0.8) {
                let coverImageName = "cover.jpg"
                if let baseURL = TemplateStorage.shared.getTemplateDirectoryURL(templateId: templateId) {
                    try imageData.write(to: baseURL.appendingPathComponent(coverImageName))
                    template.template.coverImage = coverImageName
                }
            }
            
            // 更新时间轴项目
            template.template.timelineItems = timelineItems.map { item in
                let imagePath = item.imageURL?.lastPathComponent ?? ""
                let fullPath = imagePath.isEmpty ? "" : "images/\(imagePath)"
                return TemplateData.TimelineItem(
                    id: item.id.uuidString,
                    timestamp: item.timestamp,
                    script: item.script,
                    image: fullPath
                )
            }
            
            // 保存所有更改
            try TemplateStorage.shared.saveTemplate(template)
            
            // 重新加载最新的模板数据
            let updatedTemplate = try TemplateStorage.shared.loadTemplate(templateId: templateId)
            
            // 发送模板更新通知并关闭视图
            NotificationCenter.default.post(name: .templateDidUpdate, object: updatedTemplate)
            dismiss()
        } catch {
            print("Error updating template: \(error)")
        }
    }
    
    private func createTemplateIfNeeded(with image: UIImage) {
        do {
            if templateId == nil {
                templateId = try TemplateStorage.shared.createTemplate(
                    title: title,
                    language: language,
                    coverImage: image
                )
                
                // 创建新模板后，不要自动退出，让用户继续编辑
                originalCoverImage = image
                coverImage = Image(uiImage: image)
            } else {
                // 如果已经有模板ID，说明是在编辑现有模板
                updateExistingTemplate()
            }
        } catch {
            print("Error creating/updating template: \(error)")
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
    
    private func deleteTimelineItem(at offsets: IndexSet) {
        timelineItems.remove(atOffsets: offsets)
        
        // 更新模板的时间轴项目
        if let templateId = templateId {
            do {
                var template = try TemplateStorage.shared.loadTemplate(templateId: templateId)
                template.template.timelineItems = timelineItems.map { item in
                    let imagePath = item.imageURL?.lastPathComponent ?? ""
                    let fullPath = imagePath.isEmpty ? "" : "images/\(imagePath)"
                    return TemplateData.TimelineItem(
                        id: item.id.uuidString,
                        timestamp: item.timestamp,
                        script: item.script,
                        image: fullPath
                    )
                }
                template.metadata.updatedAt = Date()
                try TemplateStorage.shared.saveTemplate(template)
            } catch {
                print("Error updating template: \(error)")
            }
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
