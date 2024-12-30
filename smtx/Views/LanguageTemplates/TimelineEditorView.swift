import SwiftUI
import PhotosUI
import UIKit
import CoreData

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
    @State private var originalImageData: Data?
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
                    // 图片和台词区域
                    ZStack {
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
                                } else if let previousImage = getImageForCurrentTime() {
                                    Image(uiImage: previousImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .opacity(isEditing ? 0.5 : 1)
                                        .overlay(
                                            Group {
                                                if isEditing {
                                                    Text("点击更换图片\n不更换则沿用上一张图片")
                                                        .font(.caption)
                                                        .multilineTextAlignment(.center)
                                                        .foregroundColor(.white)
                                                        .padding(8)
                                                        .background(.black.opacity(0.6))
                                                        .cornerRadius(8)
                                                }
                                            }
                                        )
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
                            
                            // 更新/添加按钮 - 始终显示
                            Button(action: addOrUpdateTimelineItem) {
                                Text(isEditingExistingItem ? "更新" : "添加")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled((!isEditing && isEditingExistingItem) || (script.isEmpty && originalImage == nil))
                        }
                        
                        // 编辑遮罩层
                        if isEditingExistingItem && !isEditing {
                            ZStack {
                                Rectangle()
                                    .fill(.thinMaterial)
                                    .opacity(0.7)
                                
                                Color.white.opacity(0.1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                Text("点击编辑内容")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(.black.opacity(0.3))
                                    .cornerRadius(8)
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isEditing = true
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // 已添加内容列表
                List {
                    ForEach(timelineItems.sorted(by: { $0.timestamp < $1.timestamp })) { item in
                        TimelineItemRow(
                            item: item,
                            isSelected: item.timestamp == currentTime
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            currentTime = item.timestamp
                            loadTimelineItem(item)
                            isEditing = false
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
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
                    // 加载现有项目的内容
                    loadTimelineItem(item)
                    isEditing = false
                } else {
                    // 清空表单内容
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
                        originalImageData = croppedImage.jpegData(compressionQuality: 0.8)
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
        // 清空之前的状态
        clearForm()
        
        // 加载新的内容
        script = item.script
        if let imageData = item.imageData {
            // 保存原始图片数据
            originalImageData = imageData
            if let uiImage = UIImage(data: imageData) {
                originalImage = uiImage
                previewImage = Image(uiImage: uiImage)
            }
        }
    }
    
    private func clearForm() {
        script = ""
        originalImage = nil
        originalImageData = nil
        previewImage = nil
    }
    
    private func addOrUpdateTimelineItem() {
        do {
            _ = try TemplateStorage.shared.loadTemplate(templateId: templateId)
            
            // 如果是更新现有项目
            if let index = timelineItems.firstIndex(where: { $0.timestamp == currentTime }) {
                var updatedItem = timelineItems[index]
                
                // 检查脚本是否变化
                if updatedItem.script != script {
                    updatedItem.script = script
                    updatedItem.updatedAt = Date()
                }
                
                // 检查图片是否变化
                if let newImageData = originalImageData {
                    // 直接使用原始图片数据进行比较
                    if updatedItem.imageData?.sha256() != newImageData.sha256() {
                        updatedItem.imageData = newImageData
                        updatedItem.imageUpdatedAt = Date()
                    }
                }
                
                timelineItems[index] = updatedItem
            } else {
                // 添加新项目
                let newItem = TimelineItemData(
                    script: script,
                    imageData: originalImageData,
                    timestamp: currentTime,
                    createdAt: Date(),
                    updatedAt: Date(),
                    imageUpdatedAt: originalImageData != nil ? Date() : nil
                )
                timelineItems.append(newItem)
            }
            
            // 检查是否在最后1秒内
            let isLastSecond = totalDuration - currentTime <= 1
            
            if isLastSecond {
                // 如果在最后1秒，保持表单内容，切换到编辑模式
                isEditing = false
            } else {
                // 如果不在最后1秒，清空表单
                clearForm()
                isEditing = true
                
                // 计算下一个时间点（当前时间+3秒，但不超过总时长）
                let nextTime = min(currentTime + 3, totalDuration)
                // 如果下一个时间点和当前时间不同，才更新
                if nextTime != currentTime {
                    currentTime = nextTime
                }
            }
        } catch {
            print("Error saving timeline item: \(error)")
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
        var isSelected: Bool
        
        var body: some View {
            HStack(spacing: 12) {
                // 左侧：图片
                if let imageData = item.imageData,
                   let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 68) // 16:9 比例
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 120, height: 68)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        }
                }
                
                // 右侧：台词和时间节点
                VStack(alignment: .leading, spacing: 4) {
                    if !item.script.isEmpty {
                        Text(item.script)
                            .font(.body)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Text(String(format: "%.1f秒", item.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer(minLength: 0)
            }
            .frame(height: 80) // 固定行高
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(UIColor.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
    }
    
    private func getImageForCurrentTime() -> UIImage? {
        if let image = originalImage {
            return image
        }
        
        let previousItems = timelineItems
            .filter { $0.timestamp < currentTime }
            .sorted { $0.timestamp > $1.timestamp }
        
        if let previousItemWithImage = previousItems.first(where: { $0.imageData != nil }),
           let imageData = previousItemWithImage.imageData,
           let image = UIImage(data: imageData) {
            return image
        }
        
        return nil
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
                
                // 已添加内容的标记
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
