import Foundation
import SwiftData

enum NoteSource: String, Codable, CaseIterable {
    case typed
    case voice
    case migratedLegacy
}

@Model
final class ContactNote: Identifiable {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var body: String
    var sourceRawValue: String
    var transcriptLanguage: String?
    var audioDurationSec: Double?
    var contact: Contact?

    init(
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        body: String,
        source: NoteSource = .typed,
        transcriptLanguage: String? = nil,
        audioDurationSec: Double? = nil,
        contact: Contact? = nil
    ) {
        self.id = UUID()
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.body = body
        self.sourceRawValue = source.rawValue
        self.transcriptLanguage = transcriptLanguage
        self.audioDurationSec = audioDurationSec
        self.contact = contact
    }

    var source: NoteSource {
        get { NoteSource(rawValue: sourceRawValue) ?? .typed }
        set { sourceRawValue = newValue.rawValue }
    }
}

@Model
final class ContactReminder: Identifiable {
    var id: UUID
    var createdAt: Date
    var title: String
    var isCompleted: Bool
    var contact: Contact?

    init(
        createdAt: Date = Date(),
        title: String,
        isCompleted: Bool = false,
        contact: Contact? = nil
    ) {
        self.id = UUID()
        self.createdAt = createdAt
        self.title = title
        self.isCompleted = isCompleted
        self.contact = contact
    }
}

// Legacy model kept only for one migration cycle.
@Model
final class CheckIn: Identifiable {
    var id: UUID
    var date: Date
    var note: String
    var title: String
    var contact: Contact?

    init(
        date: Date = Date(),
        note: String = "",
        title: String = "Check-in",
        contact: Contact? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.note = note
        self.title = title
        self.contact = contact
    }
}

enum LegacyDataMigrator {
    private static let checkInMigrationFlag = "didMigrateLegacyCheckInsToContactNotes_v1"
    private static let contactDefaultsFlag = "didNormalizeContactsForSocialCircleAndGiftIdea_v2"

    static func migrateIfNeeded(context: ModelContext) throws {
        if !UserDefaults.standard.bool(forKey: checkInMigrationFlag) {
            try migrateLegacyCheckInsAndPlainNotes(context: context)
            UserDefaults.standard.set(true, forKey: checkInMigrationFlag)
        }

        if !UserDefaults.standard.bool(forKey: contactDefaultsFlag) {
            try normalizeContactDefaults(context: context)
            UserDefaults.standard.set(true, forKey: contactDefaultsFlag)
        }
    }

    private static func migrateLegacyCheckInsAndPlainNotes(context: ModelContext) throws {
        let legacyCheckIns = try context.fetch(FetchDescriptor<CheckIn>())
        let contacts = try context.fetch(FetchDescriptor<Contact>())

        for legacy in legacyCheckIns {
            guard let contact = legacy.contact else {
                context.delete(legacy)
                continue
            }

            let titlePart = legacy.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let notePart = legacy.note.trimmingCharacters(in: .whitespacesAndNewlines)
            let mergedBody: String

            if titlePart.isEmpty || titlePart.lowercased() == "check-in" {
                mergedBody = notePart
            } else if notePart.isEmpty {
                mergedBody = titlePart
            } else {
                mergedBody = "\(titlePart)\n\n\(notePart)"
            }

            if !mergedBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let migrated = ContactNote(
                    createdAt: legacy.date,
                    updatedAt: legacy.date,
                    body: mergedBody,
                    source: .migratedLegacy,
                    transcriptLanguage: nil,
                    audioDurationSec: nil,
                    contact: contact
                )
                context.insert(migrated)
            }

            context.delete(legacy)
        }

        for contact in contacts {
            let plain = contact.legacyPlainText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !plain.isEmpty else { continue }

            let migrated = ContactNote(
                createdAt: contact.createdAt,
                updatedAt: contact.createdAt,
                body: plain,
                source: .migratedLegacy,
                transcriptLanguage: nil,
                audioDurationSec: nil,
                contact: contact
            )
            context.insert(migrated)
            contact.legacyPlainText = ""
        }

        try context.save()
    }

    private static func normalizeContactDefaults(context: ModelContext) throws {
        let contacts = try context.fetch(FetchDescriptor<Contact>())

        for contact in contacts {
            contact.socialCircle = SocialCircle(legacyRawValue: contact.socialCircleRawValue)
            if contact.giftIdea.trimmingCharacters(in: .newlines).isEmpty {
                contact.giftIdea = ""
            }
        }

        try context.save()
    }
}
