//
//  ReminderList.swift
//  test
//
//  Created by Plisp on 30/12/18.
//  Copyright © 2018 Plisp. All rights reserved.
//
import Foundation
import UserNotifications
import AwaitKit
import PromiseKit

/* This class manages the on disk storage of the reminders */
class ReminderList {
    static let sharedInstance = ReminderList()
    private let ITEMS_KEY = "reminderItems"
    
    func scheduleItem(_ item: Reminder) {
        let center = UNUserNotificationCenter.current()
        // remove previously existing notification, if any
        center.getPendingNotificationRequests(completionHandler: { notificationRequests in
            for request in notificationRequests {
                if request.identifier == item.id {
                    center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
                    break
                }
            }
        })
        // set the notification's contents
        let notification = UNMutableNotificationContent()
        notification.title = item.title
        notification.body = item.body ?? ""
        // create a trigger from the reminder's `due` property
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.due)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        // create a notification request with the reminder's UUID as identifier
        let request = UNNotificationRequest(identifier: item.id, content: notification, trigger: trigger)
        // register the request
        center.add(request) { error in
            if let error = error {
                print("error scheduling notification: \(error)")
            } else {
                print("registered \(notification.title)")
            }
        }
    }
    
    func addItem(_ item: Reminder) {
        // just create a dummy in the meantime so that the user can see the new reminder
        var reminderDict = UserDefaults.standard.dictionary(forKey: ITEMS_KEY) ?? [:]
        reminderDict[item.id] = ["title": item.title, "body": item.body ?? "", "dueDate": item.due, "tags": item.tags, "id": item.id]
        UserDefaults.standard.set(reminderDict, forKey: ITEMS_KEY) 

        async {
            try await(
                ReminderAPI.create(subject: item.title, body: item.body ?? "", tags: item.tags, date: item.due)
            )
	    // update local list with the correct ID FIXME: this is real crappy
            self.syncReminders()
            self.refreshNotifications() // make sure new reminder w/ 'correct' identifier is scheduled
            NotificationCenter.default.post(name: Notification.Name(rawValue: "reminderListShouldRefresh"), object: self)
        }
    }
    
    func removeItem(_ item: Reminder) {
        let center = UNUserNotificationCenter.current()
        // remove corresponding notification       
        center.getPendingNotificationRequests(completionHandler: { (notificationRequests) in
            for request in notificationRequests {
                if (request.identifier == item.id) {
                    center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
                    print("removed \(request.content.title)")
                    break
                }
            }
        })
        // update on-disk storage 
        if var reminderDict = UserDefaults.standard.dictionary(forKey: ITEMS_KEY) {
            reminderDict.removeValue(forKey: item.id)
            UserDefaults.standard.set(reminderDict, forKey: ITEMS_KEY)
        }
        // update remote 
        async {
            try await(
                ReminderAPI.delete(id: item.id)
            )
        }
    }
    
    func getReminders() -> [Reminder] {
        let reminderDict = UserDefaults.standard.dictionary(forKey: ITEMS_KEY) ?? [:]
        let items = Array(reminderDict.values)
        
        return items.map({
            let item = $0 as! [String: AnyObject]
            return Reminder(title: item["title"] as! String, body: item["body"] as? String, due: item["dueDate"] as! Date, tags: item["tags"] as! [String], id: item["id"] as! String)
        }).sorted(by: { (remA, remB) -> Bool in
            (remA.due.compare(remB.due) == .orderedAscending)
        })
    }
    
    // make sure all incomplete reminders are scheduled as notifications, called once in viewDidLoad
    // At this point I'm not sure whether shutdowns will discard notifications
    func refreshNotifications() {
        let center = UNUserNotificationCenter.current()
        // remove completed
        center.getPendingNotificationRequests(completionHandler: { notificationRequests in
            for reminder in ReminderList.sharedInstance.getReminders() {
                for request in notificationRequests {
                    if (reminder.id == request.identifier) {
                        break
                    }
                }
                
                print("\(reminder.title) was not found")
                // not found, schedule it now
                self.scheduleItem(reminder)
            }
        })
    }

    // sync the shared instance with remote
    func syncReminders() -> Promise<Void> {
        let currentDate = Date()
        var oneYear = DateComponents()
        oneYear.year = 1
        let futureDate = Calendar.current.date(byAdding: oneYear, to: currentDate)!
        
        return async {
            var reminderDict: [String: [String: Any]] = [:]
            let api = try await(ReminderAPI.get(start: currentDate, end: futureDate))
            
            for reminder in api {
                reminderDict[reminder.id] = ["title": reminder.title, "body": reminder.body ?? "", "dueDate": reminder.due, "tags": reminder.tags, "id": reminder.id]
            }
            
            UserDefaults.standard.set(reminderDict, forKey: self.ITEMS_KEY)
        }
    }
}
