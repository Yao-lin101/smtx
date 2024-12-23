import Foundation
import CoreData
import SwiftUI

class TemplateViewModel: ObservableObject {
    @Published var templates: [Template] = []
    private let viewContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        fetchTemplates()
    }
    
    func fetchTemplates() {
        let request = NSFetchRequest<Template>(entityName: "Template")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Template.createdAt, ascending: false)]
        
        do {
            templates = try viewContext.fetch(request)
        } catch {
            print("Error fetching templates: \(error)")
        }
    }
} 