import SwiftUI

struct LocalRecordingView: View {
    let templateId: String
    let recordId: String?
    @State private var template: Template?
    
    var body: some View {
        Group {
            if let template = template {
                BaseRecordingView(
                    timelineProvider: LocalTimelineProvider(template: template),
                    delegate: LocalRecordingDelegate(template: template),
                    recordId: recordId
                )
            } else {
                ProgressView()
            }
        }
        .onAppear {
            loadTemplate()
        }
    }
    
    private func loadTemplate() {
        do {
            template = try TemplateStorage.shared.loadTemplate(templateId: templateId)
        } catch {
            print("Error loading template: \(error)")
        }
    }
} 