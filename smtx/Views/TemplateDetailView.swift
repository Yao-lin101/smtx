import SwiftUI

struct TemplateDetailView: View {
    let template: TemplateFile
    @EnvironmentObject private var router: NavigationRouter
    @State private var coverImage: Image?
    
    var body: some View {
        List {
            Section {
                if let coverImage = coverImage {
                    coverImage
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            Section("时间轴") {
                ForEach(template.template.timelineItems, id: \.id) { item in
                    TimelineItemView(templateId: template.metadata.id, item: item)
                }
            }
            
            if !template.records.isEmpty {
                Section("录音记录") {
                    ForEach(template.records) { record in
                        NavigationLink(value: Route.recordDetail(templateId: template.metadata.id, record: record)) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(record.createdAt, style: .date)
                                        .font(.subheadline)
                                    Text(String(format: "时长：%.1f秒", record.duration))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "waveform")
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle(template.template.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { router.navigate(to: .recording(template)) }) {
                    Image(systemName: "mic")
                }
            }
        }
        .onAppear {
            loadCoverImage()
        }
    }
    
    private func loadCoverImage() {
        guard let baseURL = TemplateStorage.shared.getTemplateDirectoryURL(templateId: template.metadata.id) else { return }
        let coverURL = baseURL.appendingPathComponent(template.template.coverImage)
        
        if let data = try? Data(contentsOf: coverURL),
           let uiImage = UIImage(data: data) {
            coverImage = Image(uiImage: uiImage)
        }
    }
}

struct TimelineItemView: View {
    let templateId: String
    let item: TemplateData.TimelineItem
    @State private var image: Image?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = image {
                image
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
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let baseURL = TemplateStorage.shared.getTemplateDirectoryURL(templateId: templateId) else { return }
        let imageURL = baseURL.appendingPathComponent(item.image)
        
        if let data = try? Data(contentsOf: imageURL),
           let uiImage = UIImage(data: data) {
            image = Image(uiImage: uiImage)
        }
    }
} 