import CloudKit
import Foundation

/// The real backend: crews synced through the user's own iCloud account.
///
/// ## Why a backend exists at all
///
/// HealthKit is device-local by design — there is no API that lets this app read
/// what's in someone else's Health store. So a crew leaderboard is N phones each
/// reading *their own* Health data and publishing one number per day, which
/// everyone else then reads. This class is that transport, and nothing more.
///
/// ## Shape
///
/// One crew is one **custom record zone**. Whoever creates it owns the zone in
/// their private database and puts a zone-wide `CKShare` on it; everyone else
/// sees that same zone through their shared database. Real data — names, step
/// totals — only ever lives inside that shared zone, so it's visible to crew
/// members and nobody else.
///
/// The one thing in the public database is a `CrewInvite` record whose *record
/// name is the invite code* and whose only field is the share URL. That keeps
/// the six-character-code experience (far better than pasting links) without
/// putting a single byte of personal data anywhere public. Looking a code up is
/// a fetch-by-ID, not a query, so there's no index to configure either.
///
/// Reads use `recordZoneChanges` rather than `CKQuery` for the same reason: it
/// needs no queryable indexes, so the schema CloudKit generates on first write
/// is all the setup there is.
final class CloudKitSocialService: SocialService {

    /// Must match the container in the target's iCloud capability.
    static let defaultContainerIdentifier = "iCloud.com.mahadmyonis.StepCounting"

    /// How many days of history a device publishes. Longer than any challenge
    /// window, short enough that the zone stays small.
    private static let publishWindowDays = 45

    private let container: CKContainer
    private let defaults: UserDefaults

    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var sharedDB: CKDatabase { container.sharedCloudDatabase }
    private var publicDB: CKDatabase { container.publicCloudDatabase }

    init(
        containerIdentifier: String = CloudKitSocialService.defaultContainerIdentifier,
        defaults: UserDefaults = .standard
    ) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.defaults = defaults
    }

    // MARK: Schema

    private enum RecordType {
        static let crew = "Crew"
        static let member = "Member"
        static let entry = "DailyEntry"
        static let invite = "CrewInvite"
    }

    private enum Key {
        static let name = "name"
        static let emoji = "emoji"
        static let accentIndex = "accentIndex"
        static let createdAt = "createdAt"
        static let inviteCode = "inviteCode"
        static let profileID = "profileID"
        static let displayName = "displayName"
        static let avatarEmoji = "avatarEmoji"
        static let day = "day"
        static let steps = "steps"
        static let distanceMeters = "distanceMeters"
        static let updatedAt = "updatedAt"
        static let shareURL = "shareURL"
    }

    /// Fixed record name for the crew record — one per zone, so it needs no ID.
    private static let crewRecordName = "crew"

    // MARK: Availability

    func availability() async -> SocialAvailability {
        do {
            switch try await container.accountStatus() {
            case .available:
                return .ready
            case .noAccount:
                return .unavailable(
                    reason: "Sign in to iCloud in Settings to walk with friends. Your own tracking works either way."
                )
            case .restricted:
                return .unavailable(reason: "iCloud is restricted on this device, so crews aren't available.")
            case .couldNotDetermine, .temporarilyUnavailable:
                return .unavailable(reason: "Can't reach iCloud right now. Crews will reconnect automatically.")
            @unknown default:
                return .unavailable(reason: "iCloud is unavailable right now.")
            }
        } catch {
            return .unavailable(reason: "Can't reach iCloud right now. Crews will reconnect automatically.")
        }
    }

    private func ensureAvailable() async throws {
        if let reason = await availability().reason {
            throw SocialError.iCloudUnavailable(reason)
        }
    }

    // MARK: Create

    func createCrew(
        name: String,
        emoji: String,
        accentIndex: Int,
        owner: UserProfile
    ) async throws -> CrewBundle {
        try await ensureAvailable()

        // 1. A zone of its own, so the whole crew can be shared in one go.
        let zoneID = CKRecordZone.ID(
            zoneName: "crew-\(UUID().uuidString)",
            ownerName: CKCurrentUserDefaultName
        )
        _ = try await privateDB.save(CKRecordZone(zoneID: zoneID))

        // 2. Share the zone and take the capability URL off the saved share.
        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = name
        share.publicPermission = .none

        let shareSave = try await privateDB.modifyRecords(
            saving: [share],
            deleting: [],
            savePolicy: .allKeys,
            atomically: true
        )
        guard
            let savedShare = try? shareSave.saveResults[share.recordID]?.get() as? CKShare,
            let shareURL = savedShare.url
        else {
            // Don't leave an orphaned zone behind if sharing failed.
            _ = try? await privateDB.deleteRecordZone(withID: zoneID)
            throw SocialError.shareFailed
        }

        // 3. Claim a code that points at it.
        let code = try await reserveInviteCode(shareURL: shareURL.absoluteString)

        // 4. Seed the zone with the crew and our own membership.
        let crewRecord = CKRecord(
            recordType: RecordType.crew,
            recordID: CKRecord.ID(recordName: Self.crewRecordName, zoneID: zoneID)
        )
        crewRecord[Key.name] = name
        crewRecord[Key.emoji] = emoji
        crewRecord[Key.accentIndex] = accentIndex
        crewRecord[Key.createdAt] = Date()
        crewRecord[Key.inviteCode] = code

        _ = try await privateDB.modifyRecords(
            saving: [crewRecord, memberRecord(for: owner, in: zoneID)],
            deleting: [],
            savePolicy: .allKeys,
            atomically: true
        )

        let crew = Crew(
            name: name,
            emoji: emoji,
            accentIndex: accentIndex,
            inviteCode: code,
            memberIDs: [owner.id],
            isSimulated: false,
            cloud: Crew.CloudReference(
                zoneName: zoneID.zoneName,
                ownerName: nil,
                shareURL: shareURL.absoluteString
            ),
            lastSyncedAt: Date()
        )
        return CrewBundle(crew: crew, members: [])
    }

    /// Claims an unused invite code in the public database.
    ///
    /// The record *name* is the code, so this is a plain create — and a
    /// collision surfaces as a save conflict rather than needing a lookup.
    private func reserveInviteCode(shareURL: String) async throws -> String {
        for _ in 0..<8 {
            let code = InviteCode.generate(length: 8)
            let record = CKRecord(
                recordType: RecordType.invite,
                recordID: CKRecord.ID(recordName: code)
            )
            record[Key.shareURL] = shareURL

            do {
                let result = try await publicDB.modifyRecords(
                    saving: [record],
                    deleting: [],
                    savePolicy: .ifServerRecordUnchanged,
                    atomically: true
                )
                guard let saveResult = result.saveResults[record.recordID] else { continue }

                switch saveResult {
                case .success:
                    return code
                case .failure(let error):
                    // A taken code is the expected miss; anything else is real.
                    guard Self.isConflict(error) else { throw error }
                }
            } catch {
                guard Self.isConflict(error) else { throw error }
            }
        }
        throw SocialError.shareFailed
    }

    // MARK: Join

    func joinCrew(code: String, as profile: UserProfile) async throws -> CrewBundle {
        try await ensureAvailable()

        let normalized = InviteCode.normalize(code)
        guard normalized.count >= 6 else { throw SocialError.invalidCode }

        let invite: CKRecord
        do {
            invite = try await publicDB.record(for: CKRecord.ID(recordName: normalized))
        } catch let error as CKError where error.code == .unknownItem {
            throw SocialError.unknownCode
        }

        guard
            let urlString = invite[Key.shareURL] as? String,
            let url = URL(string: urlString)
        else {
            throw SocialError.unknownCode
        }

        let metadata = try await shareMetadata(for: url)
        // Accepting a share we're already in is a no-op that reports an error,
        // so a failure here shouldn't stop us reading the zone.
        _ = try? await acceptShare(metadata)

        let sharedZoneID = metadata.share.recordID.zoneID
        // If this is our own crew, the zone lives in our private database and
        // has to be addressed with the current-user sentinel, not our record name.
        let myRecordID = try? await container.userRecordID()
        let isOwner = sharedZoneID.ownerName == myRecordID?.recordName

        let reference = Crew.CloudReference(
            zoneName: sharedZoneID.zoneName,
            ownerName: isOwner ? nil : sharedZoneID.ownerName,
            shareURL: urlString
        )

        // Announce ourselves before reading, so the roster we fetch includes us
        // from the crew's point of view.
        _ = try? await database(for: reference).modifyRecords(
            saving: [memberRecord(for: profile, in: zoneID(for: reference))],
            deleting: [],
            savePolicy: .allKeys,
            atomically: true
        )

        var bundle = try await refresh(
            crew: placeholderCrew(code: normalized, reference: reference),
            as: profile
        )
        bundle.crew.inviteCode = normalized
        return bundle
    }

    /// A stand-in used only to carry the zone reference into `refresh`, which
    /// then replaces every field from the crew record itself.
    private func placeholderCrew(code: String, reference: Crew.CloudReference) -> Crew {
        Crew(
            name: "Crew",
            inviteCode: code,
            isSimulated: false,
            cloud: reference
        )
    }

    // MARK: Refresh

    func refresh(crew: Crew, as profile: UserProfile) async throws -> CrewBundle {
        guard let reference = crew.cloud else { throw SocialError.notSupported }
        try await ensureAvailable()

        let zone = zoneID(for: reference)
        let records = try await allRecords(in: zone, database: database(for: reference))

        var updated = crew
        updated.isSimulated = false
        updated.lastSyncedAt = Date()

        if let crewRecord = records.first(where: { $0.recordType == RecordType.crew }) {
            updated.name = crewRecord[Key.name] as? String ?? crew.name
            updated.emoji = crewRecord[Key.emoji] as? String ?? crew.emoji
            updated.accentIndex = crewRecord[Key.accentIndex] as? Int ?? crew.accentIndex
            updated.createdAt = crewRecord[Key.createdAt] as? Date ?? crew.createdAt
            if let code = crewRecord[Key.inviteCode] as? String { updated.inviteCode = code }
        }

        // Everyone's published totals, keyed by whose they are.
        var stepsByProfile: [String: [String: Int]] = [:]
        var latestPublish: [String: Date] = [:]

        for record in records where record.recordType == RecordType.entry {
            guard
                let profileID = record[Key.profileID] as? String,
                let day = record[Key.day] as? String,
                let steps = record[Key.steps] as? Int
            else { continue }

            stepsByProfile[profileID, default: [:]][day] = steps
            if let updatedAt = record[Key.updatedAt] as? Date {
                latestPublish[profileID] = max(latestPublish[profileID] ?? .distantPast, updatedAt)
            }
        }

        var members: [Friend] = []
        for record in records where record.recordType == RecordType.member {
            guard
                let profileID = record[Key.profileID] as? String,
                let id = UUID(uuidString: profileID),
                id != profile.id
            else { continue }

            members.append(
                Friend(
                    id: id,
                    displayName: record[Key.displayName] as? String ?? "Walker",
                    avatarEmoji: record[Key.avatarEmoji] as? String ?? "🏃",
                    accentIndex: record[Key.accentIndex] as? Int ?? 0,
                    isYou: false,
                    reportedSteps: stepsByProfile[profileID] ?? [:],
                    isSimulated: false,
                    lastPublishedAt: latestPublish[profileID]
                )
            )
        }

        members.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        return CrewBundle(crew: updated, members: members)
    }

    // MARK: Publish

    func publish(history: [DailyActivity], profile: UserProfile, to crews: [Crew]) async throws {
        let cloudCrews = crews.filter { $0.cloud != nil }
        guard !cloudCrews.isEmpty else { return }
        try await ensureAvailable()

        for crew in cloudCrews {
            try await publish(history: history, profile: profile, to: crew)
        }
    }

    private func publish(history: [DailyActivity], profile: UserProfile, to crew: Crew) async throws {
        guard let reference = crew.cloud else { return }

        let calendar = Calendar.current
        let zone = zoneID(for: reference)
        let cutoff = calendar.date(
            byAdding: .day,
            value: -Self.publishWindowDays,
            to: calendar.startOfDay(for: Date())
        ) ?? .distantPast

        let window = history.filter { $0.date >= cutoff }
        let previous = publishedSteps(for: reference)
        var current: [String: Int] = [:]
        var changed: [CKRecord] = []

        for day in window {
            let key = Friend.dayKey(day.date, calendar: calendar)
            current[key] = day.steps
            // Only write days whose number actually moved — otherwise every
            // refresh would rewrite six weeks of identical records.
            guard previous[key] != day.steps else { continue }

            let record = CKRecord(
                recordType: RecordType.entry,
                recordID: CKRecord.ID(
                    recordName: "entry-\(profile.id.uuidString)-\(key)",
                    zoneID: zone
                )
            )
            record[Key.profileID] = profile.id.uuidString
            record[Key.day] = key
            record[Key.steps] = day.steps
            record[Key.distanceMeters] = day.distanceMeters
            record[Key.updatedAt] = Date()
            changed.append(record)
        }

        // Keep our own membership row fresh so name and avatar edits propagate.
        changed.append(memberRecord(for: profile, in: zone))

        guard !changed.isEmpty else { return }

        _ = try await database(for: reference).modifyRecords(
            saving: changed,
            deleting: [],
            savePolicy: .allKeys,
            atomically: false
        )
        setPublishedSteps(current, for: reference)
    }

    // MARK: Leave

    func leave(crew: Crew, as profile: UserProfile) async throws {
        guard let reference = crew.cloud else { return }
        let zone = zoneID(for: reference)

        if reference.isOwner {
            // Deleting the zone takes the share and everyone's data with it.
            _ = try? await privateDB.deleteRecordZone(withID: zone)
            _ = try? await publicDB.deleteRecord(withID: CKRecord.ID(recordName: crew.inviteCode))
        } else {
            // A participant leaves by dropping the share from their own shared
            // database; the owner's copy is untouched.
            _ = try? await sharedDB.deleteRecord(
                withID: CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zone)
            )
        }

        defaults.removeObject(forKey: publishedKey(for: reference))
    }

    // MARK: CloudKit plumbing

    private func zoneID(for reference: Crew.CloudReference) -> CKRecordZone.ID {
        CKRecordZone.ID(
            zoneName: reference.zoneName,
            ownerName: reference.ownerName ?? CKCurrentUserDefaultName
        )
    }

    private func database(for reference: Crew.CloudReference) -> CKDatabase {
        reference.isOwner ? privateDB : sharedDB
    }

    private func memberRecord(for profile: UserProfile, in zone: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(
            recordType: RecordType.member,
            recordID: CKRecord.ID(recordName: "member-\(profile.id.uuidString)", zoneID: zone)
        )
        record[Key.profileID] = profile.id.uuidString
        record[Key.displayName] = profile.displayName
        record[Key.avatarEmoji] = profile.avatarEmoji
        record[Key.accentIndex] = profile.accentIndex
        record[Key.updatedAt] = Date()
        return record
    }

    /// Every record in a zone, paged until the server says it's done.
    private func allRecords(in zone: CKRecordZone.ID, database: CKDatabase) async throws -> [CKRecord] {
        var records: [CKRecord] = []
        var token: CKServerChangeToken?

        while true {
            let changes = try await database.recordZoneChanges(inZoneWith: zone, since: token)
            for (_, result) in changes.modificationResultsByID {
                if case .success(let modification) = result {
                    records.append(modification.record)
                }
            }
            guard changes.moreComing else { break }
            token = changes.changeToken
        }

        return records
    }

    private func shareMetadata(for url: URL) async throws -> CKShare.Metadata {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchShareMetadataOperation(shareURLs: [url])
            operation.shouldFetchRootRecord = false

            var perShare: Result<CKShare.Metadata, Error>?
            operation.perShareMetadataResultBlock = { _, result in
                perShare = result
            }
            operation.fetchShareMetadataResultBlock = { overall in
                if let perShare {
                    continuation.resume(with: perShare)
                } else if case .failure(let error) = overall {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: SocialError.unknownCode)
                }
            }
            container.add(operation)
        }
    }

    private func acceptShare(_ metadata: CKShare.Metadata) async throws -> CKShare {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])

            var perShare: Result<CKShare, Error>?
            operation.perShareResultBlock = { _, result in
                perShare = result
            }
            operation.acceptSharesResultBlock = { overall in
                if let perShare {
                    continuation.resume(with: perShare)
                } else if case .failure(let error) = overall {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: SocialError.shareFailed)
                }
            }
            container.add(operation)
        }
    }

    /// True when a save failed because something already occupies that record ID.
    private static func isConflict(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else { return false }
        if ckError.code == .serverRecordChanged { return true }
        if ckError.code == .partialFailure {
            let inner = ckError.partialErrorsByItemID?.values.compactMap { $0 as? CKError } ?? []
            return inner.contains { $0.code == .serverRecordChanged }
        }
        return false
    }

    // MARK: Publish bookkeeping

    /// What we last pushed for a crew, so publishes only send real changes.
    private func publishedKey(for reference: Crew.CloudReference) -> String {
        "cloudkit.published.\(reference.zoneName)"
    }

    private func publishedSteps(for reference: Crew.CloudReference) -> [String: Int] {
        guard
            let data = defaults.data(forKey: publishedKey(for: reference)),
            let decoded = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return [:] }
        return decoded
    }

    private func setPublishedSteps(_ steps: [String: Int], for reference: Crew.CloudReference) {
        guard let data = try? JSONEncoder().encode(steps) else { return }
        defaults.set(data, forKey: publishedKey(for: reference))
    }
}
