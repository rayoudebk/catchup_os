import Foundation
import UserNotifications

protocol BirthdayReminderScheduling {
    func scheduleAnnual(for contact: Contact) throws
    func cancel(for contact: Contact)
}

final class BirthdayReminderManager: BirthdayReminderScheduling {
    static let shared = BirthdayReminderManager()

    private init() {}

    private func identifier(for contact: Contact) -> String {
        "birthday-\(contact.id.uuidString)"
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    func scheduleAnnual(for contact: Contact) throws {
        cancel(for: contact)

        guard let birthday = contact.birthday else {
            return
        }

        let next = nextBirthday(from: birthday)
        let components = Calendar.current.dateComponents([.month, .day, .hour, .minute], from: next)

        let content = UNMutableNotificationContent()
        content.title = "Birthday reminder"
        content.body = "Today is \(contact.name)'s birthday"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: identifier(for: contact),
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancel(for contact: Contact) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier(for: contact)])
    }

    func cancelAllBirthdayNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func refreshAll(contacts: [Contact]) {
        for contact in contacts {
            try? scheduleAnnual(for: contact)
        }
    }

    private func nextBirthday(from birthday: Date) -> Date {
        let calendar = Calendar.current
        let now = Date()

        var bday = calendar.dateComponents([.month, .day], from: birthday)
        bday.hour = 9
        bday.minute = 0

        var next = calendar.date(from: bday) ?? now

        if next < now {
            bday.year = calendar.component(.year, from: now) + 1
            next = calendar.date(from: bday) ?? now
        }

        return next
    }
}
