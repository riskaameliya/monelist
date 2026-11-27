import Foundation
import AppKit
import UserNotifications

enum PomoPhase {
    case focus, shortBreak, longBreak

    var label: String {
        switch self {
        case .focus: return "Fokus"
        case .shortBreak: return "Istirahat Singkat"
        case .longBreak: return "Istirahat Panjang"
        }
    }

    var duration: TimeInterval {
        switch self {
        case .focus: return 25 * 60
        case .shortBreak: return 5 * 60
        case .longBreak: return 15 * 60
        }
    }
}

/// Fokus 25 menit secara default, istirahat 5 menit, dan istirahat panjang 15 menit tiap 4 sesi.
/// Sisa waktu dihitung dari selisih dengan waktu selesai (bukan mengurangi detik),
/// jadi tetap akurat walau jendela disembunyikan atau Mac sempat sibuk.
final class PomodoroTimer: ObservableObject {
    @Published private(set) var phase: PomoPhase = .focus
    @Published private(set) var remaining: TimeInterval = PomoPhase.focus.duration
    @Published private(set) var isRunning = false
    @Published private(set) var completedFocus = 0
    @Published private(set) var isCelebratingFocus = false
    @Published private(set) var focusDurationMinutes = 25

    var onFocusFinished: (() -> Void)?

    private let focusDurationKey = "pomo.focusDurationMinutes.v1"
    private let completedFocusKey = "pomo.completedFocus.v1"
    private var endDate: Date?
    private var ticker: Timer?
    private var completionSound: NSSound?

    init() {
        let defaults = UserDefaults.standard
        let savedDuration = defaults.integer(forKey: focusDurationKey)
        if (1...1440).contains(savedDuration) {
            focusDurationMinutes = savedDuration
        }
        completedFocus = max(0, defaults.integer(forKey: completedFocusKey))
        remaining = TimeInterval(focusDurationMinutes * 60)

        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
        }
    }

    func migrateCompletedFocusCount(from tasks: [TodoItem]) {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: completedFocusKey) == nil else { return }
        completedFocus = tasks.reduce(0) { $0 + $1.pomodoros }
        defaults.set(completedFocus, forKey: completedFocusKey)
    }

    func resetCompletedFocusCount() {
        completedFocus = 0
        UserDefaults.standard.set(0, forKey: completedFocusKey)
    }

    private var currentPhaseDuration: TimeInterval {
        phase == .focus ? TimeInterval(focusDurationMinutes * 60) : phase.duration
    }

    var progress: Double {
        1 - remaining / currentPhaseDuration
    }

    @discardableResult
    func setFocusDuration(minutes: Int) -> Bool {
        guard (1...1440).contains(minutes) else { return false }
        focusDurationMinutes = minutes
        UserDefaults.standard.set(minutes, forKey: focusDurationKey)
        if phase == .focus && !isRunning {
            remaining = currentPhaseDuration
        }
        return true
    }

    func start() {
        guard !isRunning else { return }
        isCelebratingFocus = false
        endDate = Date().addingTimeInterval(remaining)
        isRunning = true
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    func pause() {
        guard isRunning else { return }
        if let end = endDate { remaining = max(0, end.timeIntervalSinceNow) }
        stopTicker()
        isRunning = false
    }

    func reset() {
        isCelebratingFocus = false
        stopTicker()
        isRunning = false
        remaining = currentPhaseDuration
    }

    func skip() {
        isCelebratingFocus = false
        stopTicker()
        isRunning = false
        moveToNextPhase()
    }

    private func tick() {
        guard let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        if remaining <= 0 { finish() }
    }

    private func finish() {
        stopTicker()
        isRunning = false
        let wasFocus = (phase == .focus)
        isCelebratingFocus = wasFocus
        if wasFocus {
            completedFocus += 1
            UserDefaults.standard.set(completedFocus, forKey: completedFocusKey)
            onFocusFinished?()
        }
        moveToNextPhase()
        if wasFocus {
            notify(title: "Sesi fokus selesai", body: "Waktunya \(phase.label.lowercased()).")
        } else {
            notify(title: "Istirahat selesai", body: "Siap lanjut fokus?")
        }
    }

    private func moveToNextPhase() {
        switch phase {
        case .focus:
            phase = (completedFocus > 0 && completedFocus % 4 == 0) ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            phase = .focus
        }
        remaining = currentPhaseDuration
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
        endDate = nil
    }

    private func notify(title: String, body: String) {
        if completionSound == nil,
           let url = Bundle.main.url(forResource: "cat-meow", withExtension: "caf") {
            completionSound = NSSound(contentsOf: url, byReference: false)
        }
        completionSound?.play()

        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
