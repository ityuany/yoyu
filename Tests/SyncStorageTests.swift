import Foundation
import SwiftData

@Model final class SyncProbe {
    var name: String = ""
    init(_ name: String) { self.name = name }
}

@main struct SyncStorageTests {
    @MainActor static func main() throws {
        let schema = Schema([SyncProbe.self])
        let localDefault = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        let cloudDefault = ModelConfiguration(schema: schema, cloudKitDatabase: .private("iCloud.com.ityuany.yoyu"))
        precondition(localDefault.url == cloudDefault.url, "Toggling must not change the existing store URL")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.store")
        func open() throws -> ModelContainer {
            try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
        }
        func write() throws {
            let container = try open()
            container.mainContext.insert(SyncProbe("retained"))
            container.mainContext.insert(SyncProbe("deleted"))
            try container.mainContext.save()
        }
        func modify() throws {
            let container = try open()
            let records = try container.mainContext.fetch(FetchDescriptor<SyncProbe>())
            precondition(records.count == 2)
            for record in records {
                if record.name == "deleted" { container.mainContext.delete(record) }
                else { record.name = "updated offline" }
            }
            try container.mainContext.save()
        }
        try write()
        try modify()
        let final = try open()
        let records = try final.mainContext.fetch(FetchDescriptor<SyncProbe>())
        precondition(records.count == 1 && records[0].name == "updated offline")
        print("Store location parity and offline create/update/delete/reopen tests passed")
    }
}
