import SwiftUI

struct TemplateDetailView: View {
    let template: Template
    @EnvironmentObject private var router: NavigationRouter
    
    var body: some View {
        List {
            if let timelineItems = template.timelineItems?.allObjects as? [TimelineItem] {
                ForEach(timelineItems.sorted { ($0.timestamp ) < ($1.timestamp ) }) { item in
                    Text(item.script ?? "")
                }
            }
        }
        .navigationTitle(template.title ?? "未命名模板")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { router.navigate(to: .recording(template)) }) {
                    Image(systemName: "mic")
                }
            }
        }
    }
} 