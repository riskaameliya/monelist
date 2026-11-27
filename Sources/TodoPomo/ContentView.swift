import SwiftUI
import AppKit
import ImageIO

private enum PomoStyle {
    static let ink = Color(red: 0.10, green: 0.12, blue: 0.16)
    static let coral = Color(red: 1, green: 0.55, blue: 0.44)
    static let mint = Color(red: 0.48, green: 0.83, blue: 0.70)
    static let canvas = adaptive(light: 0xF5F3EF, dark: 0x191B21)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x23262F)
    static let line = adaptive(light: 0xE7E2DA, dark: 0x393D49)
    static let muted = adaptive(light: 0x626872, dark: 0xACB1BF)
    static let accent = adaptive(light: 0xAE422F, dark: 0xFF9C88)
    static let success = adaptive(light: 0x267057, dark: 0x84DABC)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 255) / 255,
                green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255,
                alpha: 1
            )
        })
    }
}

private struct PomoMascot: View {
    @EnvironmentObject var pomo: PomodoroTimer

    private enum Expression: Int, CaseIterable {
        case neutral, focused, sleepy, celebrating
    }

    private static let sprites: [Expression: CGImage] = {
        guard let url = Bundle.main.url(forResource: "PomoMascot", withExtension: "png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let sheet = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return [:] }

        let width = sheet.width / 2
        let height = sheet.height / 2
        var sprites: [Expression: CGImage] = [:]
        for expression in Expression.allCases {
            let index = expression.rawValue
            let cell = CGRect(x: (index % 2) * width, y: (index / 2) * height, width: width, height: height)
            sprites[expression] = sheet.cropping(to: cell)
        }
        return sprites
    }()

    private var expression: Expression {
        if pomo.isCelebratingFocus { return .celebrating }
        if pomo.phase != .focus { return .sleepy }
        return pomo.isRunning ? .focused : .neutral
    }

    var body: some View {
        Group {
            if let sprite = Self.sprites[expression] {
                Image(decorative: sprite, scale: 1)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: pomo.phase == .focus ? "timer" : "cup.and.saucer.fill")
                    .font(.system(size: 11, weight: .semibold))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct PomoLogoMark: View {
    private static let logoImage: NSImage? = {
        guard let url = Bundle.main.url(forResource: "PomoLogo", withExtension: "png") else {
            NSLog("MoneList: PomoLogo.png is missing from app resources.")
            return nil
        }
        return NSImage(contentsOf: url)
    }()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(PomoStyle.ink)
            if let logoImage = Self.logoImage {
                Image(nsImage: logoImage)
                    .resizable()
                    .scaledToFit()
                    .padding(2)
            } else {
                Image(systemName: "timer")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 42, height: 42)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct CircularIconButton: NSViewRepresentable {
    let symbol: String
    let accessibilityLabel: String
    let foregroundColor: NSColor
    let backgroundColor: NSColor
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(frame: .zero)
        button.target = context.coordinator
        button.action = #selector(Coordinator.performAction(_:))
        configure(button)
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.action = action
        configure(button)
    }

    private func configure(_ button: NSButton) {
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.setButtonType(.momentaryPushIn)
        button.focusRingType = .none
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: accessibilityLabel)
        button.contentTintColor = foregroundColor
        button.toolTip = accessibilityLabel
        button.setAccessibilityLabel(accessibilityLabel)
        button.wantsLayer = true
        button.layer?.backgroundColor = backgroundColor.cgColor
        button.layer?.cornerRadius = 17
        button.layer?.masksToBounds = true
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func performAction(_ sender: NSButton) {
            action()
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: TodoStore
    @EnvironmentObject var pomo: PomodoroTimer
    @State private var newTitle = ""
    @State private var isExpanded = false
    @State private var confirmingFocusReset = false
    @State private var taskFrames: [UUID: CGRect] = [:]
    @GestureState private var taskDrag: TaskDrag?
    @Namespace private var taskListSpace

    private struct TaskDrag {
        let id: UUID
        let offset: CGFloat
    }

    private var activeItems: [TodoItem] { store.items.filter { !$0.done } }
    private var doneItems: [TodoItem] { store.items.filter(\.done) }

    var body: some View {
        Group {
            if isExpanded {
                expandedDashboard
            } else {
                Color.clear
            }
        }
        .frame(width: 430, height: 700)
        .background {
            DynamicIslandWindowController(
                isExpanded: $isExpanded,
                isTimerRunning: pomo.isRunning,
                store: store,
                pomo: pomo
            )
        }
        .onAppear {
            pomo.onFocusFinished = { [store] in store.creditFocusedTask() }
            pomo.migrateCompletedFocusCount(from: store.items)
        }
    }

    private var expandedDashboard: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
                .background(PomoStyle.canvas)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PomodoroCard()
                    progressSummary
                    taskSection
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 18)
            }
            .background(PomoStyle.canvas)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            PomoLogoMark()

            Text("MoneList")
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Spacer()
            CircularIconButton(
                symbol: "arrow.down.right.and.arrow.up.left",
                accessibilityLabel: "Kecilkan ke tampilan mini",
                foregroundColor: .labelColor,
                backgroundColor: NSColor(PomoStyle.surface)
            ) {
                isExpanded = false
            }
            .frame(width: 34, height: 34)
        }
    }

    private var progressSummary: some View {
        HStack(spacing: 12) {
            Menu {
                Button("Reset hitungan sesi fokus", role: .destructive) {
                    confirmingFocusReset = true
                }
                .disabled(pomo.completedFocus == 0)
            } label: {
                Label("\(pomo.completedFocus) sesi fokus", systemImage: "flame.fill")
                    .foregroundStyle(PomoStyle.accent)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Opsi hitungan sesi fokus")
            Spacer(minLength: 0)
            Label("\(doneItems.count)/\(store.items.count) selesai", systemImage: "checkmark.circle")
                .foregroundStyle(PomoStyle.success)
        }
        .font(.system(size: 12, weight: .semibold))
        .monospacedDigit()
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(PomoStyle.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(PomoStyle.line, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .alert("Reset hitungan sesi fokus?", isPresented: $confirmingFocusReset) {
            Button("Batal", role: .cancel) {}
            Button("Reset", role: .destructive) { pomo.resetCompletedFocusCount() }
        } message: {
            Text("Total sesi fokus akan kembali ke 0.")
        }
    }

    private var taskSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daftar tugas")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(activeItems.count) tersisa")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PomoStyle.muted)
            }

            HStack(spacing: 9) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PomoStyle.accent)
                TextField("Tambah tugas…", text: $newTitle)
                    .textFieldStyle(.plain)
                    .onSubmit(addTask)
                Button(action: addTask) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(PomoStyle.ink, in: RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                .help("Tambah tugas")
                .accessibilityLabel("Tambah tugas")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(PomoStyle.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(PomoStyle.line, lineWidth: 1)
            }

            if store.items.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(PomoStyle.accent)
                    Text("Belum ada tugas")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Tambahkan tugas pertamamu di atas.")
                        .font(.system(size: 11))
                        .foregroundStyle(PomoStyle.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 25)
                .background(PomoStyle.surface, in: RoundedRectangle(cornerRadius: 16))
            } else if !activeItems.isEmpty {
                taskList(activeItems)
            }

            if !doneItems.isEmpty {
                HStack {
                    Text("Selesai")
                        .font(.system(size: 14, weight: .semibold))
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button("Hapus yang selesai") { store.clearDone() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PomoStyle.muted)
                }
                .padding(.top, 6)
                taskList(doneItems)
            }
        }
    }

    private func taskList(_ items: [TodoItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let drag = taskDrag.flatMap { $0.id == item.id ? $0 : nil }
                TodoRow(
                    item: item,
                    previousID: !item.done && index > 0 ? items[index - 1].id : nil,
                    nextID: !item.done && index + 1 < items.count ? items[index + 1].id : nil,
                    reorderGesture: reorderGesture(for: item.id)
                )
                .background(drag == nil ? Color.clear : PomoStyle.surface)
                .shadow(color: .black.opacity(drag == nil ? 0 : 0.12), radius: 5, y: 2)
                .offset(y: drag?.offset ?? 0)
                .overlay(alignment: .bottom) {
                    if index + 1 < items.count {
                        Divider().padding(.horizontal, 12)
                            .allowsHitTesting(false)
                    }
                }
                .onGeometryChange(for: CGRect.self) { geometry in
                    geometry.frame(in: .named(taskListSpace))
                } action: { frame in
                    if !item.done { taskFrames[item.id] = frame }
                }
                .onDisappear {
                    if !item.done { taskFrames.removeValue(forKey: item.id) }
                }
                .zIndex(drag == nil ? 0 : 1)
            }
        }
        .coordinateSpace(name: taskListSpace)
        .background(PomoStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PomoStyle.line, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    private func reorderGesture(for id: UUID) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(taskListSpace))
            .updating($taskDrag) { value, state, _ in
                guard let offset = boundedTaskOffset(for: id, translation: value.translation.height) else { return }
                state = TaskDrag(id: id, offset: offset)
            }
            .onEnded { value in
                guard let source = taskFrames[id],
                      let offset = boundedTaskOffset(for: id, translation: value.translation.height)
                else { return }
                let center = source.midY + offset
                guard let target = activeItems.first(where: { item in
                    guard let frame = taskFrames[item.id] else { return false }
                    return frame.minY <= center && center <= frame.maxY
                }) else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    _ = store.move(id, toPositionOf: target.id)
                }
            }
    }

    private func boundedTaskOffset(for id: UUID, translation: CGFloat) -> CGFloat? {
        guard let source = taskFrames[id],
              let first = activeItems.first.flatMap({ taskFrames[$0.id] }),
              let last = activeItems.last.flatMap({ taskFrames[$0.id] })
        else { return nil }
        return min(max(translation, first.minY - source.minY), last.maxY - source.maxY)
    }

    private func addTask() {
        store.add(newTitle)
        newTitle = ""
    }
}

private struct CompactDashboard: View {
    static let size = CGSize(width: 188, height: 50)

    @EnvironmentObject var pomo: PomodoroTimer
    @EnvironmentObject var store: TodoStore

    let onExpand: () -> Void

    private var pendingItems: [TodoItem] { store.items.filter { !$0.done } }

    private var timerTint: Color {
        pomo.phase == .focus ? PomoStyle.coral : PomoStyle.mint
    }

    private var focusedTask: TodoItem? {
        pendingItems.first { $0.id == store.focusID }
    }

    var body: some View {
        HStack(spacing: 9) {
            HStack(spacing: 9) {
                ZStack {
                    Circle().strokeBorder(timerTint.opacity(0.24), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: min(max(pomo.progress, 0), 1))
                        .stroke(timerTint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(1)
                    PomoMascot()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(timerTint)
                }
                .frame(width: 28, height: 28)
                .accessibilityLabel(pomo.phase.label)

                VStack(alignment: .leading, spacing: 1) {
                    Text(format(pomo.remaining))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    if let title = focusedTask?.title ?? pendingItems.first?.title {
                        Text(title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.76))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .overlay {
                MiniPanelDragArea(taskTitle: focusedTask?.title ?? pendingItems.first?.title)
                    .accessibilityHidden(true)
            }

            Button(action: toggleTimer) {
                Image(systemName: pomo.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PomoStyle.ink)
                    .frame(width: 26, height: 26)
                    .background(timerTint, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(pomo.isRunning ? "Jeda timer" : "Mulai timer")
            .accessibilityLabel(pomo.isRunning ? "Jeda timer" : "Mulai timer")

            Button(action: onExpand) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Buka tampilan detail")
            .accessibilityLabel("Buka tampilan detail")
        }
        .padding(.horizontal, 11)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(PomoStyle.ink, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    private func format(_ time: TimeInterval) -> String {
        let seconds = Int(ceil(time))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func toggleTimer() {
        if pomo.isRunning {
            pomo.pause()
            return
        }

        if focusedTask == nil, let nextTask = pendingItems.first {
            if let focusID = store.focusID {
                store.toggleFocus(focusID)
            }
            store.toggleFocus(nextTask.id)
        }
        pomo.start()
    }
}

private struct DynamicIslandWindowController: NSViewRepresentable {
    @Binding var isExpanded: Bool
    let isTimerRunning: Bool
    let store: TodoStore
    let pomo: PomodoroTimer

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let anchor = PanelAnchorView()
        let coordinator = context.coordinator
        anchor.onWindowAttached = { [weak coordinator] window in
            coordinator?.attach(to: window)
        }
        context.coordinator.update(
            isExpanded: isExpanded,
            isTimerRunning: isTimerRunning,
            store: store,
            pomo: pomo,
            onExpand: { isExpanded = true }
        )
        return anchor
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(
            isExpanded: isExpanded,
            isTimerRunning: isTimerRunning,
            store: store,
            pomo: pomo,
            onExpand: { isExpanded = true }
        )
    }

    final class Coordinator {
        private weak var rootWindow: NSWindow?
        private var islandPanel: KeyablePanel?
        private var isExpanded = false
        private var isTimerRunning = false
        private var appliedMode: Bool?
        private var spaceObserver: NSObjectProtocol?
        private var store: TodoStore?
        private var pomo: PomodoroTimer?
        private var onExpand: (() -> Void)?

        deinit {
            if let spaceObserver {
                NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver)
            }
        }

        func update(
            isExpanded: Bool,
            isTimerRunning: Bool,
            store: TodoStore,
            pomo: PomodoroTimer,
            onExpand: @escaping () -> Void
        ) {
            self.isExpanded = isExpanded
            self.isTimerRunning = isTimerRunning
            self.store = store
            self.pomo = pomo
            self.onExpand = onExpand
            presentIfNeeded()
        }

        func attach(to window: NSWindow) {
            rootWindow = window
            if spaceObserver == nil {
                spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
                    forName: NSWorkspace.activeSpaceDidChangeNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.updatePanelVisibility()
                }
            }
            presentIfNeeded(force: true)
        }

        private func presentIfNeeded(force: Bool = false) {
            guard let rootWindow, let store, let pomo else { return }
            if islandPanel == nil {
                let panel = KeyablePanel(
                    contentRect: NSRect(origin: .zero, size: CompactDashboard.size),
                    styleMask: [.borderless, .nonactivatingPanel],
                    backing: .buffered,
                    defer: false
                )
                panel.isFloatingPanel = true
                panel.hidesOnDeactivate = false
                panel.isReleasedWhenClosed = false
                panel.level = .statusBar
                panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                panel.backgroundColor = .clear
                panel.isOpaque = false
                panel.hasShadow = false
                let island = CompactDashboard { [weak self] in self?.expandDashboard() }
                    .environmentObject(store)
                    .environmentObject(pomo)
                panel.contentView = NSHostingView(rootView: AnyView(island))
                islandPanel = panel
            }

            if force || appliedMode != isExpanded {
                rootWindow.alphaValue = isExpanded ? 1 : 0
                rootWindow.ignoresMouseEvents = !isExpanded
                if isExpanded {
                    rootWindow.setContentSize(NSSize(width: 430, height: 700))
                    rootWindow.center()
                    rootWindow.makeKeyAndOrderFront(nil)
                }
                appliedMode = isExpanded
            }
            updatePanelVisibility()
        }

        private func expandDashboard() {
            if isExpanded {
                NSApp.activate(ignoringOtherApps: true)
                rootWindow?.makeKeyAndOrderFront(nil)
            } else {
                NSApp.activate(ignoringOtherApps: true)
                onExpand?()
            }
        }

        private func updatePanelVisibility() {
            guard let rootWindow, let islandPanel else { return }
            let dashboardIsHere = rootWindow.isVisible && !rootWindow.isMiniaturized
                && rootWindow.isOnActiveSpace
            let shouldShowPanel = !isExpanded || (isTimerRunning && !dashboardIsHere)

            if shouldShowPanel && !islandPanel.isVisible {
                showIslandPanel(islandPanel, relativeTo: rootWindow)
            } else if !shouldShowPanel && islandPanel.isVisible {
                islandPanel.orderOut(nil)
            }
        }

        private func showIslandPanel(_ panel: NSWindow?, relativeTo rootWindow: NSWindow) {
            guard let panel else { return }
            let size = CompactDashboard.size
            if let origin = KeyablePanel.savedOrigin {
                panel.setFrameOrigin(origin)
            } else if let screen = rootWindow.screen ?? NSScreen.main {
                let visibleFrame = screen.visibleFrame
                panel.setFrameOrigin(NSPoint(
                    x: visibleFrame.midX - size.width / 2,
                    y: visibleFrame.maxY - size.height - 8
                ))
            }
            panel.orderFrontRegardless()
        }
    }
}

private final class PanelAnchorView: NSView {
    var onWindowAttached: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            onWindowAttached?(window)
        }
    }
}

private struct MiniPanelDragArea: NSViewRepresentable {
    let taskTitle: String?

    func makeNSView(context: Context) -> DragView {
        DragView()
    }

    func updateNSView(_ view: DragView, context: Context) {
        view.toolTip = taskTitle.map { "\($0) · Seret untuk memindahkan panel" }
            ?? "Seret untuk memindahkan panel"
    }

    final class DragView: NSView {
        private var grabOffset: NSPoint?
        private var didDrag = false

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }

        override func mouseDown(with event: NSEvent) {
            grabOffset = event.locationInWindow
            didDrag = false
        }

        override func mouseDragged(with event: NSEvent) {
            guard let panel = window as? KeyablePanel, let grabOffset else { return }
            let pointer = NSEvent.mouseLocation
            panel.setFrameOrigin(NSPoint(
                x: pointer.x - grabOffset.x,
                y: pointer.y - grabOffset.y
            ))
            didDrag = true
        }

        override func mouseUp(with event: NSEvent) {
            if didDrag, let panel = window as? KeyablePanel {
                panel.savePosition()
            }
            grabOffset = nil
            didDrag = false
        }
    }
}

private final class KeyablePanel: NSPanel {
    private static let positionKey = "pomo.miniPanelOrigin.v1"

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    static var savedOrigin: NSPoint? {
        guard let coordinates = UserDefaults.standard.string(forKey: positionKey) else { return nil }
        let origin = NSPointFromString(coordinates)
        let frame = NSRect(origin: origin, size: CompactDashboard.size)
        return NSScreen.screens.contains { $0.frame.intersects(frame) } ? origin : nil
    }

    func savePosition() {
        UserDefaults.standard.set(NSStringFromPoint(frame.origin), forKey: Self.positionKey)
    }
}

private struct TodoRow<ReorderGesture: Gesture>: View {
    @EnvironmentObject var store: TodoStore
    let item: TodoItem
    let previousID: UUID?
    let nextID: UUID?
    let reorderGesture: ReorderGesture

    private var isFocused: Bool { store.focusID == item.id }

    var body: some View {
        rowContent {
            if previousID != nil || nextID != nil {
                dragHandle
                    .gesture(reorderGesture)
                    .help("Seret ke tugas lain untuk mengubah urutan")
                    .accessibilityLabel("Ubah urutan tugas")
                    .accessibilityActions {
                        if let previousID {
                            Button("Pindah ke atas") { store.move(item.id, toPositionOf: previousID) }
                        }
                        if let nextID {
                            Button("Pindah ke bawah") { store.move(item.id, toPositionOf: nextID) }
                        }
                    }
            }
        }
        .background(isFocused ? PomoStyle.coral.opacity(0.12) : .clear)
    }

    private var dragHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(PomoStyle.muted)
            .frame(width: 20, height: 26)
            .contentShape(Rectangle())
    }

    private func rowContent<Handle: View>(@ViewBuilder handle: () -> Handle) -> some View {
        HStack(spacing: 10) {
            handle()

            Button { store.toggle(item.id) } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(item.done ? PomoStyle.success : PomoStyle.muted)
                    .frame(width: 26, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(item.done ? "Tandai belum selesai" : "Tandai selesai")

            Text(item.title)
                .font(.system(size: 13, weight: isFocused ? .semibold : .medium))
                .strikethrough(item.done)
                .foregroundStyle(item.done ? PomoStyle.muted : Color.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if item.pomodoros > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                    Text("\(item.pomodoros)")
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PomoStyle.accent)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(PomoStyle.coral.opacity(0.1), in: Capsule())
            }

            if !item.done {
                Button { store.toggleFocus(item.id) } label: {
                    Image(systemName: isFocused ? "target" : "scope")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isFocused ? PomoStyle.accent : PomoStyle.muted)
                        .frame(width: 25, height: 25)
                        .background(isFocused ? PomoStyle.coral.opacity(0.12) : .clear, in: Circle())
                }
                .buttonStyle(.plain)
                .help(isFocused ? "Lepas fokus dari tugas" : "Fokuskan pomodoro ke tugas ini")
                .accessibilityLabel(isFocused ? "Lepas fokus dari tugas" : "Fokuskan pomodoro ke tugas ini")
            }

            Button { store.delete(item.id) } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PomoStyle.muted)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Hapus tugas")
            .accessibilityLabel("Hapus tugas")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }
}

private struct PomodoroCard: View {
    @EnvironmentObject var pomo: PomodoroTimer
    @EnvironmentObject var store: TodoStore
    @State private var focusMinutes = 25
    @State private var showingDurationSettings = false

    private var tint: Color {
        pomo.phase == .focus ? PomoStyle.coral : PomoStyle.mint
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                PomoMascot()
                    .frame(width: 52, height: 52)
                    .foregroundStyle(tint)

                Text(pomo.phase.label.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(tint.opacity(0.13), in: Capsule())
                Spacer()
                Button {
                    focusMinutes = pomo.focusDurationMinutes
                    showingDurationSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.78))
                        .frame(width: 25, height: 25)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Atur durasi fokus")
                .popover(isPresented: $showingDurationSettings) {
                    durationSettings
                }
            }

            Text(format(pomo.remaining))
                .font(.system(size: 54, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Waktu tersisa")
                .accessibilityValue(format(pomo.remaining))

            GeometryReader { geometry in
                Capsule()
                    .fill(tint)
                    .frame(width: geometry.size.width * min(max(pomo.progress, 0), 1))
                    .animation(.linear(duration: 0.25), value: pomo.progress)
            }
            .frame(height: 5)
            .background(.white.opacity(0.16), in: Capsule())
            .accessibilityHidden(true)

            HStack(spacing: 9) {
                Button {
                    if pomo.isRunning { pomo.pause() } else { pomo.start() }
                } label: {
                    Label(pomo.isRunning ? "Jeda" : (pomo.phase == .focus ? "Mulai fokus" : "Mulai istirahat"), systemImage: pomo.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PomoStyle.ink)
                        .padding(.horizontal, 18)
                        .frame(height: 36)
                        .background(tint, in: Capsule())
                }
                .buttonStyle(.plain)

                Button { pomo.reset() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Atur ulang timer")

                Button { pomo.skip() } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Lewati sesi")
            }

            HStack(spacing: 5) {
                Image(systemName: store.focusTitle == nil ? "info.circle" : "target")
                    .font(.system(size: 10))
                Text(store.focusTitle.map { "Fokus: \($0)" } ?? "Pilih tugas untuk mencatat sesi")
                    .lineLimit(1)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white.opacity(0.65))
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.19, green: 0.21, blue: 0.28), PomoStyle.ink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(tint.opacity(0.13))
                        .frame(width: 145, height: 145)
                        .blur(radius: 35)
                        .offset(x: 28, y: -50)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var durationSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Durasi fokus")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                TextField("Menit", value: $focusMinutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .frame(width: 72)

                Stepper("", value: $focusMinutes, in: 1...1440)
                    .labelsHidden()
                Text("menit")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PomoStyle.muted)
            }

            Text("Pilih 1–1440 menit. Timer yang sedang berjalan tidak berubah.")
                .font(.system(size: 10))
                .foregroundStyle(PomoStyle.muted)
                .fixedSize(horizontal: false, vertical: true)

            Button("Simpan") {
                if pomo.setFocusDuration(minutes: focusMinutes) {
                    showingDurationSettings = false
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(PomoStyle.coral)
            .disabled(!(1...1440).contains(focusMinutes))
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .frame(width: 250)
    }

    private func format(_ time: TimeInterval) -> String {
        let seconds = Int(ceil(time))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
