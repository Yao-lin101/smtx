import SwiftUI
import PhotosUI
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreData

struct CreateTemplateView: View {
    let language: String
    let existingTemplateId: String?
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var coverImage: Image?
    @State private var originalCoverImage: UIImage?
    @State private var timelineItems: [TimelineItemData] = []
    @State private var showingTimelineEditor = false
    @State private var showingCropper = false
    @State private var tempUIImage: UIImage?
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
    
    private let minutesRange = 0...10
    private let secondsRange = 0...59
    
    init(language: String, existingTemplateId: String? = nil) {
        self.language = language
        self.existingTemplateId = existingTemplateId
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
            .navigationTitle(existingTemplateId != nil ? "编辑模板" : "新建模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        if hasUnsavedChanges() {
                            showingCancelAlert = true
                        } else {
                            dismiss()
                        }
                    }) {
                        Text("取消")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        saveTemplate()
                    }) {
                        Text(existingTemplateId != nil ? "保存" : "创建")
                    }
                    .disabled(title.isEmpty)
                }
            }
            .alert("是否保存更改？", isPresented: $showingCancelAlert) {
                Button("取消", role: .cancel) { }
                Button("不保存", role: .destructive) {
                    dismiss()
                }
                Button("保存") {
                    saveTemplate()
                }
            } message: {
                Text("您对模板进行了修改，是否要保存这些更改？")
            }
            .sheet(isPresented: $showingTimelineEditor) {
                if let id = templateId {
                    TimelineEditorView(
                        templateId: id,
                        totalDuration: Double(selectedMinutes * 60 + selectedSeconds),
                        timelineItems: $timelineItems
                    )
                }
            }
            .sheet(isPresented: $showingCropper) {
                if let image = tempUIImage {
                    ImageCropperView(image: image, aspectRatio: 4/3) { croppedImage in
                        originalCoverImage = croppedImage
                        coverImage = Image(uiImage: croppedImage)
                        if existingTemplateId == nil {
                            // 只更新封面图片，不退出视图
                            do {
                                if let templateId = templateId {
                                    let totalDuration = Double(selectedMinutes * 60 + selectedSeconds)
                                    try TemplateStorage.shared.updateTemplate(
                                        templateId: templateId,
                                        title: title,
                                        coverImage: croppedImage,
                                        tags: tags,
                                        timelineItems: timelineItems,
                                        totalDuration: totalDuration
                                    )
                                }
                            } catch {
                                print("Error updating cover image: \(error)")
                            }
                        }
                    }
                }
            }
            .onAppear {
                if existingTemplateId != nil {
                    loadExistingTemplate()
                }
                saveInitialState()
            }
        }
    }
    
    private func loadExistingTemplate() {
        guard let templateId = existingTemplateId else { return }
        
        do {
            let template = try TemplateStorage.shared.loadTemplate(templateId: templateId)
            
            // 加载模板数据
            self.templateId = template.id
            title = template.title ?? ""
            
            // 设置时长
            let duration = template.totalDuration
            selectedMinutes = Int(duration) / 60
            selectedSeconds = Int(duration) % 60
            
            // 加载封面图片
            if let imageData = template.coverImage,
               let uiImage = UIImage(data: imageData) {
                originalCoverImage = uiImage
                coverImage = Image(uiImage: uiImage)
            }
            
            // 加载标签
            tags = TemplateStorage.shared.getTemplateTags(template)
            
            // 加载时间轴项目
            if let items = template.timelineItems?.allObjects as? [TimelineItem] {
                timelineItems = items.map { item in
                    TimelineItemData(
                        script: item.script ?? "",
                        imageData: item.image,
                        timestamp: item.timestamp
                    )
                }
            }
            
            // 保存初始状态
            saveInitialState()
        } catch {
            print("Error loading template: \(error)")
        }
    }
    
    private func saveTemplate() {
        do {
            if existingTemplateId != nil {
                try updateExistingTemplate()
            } else {
                try createAndUpdateTemplate()
            }
            
            // 发送模板更新通知并关闭视图
            if let template = try? TemplateStorage.shared.loadTemplate(templateId: templateId ?? "") {
                NotificationCenter.default.post(name: .templateDidUpdate, object: template)
            }
            dismiss()
        } catch {
            print("Error saving template: \(error)")
        }
    }
    
    private func updateExistingTemplate() throws {
        guard let templateId = templateId else { return }
        
        let totalDuration = Double(selectedMinutes * 60 + selectedSeconds)
        print("📝 Updating template duration: \(totalDuration) seconds")
        
        try TemplateStorage.shared.updateTemplate(
            templateId: templateId,
            title: title,
            coverImage: originalCoverImage,
            tags: tags,
            timelineItems: timelineItems,
            totalDuration: totalDuration
        )
        
        print("✅ Template updated with new duration")
    }
    
    private func createAndUpdateTemplate() throws {
        // 1. 创建默认封面图片
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300))
        let defaultCoverImage = renderer.image { context in
            UIColor.systemGray5.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        }
        
        // 2. 创建新模板
        templateId = try TemplateStorage.shared.createTemplate(
            title: title,
            language: language,
            coverImage: defaultCoverImage
        )
        
        // 3. 更新模板内容
        try updateExistingTemplate()
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
                    
                    // 修改添加/编辑时间轴按钮
                    Button(action: handleTimelineEdit) {
                        Label(timelineItems.isEmpty ? "添加时间轴" : "编辑时间轴", 
                              systemImage: timelineItems.isEmpty ? "plus.circle.fill" : "pencil.circle.fill")
                            .font(.headline)
                            .frame(width: geometry.size.width * 0.4)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(title.isEmpty) // 禁用按钮如果标题为空
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
        print("⏱️ Validating duration: \(totalSeconds) seconds")
        
        // 确保不小于最小时长（5秒）
        if totalSeconds < 5 {
            print("⚠️ Duration too short, setting to minimum 5 seconds")
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
                print("⚠️ Duration shorter than last timeline item (\(requiredSeconds) seconds), adjusting...")
                selectedMinutes = requiredMinutes
                selectedSeconds = requiredRemainingSeconds
            }
        }
        
        print("✅ Duration validated: \(selectedMinutes):\(String(format: "%02d", selectedSeconds))")
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
                                tempUIImage = uiImage
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
            // 标签标题和提示信息
            VStack(alignment: .leading, spacing: 4) {
                Text("标签")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("添加作品名、角色名等标签便于检索，批量添加可用逗号、顿号、空格、换行符分隔")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 已添加的标签
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        TagView(tag: tag) {
                            if let index = tags.firstIndex(of: tag) {
                                tags.remove(at: index)
                            }
                        }
                    }
                }
            }
            
            // 添加新标签
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    TextField("示例：进击的巨人、利威尔...", text: $newTag)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit(addTag)
                    
                    Button(action: addTag) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                    .disabled(newTag.isEmpty || tags.count >= 10)
                }
                
                // 显示验证提示
                tagInputPrompt
            }
        }
    }
    
    private func addTag() {
        // 1. 分割输入的文本（支持多种分隔符）
        let separators = CharacterSet(charactersIn: "、，, \n")
        let newTags = newTag
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // 2. 验证并添加每个标签
        for tag in newTags {
            // 验证标签长度（1-15个字符）
            guard (1...15).contains(tag.count) else { continue }
            
            // 验证是否已存在
            guard !tags.contains(tag) else { continue }
            
            // 限制标签总数（最多10个）
            guard tags.count < 10 else { break }
            
            // 添加有效标签
            tags.append(tag)
        }
        
        // 清空输入框
        newTag = ""
    }
    
    // 修改验证提示
    private var tagInputPrompt: some View {
        Group {
            if tags.count >= 10 {
                Text("最多添加10个标签")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // 添加新方法：处理时间轴编辑
    private func handleTimelineEdit() {
        if templateId == nil {
            // 如果模板还未创建，先创建模板
            do {
                try createAndUpdateTemplate()
                showingTimelineEditor = true
            } catch {
                print("❌ Failed to create template before timeline editing: \(error)")
            }
        } else {
            // 如果模板已存在，直接显示编辑器
            showingTimelineEditor = true
        }
    }
}

// 时间轴项目数据模型
struct TimelineItemData: Identifiable {
    let id = UUID()
    var script: String
    var imageData: Data?
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
