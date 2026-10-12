//
//  ProtectedDataStore.swift
//  NextTime
//
//  使用 Core Data SQLite 和 iOS 完整文件保护保存敏感本地数据。
//

import CoreData
import Foundation

final class ProtectedDataStore {
    private enum Schema {
        static let entity = "SecureRecord"
        static let key = "key"
        static let payload = "payload"
        static let updatedAt = "updatedAt"
    }

    private let container: NSPersistentContainer

    static func makeDefault() -> ProtectedDataStore {
        do {
            return try ProtectedDataStore()
        } catch {
            // 磁盘存储不可用时退回仅内存模式，避免把敏感数据降级写入 UserDefaults。
            assertionFailure("Protected local store could not be opened: \(error.localizedDescription)")
            return try! ProtectedDataStore(inMemory: true)
        }
    }

    init(inMemory: Bool = false, storeURL: URL? = nil) throws {
        container = NSPersistentContainer(
            name: "NextTimeProtected",
            managedObjectModel: Self.makeModel()
        )

        let description = NSPersistentStoreDescription()
        if inMemory {
            description.type = NSInMemoryStoreType
        } else {
            let resolvedURL = try storeURL ?? Self.defaultStoreURL()
            description.url = resolvedURL
            description.type = NSSQLiteStoreType
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            description.setOption(
                FileProtectionType.complete as NSObject,
                forKey: NSPersistentStoreFileProtectionKey
            )
        }
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil

        if !inMemory, let url = description.url {
            Self.excludeStoreFromBackup(at: url)
        }
    }

    func save<Value: Encodable>(_ value: Value, forKey key: String) throws {
        let payload = try JSONEncoder().encode(value)
        let context = container.viewContext
        var operationError: Error?

        context.performAndWait {
            do {
                let object = try self.fetchRecord(forKey: key, in: context)
                    ?? NSEntityDescription.insertNewObject(forEntityName: Schema.entity, into: context)
                object.setValue(key, forKey: Schema.key)
                object.setValue(payload, forKey: Schema.payload)
                object.setValue(Date(), forKey: Schema.updatedAt)
                try context.save()
            } catch {
                operationError = error
                context.rollback()
            }
        }

        if let operationError {
            throw operationError
        }
    }

    func load<Value: Decodable>(_ type: Value.Type, forKey key: String) -> Value? {
        let context = container.viewContext
        var payload: Data?

        context.performAndWait {
            payload = try? self.fetchRecord(forKey: key, in: context)?
                .value(forKey: Schema.payload) as? Data
        }

        guard let payload else { return nil }
        return try? JSONDecoder().decode(type, from: payload)
    }

    func removeValue(forKey key: String) throws {
        let context = container.viewContext
        var operationError: Error?

        context.performAndWait {
            do {
                if let object = try self.fetchRecord(forKey: key, in: context) {
                    context.delete(object)
                    try context.save()
                }
            } catch {
                operationError = error
                context.rollback()
            }
        }

        if let operationError {
            throw operationError
        }
    }

    func removeAll() throws {
        let context = container.viewContext
        var operationError: Error?

        context.performAndWait {
            do {
                let request = NSFetchRequest<NSManagedObject>(entityName: Schema.entity)
                for object in try context.fetch(request) {
                    context.delete(object)
                }
                try context.save()
            } catch {
                operationError = error
                context.rollback()
            }
        }

        if let operationError {
            throw operationError
        }
    }

    private func fetchRecord(
        forKey key: String,
        in context: NSManagedObjectContext
    ) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: Schema.entity)
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "%K == %@", Schema.key, key)
        return try context.fetch(request).first
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = Schema.entity
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let key = NSAttributeDescription()
        key.name = Schema.key
        key.attributeType = .stringAttributeType
        key.isOptional = false

        let payload = NSAttributeDescription()
        payload.name = Schema.payload
        payload.attributeType = .binaryDataAttributeType
        payload.isOptional = false
        payload.allowsExternalBinaryDataStorage = false

        let updatedAt = NSAttributeDescription()
        updatedAt.name = Schema.updatedAt
        updatedAt.attributeType = .dateAttributeType
        updatedAt.isOptional = false

        entity.properties = [key, payload, updatedAt]
        entity.uniquenessConstraints = [[Schema.key]]
        model.entities = [entity]
        return model
    }

    private static func defaultStoreURL() throws -> URL {
        let fileManager = FileManager.default
        let baseURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = baseURL.appendingPathComponent("NextTime", isDirectory: true)
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        return directory.appendingPathComponent("Sensitive.sqlite")
    }

    private static func excludeStoreFromBackup(at storeURL: URL) {
        let relatedURLs = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-wal"),
            URL(fileURLWithPath: storeURL.path + "-shm")
        ]

        for var url in relatedURLs where FileManager.default.fileExists(atPath: url.path) {
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? url.setResourceValues(values)
        }
    }
}
