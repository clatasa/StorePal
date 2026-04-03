import Foundation
import CloudKit
import Combine

// MARK: - Errors

enum CloudKitError: LocalizedError {
    case notAuthenticated
    case listNotFound
    case saveFailed(Error)
    case fetchFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:    return "Sign in to iCloud in Settings to use Shared Lists."
        case .listNotFound:        return "No shared list found with that code."
        case .saveFailed(let e):   return "Save failed: \(e.localizedDescription)"
        case .fetchFailed(let e):  return "Fetch failed: \(e.localizedDescription)"
        }
    }
}

// MARK: - Record type / field constants

private enum RecordType {
    static let sharedList = "SharedList"
    static let sharedItem = "SharedListItem"
}

private enum Field {
    // SharedList
    static let shareCode      = "shareCode"
    static let listName       = "listName"
    static let ownerID        = "ownerID"
    static let participantIDs = "participantIDs"

    // SharedListItem
    static let cloudListId    = "cloudListId"
    static let itemId         = "itemId"        // local UUID string
    static let itemName       = "itemName"
    static let isChecked      = "isChecked"
    static let isStaple       = "isStaple"
    static let quantity       = "quantity"
    static let weightValue    = "weightValue"
    static let weightUnit     = "weightUnit"
    static let note           = "note"
    static let purchasedDate  = "purchasedDate"
    static let sortOrder      = "sortOrder"
}

// MARK: - CloudKitService

@MainActor
final class CloudKitService: ObservableObject {

    static let shared = CloudKitService()

    // MARK: State

    @Published var isAvailable: Bool = false
    @Published var currentUserID: String?
    @Published var errorMessage: String?

    // MARK: Private

    private let container  = CKContainer.default()
    private var publicDB: CKDatabase { container.publicCloudDatabase }

    private init() {}

    // MARK: - Availability

    func checkAvailability() async {
        do {
            let status = try await container.accountStatus()
            isAvailable = (status == .available)
            if isAvailable {
                let id = try await container.userRecordID()
                currentUserID = id.recordName
            }
        } catch {
            isAvailable = false
            currentUserID = nil
        }
    }

    // MARK: - Share a list

    /// Publishes `list` to CloudKit and returns the 6-char share code.
    func shareList(name: String, listId: UUID, items: [ListItemPayload]) async throws -> String {
        guard let ownerID = currentUserID else { throw CloudKitError.notAuthenticated }

        let code = generateShareCode()
        let recordID = CKRecord.ID(recordName: "list-\(listId.uuidString)")
        let record = CKRecord(recordType: RecordType.sharedList, recordID: recordID)
        record[Field.shareCode]      = code
        record[Field.listName]       = name
        record[Field.ownerID]        = ownerID
        record[Field.participantIDs] = [ownerID] as CKRecordValue

        do {
            try await publicDB.save(record)
        } catch {
            throw CloudKitError.saveFailed(error)
        }

        // Push all current items
        for (index, item) in items.enumerated() {
            try await saveItem(item, cloudListId: listId.uuidString, sortOrder: index)
        }

        return code
    }

    // MARK: - Join a list

    /// Returns the `cloudListId` (record name) for the joined list.
    func joinList(shareCode: String) async throws -> (cloudListId: String, listName: String) {
        guard let userID = currentUserID else { throw CloudKitError.notAuthenticated }

        let predicate = NSPredicate(format: "%K == %@", Field.shareCode, shareCode.uppercased())
        let query = CKQuery(recordType: RecordType.sharedList, predicate: predicate)

        let result: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)
        do {
            result = try await publicDB.records(matching: query, resultsLimit: 1)
        } catch {
            throw CloudKitError.fetchFailed(error)
        }

        guard let (recordID, recordResult) = result.matchResults.first,
              let record = try? recordResult.get() else {
            throw CloudKitError.listNotFound
        }

        // Add this user to participantIDs
        var participants = record[Field.participantIDs] as? [String] ?? []
        if !participants.contains(userID) {
            participants.append(userID)
            record[Field.participantIDs] = participants as CKRecordValue
            do {
                try await publicDB.save(record)
            } catch {
                throw CloudKitError.saveFailed(error)
            }
        }

        let listName = record[Field.listName] as? String ?? "Shared List"
        return (cloudListId: recordID.recordName, listName: listName)
    }

    // MARK: - Fetch items

    func fetchItems(cloudListId: String) async throws -> [ListItemPayload] {
        let predicate = NSPredicate(format: "%K == %@", Field.cloudListId, cloudListId)
        let query = CKQuery(recordType: RecordType.sharedItem, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: Field.sortOrder, ascending: true)]

        let result: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)
        do {
            result = try await publicDB.records(matching: query)
        } catch {
            throw CloudKitError.fetchFailed(error)
        }

        return result.matchResults.compactMap { _, recordResult in
            guard let record = try? recordResult.get() else { return nil }
            return ListItemPayload(from: record)
        }
    }

    // MARK: - Save / upsert an item

    func saveItem(_ payload: ListItemPayload, cloudListId: String, sortOrder: Int) async throws {
        let recordID = CKRecord.ID(recordName: "item-\(cloudListId)-\(payload.itemId)")
        let record: CKRecord

        // Try to fetch existing record first
        if let existing = try? await publicDB.record(for: recordID) {
            record = existing
        } else {
            record = CKRecord(recordType: RecordType.sharedItem, recordID: recordID)
        }

        record[Field.cloudListId]   = cloudListId
        record[Field.itemId]        = payload.itemId
        record[Field.itemName]      = payload.name
        record[Field.isChecked]     = payload.isChecked ? 1 : 0
        record[Field.isStaple]      = payload.isStaple ? 1 : 0
        record[Field.quantity]      = payload.quantity as CKRecordValue?
        record[Field.weightValue]   = payload.weightValue as CKRecordValue?
        record[Field.weightUnit]    = payload.weightUnit as CKRecordValue?
        record[Field.note]          = payload.note as CKRecordValue?
        record[Field.purchasedDate] = payload.purchasedDate as CKRecordValue?
        record[Field.sortOrder]     = sortOrder

        do {
            try await publicDB.save(record)
        } catch {
            throw CloudKitError.saveFailed(error)
        }
    }

    // MARK: - Delete an item

    func deleteItem(cloudListId: String, itemId: String) async throws {
        let recordID = CKRecord.ID(recordName: "item-\(cloudListId)-\(itemId)")
        do {
            try await publicDB.deleteRecord(withID: recordID)
        } catch {
            throw CloudKitError.saveFailed(error)
        }
    }

    // MARK: - Leave / stop sharing

    /// Owner: deletes the list and all items.  Participant: removes self from participants.
    func leaveList(cloudListId: String, isOwner: Bool) async throws {
        guard let userID = currentUserID else { throw CloudKitError.notAuthenticated }

        let listRecordID = CKRecord.ID(recordName: cloudListId)

        if isOwner {
            // Delete all item records
            let predicate = NSPredicate(format: "%K == %@", Field.cloudListId, cloudListId)
            let query = CKQuery(recordType: RecordType.sharedItem, predicate: predicate)
            if let result = try? await publicDB.records(matching: query) {
                let ids = result.matchResults.map { $0.0 }
                if !ids.isEmpty {
                    try await publicDB.deleteRecords(withIDs: ids)
                }
            }
            // Delete list record
            try await publicDB.deleteRecord(withID: listRecordID)
        } else {
            // Remove self from participants
            if let record = try? await publicDB.record(for: listRecordID) {
                var participants = record[Field.participantIDs] as? [String] ?? []
                participants.removeAll { $0 == userID }
                record[Field.participantIDs] = participants as CKRecordValue
                try await publicDB.save(record)
            }
        }
    }

    // MARK: - Subscriptions (real-time push)

    /// Call once per shared list the user is in. Returns the subscription ID.
    @discardableResult
    func subscribeToListChanges(cloudListId: String) async throws -> String {
        let subID = "sub-\(cloudListId)"
        let predicate = NSPredicate(format: "%K == %@", Field.cloudListId, cloudListId)
        let sub = CKQuerySubscription(
            recordType: RecordType.sharedItem,
            predicate: predicate,
            subscriptionID: subID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true   // silent push
        sub.notificationInfo = info

        do {
            try await publicDB.save(sub)
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Subscription already exists — that's fine
        } catch {
            throw CloudKitError.saveFailed(error)
        }
        return subID
    }

    func unsubscribe(cloudListId: String) async {
        let subID = "sub-\(cloudListId)"
        try? await publicDB.deleteSubscription(withID: subID)
    }

    // MARK: - Share code helper

    private func generateShareCode() -> String {
        // 6 chars from unambiguous alphabet (no 0/O/I/1/l)
        let alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in alphabet.randomElement()! })
    }
}

// MARK: - CKDatabase convenience (async delete multiple)

private extension CKDatabase {
    func deleteRecords(withIDs ids: [CKRecord.ID]) async throws {
        let op = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: ids)
        op.savePolicy = .allKeys
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success:          cont.resume()
                case .failure(let e):   cont.resume(throwing: e)
                }
            }
            self.add(op)
        }
    }
}

// MARK: - ListItem ↔ ListItemPayload bridge

extension ListItem {
    func payload(sortOrder: Int = 0) -> ListItemPayload {
        ListItemPayload(
            itemId: id.uuidString,
            name: name,
            isChecked: isChecked,
            isStaple: isStaple,
            quantity: quantity,
            weightValue: weightValue,
            weightUnit: weightUnit.rawValue,
            note: note,
            purchasedDate: purchasedDate,
            sortOrder: sortOrder
        )
    }
}

extension ListItemPayload {
    var asListItem: ListItem {
        ListItem(
            id: UUID(uuidString: itemId) ?? UUID(),
            name: name,
            isChecked: isChecked,
            isStaple: isStaple,
            quantity: quantity,
            weightValue: weightValue,
            weightUnit: weightUnit.flatMap(WeightUnit.init(rawValue:)) ?? .lbs,
            note: note,
            purchasedDate: purchasedDate
        )
    }
}

// MARK: - ListItemPayload (CloudKit ↔ ListItem bridge)

struct ListItemPayload {
    var itemId: String
    var name: String
    var isChecked: Bool
    var isStaple: Bool
    var quantity: Int?
    var weightValue: Double?
    var weightUnit: String?
    var note: String?
    var purchasedDate: Date?
    var sortOrder: Int

    init(itemId: String, name: String, isChecked: Bool, isStaple: Bool,
         quantity: Int?, weightValue: Double?, weightUnit: String?,
         note: String?, purchasedDate: Date?, sortOrder: Int = 0) {
        self.itemId       = itemId
        self.name         = name
        self.isChecked    = isChecked
        self.isStaple     = isStaple
        self.quantity     = quantity
        self.weightValue  = weightValue
        self.weightUnit   = weightUnit
        self.note         = note
        self.purchasedDate = purchasedDate
        self.sortOrder    = sortOrder
    }

    /// Decode from a CKRecord
    init?(from record: CKRecord) {
        guard let itemId = record[Field.itemId] as? String,
              let name   = record[Field.itemName] as? String else { return nil }
        self.itemId        = itemId
        self.name          = name
        self.isChecked     = (record[Field.isChecked] as? Int ?? 0) == 1
        self.isStaple      = (record[Field.isStaple]  as? Int ?? 0) == 1
        self.quantity      = record[Field.quantity]     as? Int
        self.weightValue   = record[Field.weightValue]  as? Double
        self.weightUnit    = record[Field.weightUnit]   as? String
        self.note          = record[Field.note]         as? String
        self.purchasedDate = record[Field.purchasedDate] as? Date
        self.sortOrder     = record[Field.sortOrder]    as? Int ?? 0
    }
}
