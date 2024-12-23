import SwiftUI
import CoreData
import PhotosUI

struct CreateTemplateView: View {
    let language: String
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var coverImage: Image?
    @State private var coverImageData: Data?
    @State private var timelineItems: [TimelineItemData] = []
    @State private var showingImagePicker = false
    @State private var showingTimelineEditor = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("模板标题", text: $title)
                    
                    // 封面图片选择
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
                    }
                }
                
                Section("时间轴项目") {
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
            .navigationTitle("新建模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        createTemplate()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .onChange(of: selectedImage) { _ in
                Task {
                    if let data = try? await selectedImage?.loadTransferable(type: Data.self) {
                        if let uiImage = UIImage(data: data) {
                            coverImage = Image(uiImage: uiImage)
                            coverImageData = data
                        }
                    }
                }
            }
            .sheet(isPresented: $showingTimelineEditor) {
                TimelineEditorView(timelineItems: $timelineItems)
            }
        }
    }
    
    private func deleteTimelineItem(at offsets: IndexSet) {
        timelineItems.remove(atOffsets: offsets)
    }
    
    private func createTemplate() {
        // 先获取或创建对应的语言分区
        let fetchRequest: NSFetchRequest<LanguageSection> = LanguageSection.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", language)
        
        do {
            let section: LanguageSection
            if let existingSection = try viewContext.fetch(fetchRequest).first {
                section = existingSection
            } else {
                section = LanguageSection(context: viewContext)
                section.id = UUID()
                section.name = language
                section.createdAt = Date()
            }
            
            // 创建新模板
            let template = Template(context: viewContext)
            template.id = UUID()
            template.title = title
            template.createdAt = Date()
            template.languageSection = section
            template.coverImageData = coverImageData
            
            // 创建时间轴项目
            var totalDuration: Double = 0
            for itemData in timelineItems {
                let item = TimelineItem(context: viewContext)
                item.id = UUID()
                item.script = itemData.script
                item.imageData = itemData.imageData
                item.timestamp = itemData.timestamp
                item.template = template
                totalDuration = max(totalDuration, itemData.timestamp)
            }
            template.totalDuration = totalDuration
            
            try viewContext.save()
            dismiss()
        } catch {
            print("Error creating template: \(error)")
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

// 时间轴项目行视图
struct TimelineItemRow: View {
    let item: TimelineItemData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageData = item.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
    @Environment(\.dismiss) private var dismiss
    @Binding var timelineItems: [TimelineItemData]
    @State private var script = ""
    @State private var timestamp = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var previewImage: Image?
    
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        if let time = Double(timestamp), !script.isEmpty {
                            let item = TimelineItemData(
                                script: script,
                                imageData: imageData,
                                timestamp: time
                            )
                            timelineItems.append(item)
                            timelineItems.sort { $0.timestamp < $1.timestamp }
                            dismiss()
                        }
                    }
                    .disabled(script.isEmpty || timestamp.isEmpty)
                }
            }
            .onChange(of: selectedImage) { _ in
                Task {
                    if let data = try? await selectedImage?.loadTransferable(type: Data.self) {
                        if let uiImage = UIImage(data: data) {
                            imageData = data
                            previewImage = Image(uiImage: uiImage)
                        }
                    }
                }
            }
        }
    }
} 