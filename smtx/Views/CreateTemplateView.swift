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
                    ImageCropperView(image: image, aspectRatio: 1/1) { croppedImage in
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
            
            GeometryReader { geometry in
                PhotosPicker(selection: $selectedImage,
                           matching: .images,
                           photoLibrary: .shared()) {
                    if let coverImage = coverImage {
                        coverImage
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.width)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: geometry.size.width, height: geometry.size.width)
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
            .aspectRatio(1, contentMode: .fit)
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
