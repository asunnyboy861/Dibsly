import CloudKit
import Foundation
import Observation
import UIKit

struct RemoteListing: Identifiable {
    let id: String
    let title: String
    let details: String
    let categoryRaw: String
    let estValueCents: Int
    let giverID: String
    let giverName: String
    let giverTrust: Int
    let geohash5: String
    let city: String
    let latitude: Double
    let longitude: Double
    let statusRaw: String
    let createdAt: Date
    let imageName: String?
}

struct RemoteMessage: Identifiable {
    let id: String
    let itemID: String
    let senderID: String
    let senderName: String
    let text: String
    let createdAt: Date
}

@Observable
final class CloudKitService {
    static let containerIdentifier = "iCloud.com.zzoutuo.Dibsly"

    @ObservationIgnored private let container = CKContainer(identifier: CloudKitService.containerIdentifier)
    var isAvailable: Bool = false
    var lastSyncDescription: String = "Local only"

    private var database: CKDatabase { container.publicCloudDatabase }

    func refreshAvailability() async {
        do {
            let status = try await container.accountStatus()
            isAvailable = (status == .available)
            lastSyncDescription = isAvailable ? "iCloud community on" : "Local only"
        } catch {
            isAvailable = false
            lastSyncDescription = "Local only"
        }
    }

    func publish(item: Item, imageName: String?) async {
        guard isAvailable else { return }
        let recordID = CKRecord.ID(recordName: item.id)
        let record = CKRecord(recordType: "DibsItem", recordID: recordID)
        record["title"] = item.title as CKRecordValue
        record["details"] = item.details as CKRecordValue
        record["category"] = item.categoryRaw as CKRecordValue
        record["estValueCents"] = Int64(item.estValueCents) as CKRecordValue
        record["status"] = item.statusRaw as CKRecordValue
        record["geohash5"] = item.geohash5 as CKRecordValue
        record["city"] = item.city as CKRecordValue
        let fuzzy = item.fuzzyCoordinate
        record["latitude"] = fuzzy.latitude as CKRecordValue
        record["longitude"] = fuzzy.longitude as CKRecordValue
        record["giverID"] = item.giverID as CKRecordValue
        record["giverName"] = item.giverName as CKRecordValue
        record["giverTrust"] = Int64(item.giverTrustAtPost) as CKRecordValue
        record["createdAt"] = item.createdAt as CKRecordValue

        if let imageName, let image = ImageStore.shared.load(imageName),
           let data = ImageStore.shared.downscaled(image, maxDimension: 900).jpegData(compressionQuality: 0.65) {
            let temp = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
            if (try? data.write(to: temp)) != nil {
                record["photo"] = CKAsset(fileURL: temp)
            }
        }

        do {
            _ = try await database.save(record)
        } catch {
            lastSyncDescription = "Upload will retry"
        }
    }

    func fetchListings() async -> [RemoteListing] {
        guard isAvailable else { return [] }
        let query = CKQuery(recordType: "DibsItem", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        do {
            let response = try await database.records(matching: query, resultsLimit: 80)
            var listings: [RemoteListing] = []
            for (_, result) in response.matchResults {
                guard case .success(let record) = result else { continue }
                guard let title = record["title"] as? String,
                      let status = record["status"] as? String,
                      let createdAt = record["createdAt"] as? Date else { continue }
                if status != ItemStatus.live.rawValue { continue }

                var localImageName: String?
                if let asset = record["photo"] as? CKAsset, let fileURL = asset.fileURL,
                   let data = try? Data(contentsOf: fileURL) {
                    let name = "ck_" + record.recordID.recordName + ".jpg"
                    if ImageStore.shared.save(data: data, name: name) {
                        localImageName = name
                    }
                }

                listings.append(RemoteListing(
                    id: record.recordID.recordName,
                    title: title,
                    details: record["details"] as? String ?? "",
                    categoryRaw: record["category"] as? String ?? ItemCategory.other.rawValue,
                    estValueCents: Int(record["estValueCents"] as? Int64 ?? 0),
                    giverID: record["giverID"] as? String ?? "",
                    giverName: record["giverName"] as? String ?? "Neighbor",
                    giverTrust: Int(record["giverTrust"] as? Int64 ?? 5),
                    geohash5: record["geohash5"] as? String ?? "",
                    city: record["city"] as? String ?? "",
                    latitude: record["latitude"] as? Double ?? 0,
                    longitude: record["longitude"] as? Double ?? 0,
                    statusRaw: status,
                    createdAt: createdAt,
                    imageName: localImageName
                ))
            }
            return listings
        } catch {
            lastSyncDescription = "Feed will retry"
            return []
        }
    }

    func tryClaim(itemID: String, takerID: String, takerName: String) async -> ClaimResult? {
        guard isAvailable else { return nil }
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: itemID))
            let status = record["status"] as? String ?? ItemStatus.live.rawValue
            guard status == ItemStatus.live.rawValue else { return .lost }
            record["status"] = ItemStatus.dibbed.rawValue as CKRecordValue
            record["dibsByID"] = takerID as CKRecordValue
            record["dibsByName"] = takerName as CKRecordValue
            record["dibsExpiresAt"] = Date().addingTimeInterval(600) as CKRecordValue
            let results = try await database.modifyRecords(
                saving: [record],
                deleting: [],
                savePolicy: .ifServerRecordUnchanged,
                atomically: true
            )
            for (_, result) in results.saveResults {
                switch result {
                case .success: return .win
                case .failure: return .lost
                }
            }
            return .lost
        } catch {
            return nil
        }
    }

    func markRemoteGiven(itemID: String) async {
        guard isAvailable else { return }
        await updateRemoteStatus(itemID: itemID, status: .given)
    }

    func markRemoteDone(itemID: String) async {
        guard isAvailable else { return }
        await updateRemoteStatus(itemID: itemID, status: .done)
    }

    private func updateRemoteStatus(itemID: String, status: ItemStatus) async {
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: itemID))
            record["status"] = status.rawValue as CKRecordValue
            let results = try await database.modifyRecords(
                saving: [record],
                deleting: [],
                savePolicy: .ifServerRecordUnchanged,
                atomically: true
            )
            _ = results.saveResults
        } catch {
            return
        }
    }

    func sendMessage(itemID: String, senderID: String, senderName: String, text: String) async {
        guard isAvailable else { return }
        let record = CKRecord(recordType: "DibsMessage")
        record["itemID"] = itemID as CKRecordValue
        record["senderID"] = senderID as CKRecordValue
        record["senderName"] = senderName as CKRecordValue
        record["text"] = text as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        do {
            _ = try await database.save(record)
        } catch {
            return
        }
    }

    func fetchMessages(itemID: String) async -> [RemoteMessage] {
        guard isAvailable else { return [] }
        let query = CKQuery(recordType: "DibsMessage", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        do {
            let response = try await database.records(matching: query, resultsLimit: 120)
            var messages: [RemoteMessage] = []
            for (_, result) in response.matchResults {
                guard case .success(let record) = result else { continue }
                guard let threadID = record["itemID"] as? String, threadID == itemID else { continue }
                guard let text = record["text"] as? String,
                      let createdAt = record["createdAt"] as? Date else { continue }
                messages.append(RemoteMessage(
                    id: record.recordID.recordName,
                    itemID: threadID,
                    senderID: record["senderID"] as? String ?? "",
                    senderName: record["senderName"] as? String ?? "Neighbor",
                    text: text,
                    createdAt: createdAt
                ))
            }
            return messages
        } catch {
            return []
        }
    }
}
