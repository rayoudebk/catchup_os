import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Error requesting notification permission: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleNotification(for contact: Contact) {
        // Remove existing notifications for this contact
        cancelNotification(for: contact)
        
        guard let nextCheckInDate = contact.nextCheckInDate else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Time to catch up!"
        content.body = "It's been a while since you connected with \(contact.name)"
        content.sound = .default
        content.badge = 1
        
        // Create date components for the notification
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: nextCheckInDate
        )
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: contact.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    func cancelNotification(for contact: Contact) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [contact.id.uuidString]
        )
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func getPendingNotifications(completion: @escaping ([UNNotificationRequest]) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            completion(requests)
        }
    }
}

