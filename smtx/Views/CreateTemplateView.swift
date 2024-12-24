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
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var showingCancelAlert = false
    
    // 用于跟踪初始状态
    @State private var initialTitle = ""
    @State private var initialCoverImageData: Data?
    @State private var initialTimelineItems: [TimelineItemData] = []
    @State private var initialTotalDuration: Double = 5
    @State private var initialTags: [String] = []
    
    private let minutesRange = 0...10 // 0-10分钟
    private let secondsRange = 0...59 // 0-59秒
    
    init(language: String, existingTemplate: TemplateFile? = nil) {
        self.language = language
        self.existingTemplate = existingTemplate
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 封面图片
                    coverImageSection
                    
                    // 标题输入
                    titleSection
                    
                    // 标签编辑
                    tagsSection
                    
                    // 时长选择器（包含时间轴按钮）
                    durationSection
                    
                    // 时间轴预览
                    if !timelineItems.isEmpty {
                        TimelinePreviewView(
                            timelineItems: timelineItems,
                            totalDuration: Double(selectedMinutes * 60 + selectedSeconds)
                        )
                    }
                }
                .padding()
            }
            .navigationTitle(existingTemplate != nil ? "编辑模板" : "新建模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        if hasUnsavedChanges() {
                            showingCancelAlert = true
                        } else {
                            cancelAndDismiss()
                        }
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
            .alert("是否保存更改？", isPresented: $showingCancelAlert) {
                Button("取消", role: .cancel) { }
                Button("不保存", role: .destructive) {
                    cancelAndDismiss()
                }
                Button("保存") {
                    saveTemplate()
                }
            } message: {
                Text("您对模板进行了修改，是否要保存这些更改？")
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
                    ImageCropperView(image: image, aspectRatio: 4/3) { croppedImage in
                        originalCoverImage = croppedImage
                        coverImage = Image(uiImage: croppedImage)
                        if existingTemplate == nil {
                            // 只更新封面图片，不退出视图
                            do {
                                var template = try TemplateStorage.shared.loadTemplate(templateId: templateId ?? "")
                                if let imageData = croppedImage.jpegData(compressionQuality: 0.8) {
                                    let coverImageName = "cover.jpg"
                                    if let baseURL = TemplateStorage.shared.getTemplateDirectoryURL(templateId: template.metadata.id) {
                                        try imageData.write(to: baseURL.appendingPathComponent(coverImageName))
                                        template.template.coverImage = coverImageName
                                        try TemplateStorage.shared.saveTemplate(template)
                                    }
                                }
                            } catch {
                                print("Error updating cover image: \(error)")
                            }
                        }
                    }
                }
            }
            .onAppear {
                if existingTemplate != nil {
                    loadExistingTemplate()
                } else {
                    createNewTemplate()
                }
                // 保存初始状态
                saveInitialState()
            }
        }
    }
    
    private func createNewTemplate() {
        // 创建一个默认的纯色图片作为临时封面
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300))
        let defaultCoverImage = renderer.image { context in
            UIColor.systemGray5.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        }
        
        do {
            templateId = try TemplateStorage.shared.createTemplate(
                title: title,
                language: language,
                coverImage: defaultCoverImage
            )
        } catch {
            print("Error creating template: \(error)")
        }
    }
    
    private func loadExistingTemplate() {
        guard let template = existingTemplate else { return }
        
        // 加载模板数据
        title = template.template.title
        templateId = template.metadata.id
        tags = template.template.tags
        
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
            updateExistingTemplate()
        }
    }
    
    private func updateExistingTemplate() {
        guard let templateId = templateId else { return }
        
        do {
            var template = try TemplateStorage.shared.loadTemplate(templateId: templateId)
            
            // 更新基本信息
            template.template.title = title
            template.metadata.updatedAt = Date()
            template.template.totalDuration = Double(selectedMinutes * 60 + selectedSeconds)
            template.template.tags = tags
            
            // 保存封面图片
            if let coverImage = originalCoverImage,
               let imageData = coverImage.jpegData(compressionQuality: 0.8) {
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
    
    private func saveInitialState() {
        initialTitle = title
        initialCoverImageData = originalCoverImage?.jpegData(compressionQuality: 0.8)
        initialTimelineItems = timelineItems
        initialTotalDuration = Double(selectedMinutes * 60 + selectedSeconds)
        initialTags = tags
    }
    
    private func hasUnsavedChanges() -> Bool {
        // 检查标题
        if title != initialTitle { return true }
        
        // 检查封面图片
        let currentCoverImageData = originalCoverImage?.jpegData(compressionQuality: 0.8)
        if (currentCoverImageData == nil && initialCoverImageData != nil) ||
           (currentCoverImageData != nil && initialCoverImageData == nil) ||
           (currentCoverImageData != nil && initialCoverImageData != nil && currentCoverImageData != initialCoverImageData) {
            return true
        }
        
        // 检查时长
        let currentDuration = Double(selectedMinutes * 60 + selectedSeconds)
        if currentDuration != initialTotalDuration { return true }
        
        // 检查标签
        if tags != initialTags { return true }
        
        // 检查时间轴项目数量
        if timelineItems.count != initialTimelineItems.count { return true }
        
        // 如果所有检查都通过，说明没有更改
        return false
    }
    
    private func cancelAndDismiss() {
        if existingTemplate == nil, let templateId = templateId {
            try? TemplateStorage.shared.deleteTemplate(templateId: templateId)
        }
        dismiss()
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("标题")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField("输入模板标题", text: $title)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("时长")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // 使用 GeometryReader 来确保正确的布局和对齐
            GeometryReader { geometry in
                HStack(spacing: 16) {
                    // 时长选择器
                    HStack {
                        Picker("", selection: $selectedMinutes) {
                            ForEach(minutesRange, id: \.self) { minute in
                                Text("\(minute)").tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 50)
                        .clipped()
                        Text("分")
                        
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
                    .frame(maxWidth: geometry.size.width * 0.5, alignment: .leading)
                    
                    // 添加/编辑时间轴按钮
                    Button(action: { showingTimelineEditor = true }) {
                        Label(timelineItems.isEmpty ? "添加时间轴" : "编辑时间轴", 
                              systemImage: timelineItems.isEmpty ? "plus.circle.fill" : "pencil.circle.fill")
                            .font(.headline)
                            .frame(width: geometry.size.width * 0.4)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .frame(height: 120) // 设置固定高度以匹配 Picker 的高度
            .onChange(of: selectedMinutes) { _ in
                validateDuration()
            }
            .onChange(of: selectedSeconds) { _ in
                validateDuration()
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
    
    private var coverImageSection: some View {
        VStack(alignment: .leading) {
            Text("封面图片")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            GeometryReader { geometry in
                PhotosPicker(selection: $selectedImage,
                           matching: .images,
                           photoLibrary: .shared()) {
                    if let coverImage = coverImage {
                        coverImage
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.width * 3/4)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: geometry.size.width, height: geometry.size.width * 3/4)
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
            .aspectRatio(4/3, contentMode: .fit)
        }
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("标签")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // 已添加的标签
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        TagView(tag: tag) {
                            // 删除标签
                            if let index = tags.firstIndex(of: tag) {
                                tags.remove(at: index)
                            }
                        }
                    }
                }
            }
            
            // 添加新标签
            HStack {
                TextField("添加标签", text: $newTag)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                
                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
                .disabled(newTag.isEmpty)
            }
        }
    }
    
    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tag.isEmpty && !tags.contains(tag) {
            tags.append(tag)
            newTag = ""
        }
    }
}

// 时间轴项目数据模型
struct TimelineItemData: Identifiable {
    let id = UUID()
    var script: String
    var imageURL: URL?
    var timestamp: Double
}

// 标签视图组件
private struct TagView: View {
    let tag: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.subheadline)
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.1))
        .foregroundColor(.accentColor)
        .clipShape(Capsule())
    }
}
