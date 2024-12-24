import SwiftUI
import PhotosUI
import UIKit

struct TimelineEditorView: View {
    let templateId: String
    let totalDuration: Double
    @Environment(\.dismiss) private var dismiss
    @Binding var timelineItems: [TimelineItemData]
    
    // 编辑状态
    @State private var currentTime: Double = 0
    @State private var script = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var previewImage: Image?
    @State private var originalImage: UIImage?
    @State private var showingCropper = false
    @State private var tempUIImage: UIImage?
    @State private var isEditing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 时间轴
                TimelineSlider(
                    value: $currentTime,
                    in: 0...totalDuration,
                    step: 1,
                    markedPositions: timelineItems.map { $0.timestamp }
                )
                .padding(.horizontal)
                
                // 当前时间显示
                Text(String(format: "%.0f秒", currentTime))
                    .font(.headline)
                
                // 表单区域
                VStack(spacing: 12) {
                    // 图片选择器
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
                    .disabled(!isEditing && isEditingExistingItem)
                    
                    // 台词输入框
                    TextField("输入台词", text: $script)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!isEditing && isEditingExistingItem)
                    
                    // 编辑/添加/更新按钮
                    if isEditingExistingItem {
                        if isEditing {
                            Button(action: addOrUpdateTimelineItem) {
                                Text("更新")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(script.isEmpty || originalImage == nil)
                        } else {
                            Button(action: { isEditing = true }) {
                                Text("编辑")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Button(action: addOrUpdateTimelineItem) {
                            Text("添加")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(script.isEmpty || originalImage == nil)
                    }
                }
                .padding(.horizontal)
                
                // 已添加内容列表
                List {
                    ForEach(timelineItems.sorted(by: { $0.timestamp < $1.timestamp })) { item in
                        TimelineItemRow(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // 点击跳转到对应时间节点
                                currentTime = item.timestamp
                                loadTimelineItem(item)
                                isEditing = false
                            }
                            .listRowInsets(EdgeInsets())
                    }
                    .onDelete(perform: deleteTimelineItem)
                }
                .listStyle(.plain)
            }
            .navigationTitle("编辑时间轴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedImage) { newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        tempUIImage = uiImage
                        showingCropper = true
                        selectedImage = nil
                    }
                }
            }
            .onChange(of: currentTime) { newTime in
                // 时间轴滑动时，加载对应时间点的内容
                if let item = timelineItems.first(where: { $0.timestamp == newTime }) {
                    loadTimelineItem(item)
                    isEditing = false
                } else {
                    // 清空表单
                    clearForm()
                    isEditing = true
                }
            }
            .onAppear {
                // 检查 0.0 秒位置是否有内容
                if let initialItem = timelineItems.first(where: { $0.timestamp == 0.0 }) {
                    loadTimelineItem(initialItem)
                    isEditing = false
                }
            }
            .sheet(isPresented: $showingCropper) {
                if let image = tempUIImage {
                    ImageCropperView(image: image, aspectRatio: 16/9) { croppedImage in
                        originalImage = croppedImage
                        previewImage = Image(uiImage: croppedImage)
                    }
                }
            }
        }
    }
    
    private var isEditingExistingItem: Bool {
        timelineItems.contains { $0.timestamp == currentTime }
    }
    
    private func loadTimelineItem(_ item: TimelineItemData) {
        script = item.script
        if let imageURL = item.imageURL,
           let imageData = try? Data(contentsOf: imageURL),
           let uiImage = UIImage(data: imageData) {
            originalImage = uiImage
            previewImage = Image(uiImage: uiImage)
        }
    }
    
    private func clearForm() {
        script = ""
        originalImage = nil
        previewImage = nil
    }
    
    private func addOrUpdateTimelineItem() {
        guard let image = originalImage else { return }
        
        Task {
            do {
                _ = try TemplateStorage.shared.saveTimelineItem(
                    templateId: templateId,
                    timestamp: currentTime,
                    script: script,
                    image: image
                )
                
                // 加载模板以获取新的时间轴项目URL
                let template = try TemplateStorage.shared.loadTemplate(templateId: templateId)
                if let item = template.template.timelineItems.last,
                   let baseURL = TemplateStorage.shared.getTemplateDirectoryURL(templateId: templateId) {
                    let imageURL = baseURL.appendingPathComponent(item.image)
                    
                    // 更新或添加时间轴项目
                    if let index = timelineItems.firstIndex(where: { $0.timestamp == currentTime }) {
                        timelineItems[index] = TimelineItemData(
                            script: script,
                            imageURL: imageURL,
                            timestamp: currentTime
                        )
                    } else {
                        let timelineItem = TimelineItemData(
                            script: script,
                            imageURL: imageURL,
                            timestamp: currentTime
                        )
                        timelineItems.append(timelineItem)
                    }
                    
                    // 清空表单并退出编辑状态
                    clearForm()
                    isEditing = false
                }
            } catch {
                print("Error saving timeline item: \(error)")
            }
        }
    }
    
    private func deleteTimelineItem(at offsets: IndexSet) {
        let sortedItems = timelineItems.sorted(by: { $0.timestamp < $1.timestamp })
        for index in offsets {
            let item = sortedItems[index]
            if let itemIndex = timelineItems.firstIndex(where: { $0.id == item.id }) {
                timelineItems.remove(at: itemIndex)
            }
        }
    }
    
    // 时间轴项目行视图
    private struct TimelineItemRow: View {
        let item: TimelineItemData
        
        var body: some View {
            HStack(spacing: 12) {
                // 左侧：图片
                if let imageURL = item.imageURL {
                    AsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 68) // 16:9 比例
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 120, height: 68)
                    }
                }
                
                // 右侧：台词和时间节点
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.script)
                        .font(.body)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(String(format: "%.1f秒", item.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer(minLength: 0)
            }
            .frame(height: 80) // 固定行高
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBackground))
        }
    }
}

// 自定义时间轴滑块
struct TimelineSlider: View {
    @Binding var value: Double
    let bounds: ClosedRange<Double>
    let step: Double
    let markedPositions: [Double]
    
    init(value: Binding<Double>, in bounds: ClosedRange<Double>, step: Double, markedPositions: [Double]) {
        self._value = value
        self.bounds = bounds
        self.step = step
        self.markedPositions = markedPositions
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 时间轴线
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 2)
                
                // 已添加内容的标记点
                ForEach(markedPositions, id: \.self) { position in
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                        .offset(x: -4)
                        .offset(x: position / bounds.upperBound * geometry.size.width)
                }
                
                // 滑块
                Circle()
                    .fill(.blue)
                    .frame(width: 20, height: 20)
                    .offset(x: -10)
                    .offset(x: value / bounds.upperBound * geometry.size.width)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                let newValue = bounds.upperBound * gesture.location.x / geometry.size.width
                                value = round(min(max(bounds.lowerBound, newValue), bounds.upperBound) / step) * step
                            }
                    )
            }
        }
        .frame(height: 44)
    }
} 