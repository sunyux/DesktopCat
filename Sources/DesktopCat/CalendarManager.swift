import EventKit
import Foundation
import UserNotifications

struct UpcomingCalendarEvent {
    let id: String
    let title: String
    let startDate: Date
    let calendarTitle: String
    let isAllDay: Bool
}

final class CalendarManager {
    private enum DefaultsKey {
        static let enabled = "desktopCat.calendar.enabled"
    }

    private let eventStore = EKEventStore()
    private let notificationCenter = UNUserNotificationCenter.current()
    private let notificationPrefix = "desktopcat.calendar."
    private var refreshTimer: Timer?
    private var eventStoreObserver: NSObjectProtocol?

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: DefaultsKey.enabled)
    }

    init() {
        eventStoreObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            self?.refreshAndSchedule()
        }
    }

    deinit {
        refreshTimer?.invalidate()
        if let eventStoreObserver {
            NotificationCenter.default.removeObserver(eventStoreObserver)
        }
    }

    func start() {
        guard isEnabled, hasCalendarAccess else { return }
        refreshAndSchedule()
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 15 * 60,
            repeats: true
        ) { [weak self] _ in
            self?.refreshAndSchedule()
        }
    }

    func connect(completion: @escaping (Result<[UpcomingCalendarEvent], Error>) -> Void) {
        requestCalendarAccess { [weak self] granted, error in
            guard let self else { return }

            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard granted else {
                let error = NSError(
                    domain: "DesktopCat.Calendar",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: L10n.text(
                            "日历访问未获授权。请在系统设置 → 隐私与安全性 → 日历中允许 DesktopCat。",
                            "Calendar access was not granted. Enable DesktopCat in System Settings → Privacy & Security → Calendars."
                        )
                    ]
                )
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            self.notificationCenter.requestAuthorization(
                options: [.alert, .sound]
            ) { _, _ in
                UserDefaults.standard.set(true, forKey: DefaultsKey.enabled)
                UserDefaults.standard.synchronize()
                self.start()
                let events = self.upcomingEvents()
                DispatchQueue.main.async { completion(.success(events)) }
            }
        }
    }

    func disconnect() {
        UserDefaults.standard.set(false, forKey: DefaultsKey.enabled)
        UserDefaults.standard.synchronize()
        refreshTimer?.invalidate()
        refreshTimer = nil
        removeScheduledNotifications()
    }

    func upcomingEvents(days: Int = 7) -> [UpcomingCalendarEvent] {
        guard hasCalendarAccess else { return [] }

        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: days, to: start)
            ?? start.addingTimeInterval(TimeInterval(days * 24 * 60 * 60))
        let predicate = eventStore.predicateForEvents(
            withStart: start,
            end: end,
            calendars: nil
        )

        return eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map {
                UpcomingCalendarEvent(
                    id: $0.eventIdentifier ?? UUID().uuidString,
                    title: $0.title?.isEmpty == false
                        ? $0.title
                        : L10n.text("无标题事件", "Untitled event"),
                    startDate: $0.startDate,
                    calendarTitle: $0.calendar.title,
                    isAllDay: $0.isAllDay
                )
            }
    }

    func refreshAndSchedule() {
        guard isEnabled, hasCalendarAccess else { return }
        let events = upcomingEvents()
        removeScheduledNotifications {
            self.scheduleNotifications(for: events)
        }
    }

    private var hasCalendarAccess: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            return status == .fullAccess
        }
        return status == .authorized
    }

    private func requestCalendarAccess(
        completion: @escaping (Bool, Error?) -> Void
    ) {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents(completion: completion)
        } else {
            eventStore.requestAccess(to: .event, completion: completion)
        }
    }

    private func scheduleNotifications(for events: [UpcomingCalendarEvent]) {
        let now = Date()

        for event in events where !event.isAllDay {
            let notificationDate = event.startDate.addingTimeInterval(-10 * 60)
            guard notificationDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = L10n.text("会议即将开始", "Meeting starting soon")
            content.body = L10n.text(
                "\(event.title) 将在 10 分钟后开始。",
                "\(event.title) starts in 10 minutes."
            )
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: notificationDate
            )
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: false
            )
            let identifier = notificationPrefix
                + event.id.replacingOccurrences(of: "/", with: "-")
                + ".\(Int(event.startDate.timeIntervalSince1970))"
            notificationCenter.add(
                UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: trigger
                )
            )
        }
    }

    private func removeScheduledNotifications(completion: (() -> Void)? = nil) {
        notificationCenter.getPendingNotificationRequests { requests in
            let identifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(self.notificationPrefix) }
            self.notificationCenter.removePendingNotificationRequests(
                withIdentifiers: identifiers
            )
            completion?()
        }
    }
}
