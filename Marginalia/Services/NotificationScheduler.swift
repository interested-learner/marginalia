import SwiftUI
import SwiftData
import UserNotifications

/// One reminder a day, seven scheduled ahead, refreshed on every launch.
///
/// The impure half of `NotificationPlan`: this asks for permission, hands the
/// system its requests, and takes them back. Nothing here decides *what* a
/// reminder says.
///
/// **Permission is asked at first use** — the moment the toggle in settings is
/// turned on, never at launch. Same rule as the microphone and the camera.
///
/// Seven ahead rather than one repeating request, because the note changes every
/// day and a repeating trigger carries the same text forever. They're rewritten
/// on every launch, so a library that grew yesterday is reflected today.
enum NotificationScheduler {

    /// One id prefix, so a re-schedule can remove exactly what it wrote and
    /// nothing else — the app has no other notifications, but it might.
    private static let prefix = "passim.daily."

    /// What a tap hands back: the note the reminder was about.
    nonisolated static let noteKey = "note"

    /// Whether the app may post anything, **without asking.**
    ///
    /// The split matters: `authorize` can put a system alert on screen and this
    /// can't, so scheduling — which happens on every launch — goes through here
    /// and only the settings toggle goes through the other one. `CLAUDE.md`'s
    /// rule is that permission is requested at first use and never at launch,
    /// and a scheduler that asked would break it every time the app opened.
    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }

    /// Asks, once, from the one place that should: the toggle being turned on.
    /// Returns whether the app may post — a reader who says no gets the toggle
    /// back off rather than a switch that lies.
    static func authorize() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            // Asking again does nothing — iOS only prompts once, and after that
            // it's a trip to Settings. Saying so is `SettingsView`'s job.
            return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }

    /// Replaces every reminder this app has queued with `entries`.
    ///
    /// Always a full replacement, never a diff: the plan is rebuilt from the
    /// library on every launch and every settings change, and reconciling seven
    /// requests would cost more than writing them.
    static func schedule(_ entries: [NotificationPlan.Entry]) async {
        let center = UNUserNotificationCenter.current()
        cancel()

        for entry in entries {
            let content = UNMutableNotificationContent()
            content.title = entry.title
            content.body = entry.body
            content.sound = .default
            content.userInfo = [noteKey: entry.shortID]

            let request = UNNotificationRequest(
                identifier: prefix + entry.when.identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: entry.when, repeats: false)
            )
            try? await center.add(request)
        }
    }

    /// Takes every queued reminder back — the toggle going off, or permission
    /// having been refused.
    static func cancel() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ours = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ours)
        }
    }
}

private extension DateComponents {

    /// `2026-08-15-0800`. Stable for a given firing time, so re-scheduling the
    /// same day twice can't leave two requests behind.
    var identifier: String {
        String(format: "%04d-%02d-%02d-%02d%02d",
               year ?? 0, month ?? 0, day ?? 0, hour ?? 0, minute ?? 0)
    }
}

// MARK: The trigger

extension View {

    /// Keeps the next seven days' reminders current, from one place.
    ///
    /// The same shape as `.linking()`, and for the same reason: scheduling is
    /// triggered by the toggle, by the time, and by the library changing under
    /// them, and three call sites would drift. On the root view, so a launch
    /// rewrites the queue whether or not anybody visits settings.
    func reminders() -> some View { modifier(Reminders()) }
}

private struct Reminders: ViewModifier {
    @Query private var notes: [Note]

    @AppStorage(Preferences.Key.notificationsOn) private var on = false
    @AppStorage(Preferences.Key.notificationMinute) private var minute = Preferences.defaultMinute

    func body(content: Content) -> some View {
        content.task(id: Plan(on: on, minute: minute, count: notes.count)) {
            // `isAuthorized`, never `authorize` — this runs on every launch, and
            // a permission prompt at launch is the one thing this app doesn't do.
            guard on, await NotificationScheduler.isAuthorized() else {
                NotificationScheduler.cancel()
                return
            }
            await NotificationScheduler.schedule(
                NotificationPlan.entries(for: notes, minute: minute, from: .now)
            )
        }
    }

    /// The note count rather than the notes: a reminder names the first card of
    /// a day's set, and what changes that is a note arriving or leaving.
    private struct Plan: Equatable {
        let on: Bool
        let minute: Int
        let count: Int
    }
}

/// Where a tapped reminder goes.
///
/// **`nonisolated` on the delegate method, deliberately.** The project builds
/// with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, and `UserNotifications`
/// calls its delegate on its own queue — the same shape as the `Theme` crash in
/// `docs/issues.md` §1, and the reason this hops to the main actor by hand
/// instead of being declared there.
///
/// It posts rather than holding state: `RootView` is the only thing that knows
/// how to open a note, and a router that tried to would be a second copy of the
/// app's navigation.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationRouter()

    /// Fired when a reminder is tapped. `userInfo["note"]` is the short id.
    nonisolated static let tapped = Notification.Name("passim.notificationTapped")

    /// Called once, at launch. Without a delegate a tap just foregrounds the app
    /// and the reminder's note is lost.
    static func install() {
        UNUserNotificationCenter.current().delegate = shared
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let shortID = response.notification.request.content
            .userInfo[NotificationScheduler.noteKey] as? Int

        if let shortID {
            NotificationCenter.default.post(
                name: Self.tapped,
                object: nil,
                userInfo: [NotificationScheduler.noteKey: shortID]
            )
        }
        completionHandler()
    }
}
