import AppKit

enum ProductivityTab: Int {
    case todo = 0
    case timer = 1
}

private struct TodoItem: Codable {
    let id: UUID
    var title: String
    var isCompleted: Bool
}

private enum PomodoroPhase: String {
    case focus
    case breakTime

    var duration: TimeInterval {
        switch self {
        case .focus: return 25 * 60
        case .breakTime: return 5 * 60
        }
    }

    var title: String {
        switch self {
        case .focus: return "专注时间"
        case .breakTime: return "休息时间"
        }
    }
}

private final class ProductivityPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class TodoCellView: NSTableCellView {
    private let checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let deleteButton = NSButton(title: "删除", target: nil, action: nil)

    var onToggle: (() -> Void)?
    var onDelete: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        checkbox.frame = NSRect(x: 4, y: 5, width: 226, height: 24)
        checkbox.autoresizingMask = [.width]
        checkbox.target = self
        checkbox.action = #selector(toggle)

        deleteButton.frame = NSRect(x: 234, y: 6, width: 50, height: 22)
        deleteButton.autoresizingMask = [.minXMargin]
        deleteButton.bezelStyle = .inline
        deleteButton.font = .systemFont(ofSize: 11)
        deleteButton.contentTintColor = .secondaryLabelColor
        deleteButton.target = self
        deleteButton.action = #selector(deleteItem)

        addSubview(checkbox)
        addSubview(deleteButton)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: TodoItem) {
        checkbox.title = item.title
        checkbox.state = item.isCompleted ? .on : .off
        checkbox.attributedTitle = NSAttributedString(
            string: item.title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: item.isCompleted
                    ? NSColor.tertiaryLabelColor
                    : NSColor.labelColor,
                .strikethroughStyle: item.isCompleted
                    ? NSUnderlineStyle.single.rawValue
                    : 0
            ]
        )
    }

    @objc private func toggle() {
        onToggle?()
    }

    @objc private func deleteItem() {
        onDelete?()
    }
}

final class ProductivityPanelController: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    private enum DefaultsKey {
        static let todos = "desktopCat.todos"
        static let timerPhase = "desktopCat.timer.phase"
        static let timerRemaining = "desktopCat.timer.remaining"
        static let timerEndDate = "desktopCat.timer.endDate"
        static let timerRunning = "desktopCat.timer.running"
    }

    let panel: NSPanel

    var onVisibilityChanged: ((Bool) -> Void)?
    var onTabChanged: ((ProductivityTab) -> Void)?
    var onTimerRunningChanged: ((Bool) -> Void)?
    var onTimerFinished: (() -> Void)?

    private let rootView = NSView()
    private let segmentedControl = NSSegmentedControl(
        labels: ["待办", "番茄钟"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let todoContainer = NSView()
    private let timerContainer = NSView()
    private let todoInput = NSTextField()
    private let tableView = NSTableView()
    private let timerPhaseLabel = NSTextField(labelWithString: "")
    private let timerValueLabel = NSTextField(labelWithString: "25:00")
    private let timerProgress = NSProgressIndicator()
    private let timerToggleButton = NSButton(title: "开始", target: nil, action: nil)

    private var todos: [TodoItem] = []
    private var selectedTab: ProductivityTab = .todo
    private var phase: PomodoroPhase = .focus
    private var remaining: TimeInterval = PomodoroPhase.focus.duration
    private var endDate: Date?
    private var isTimerRunning = false
    private var timer: Timer?

    var isVisible: Bool {
        panel.isVisible
    }

    init(size: NSSize = NSSize(width: 320, height: 410)) {
        panel = ProductivityPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        super.init()

        configurePanel(size: size)
        loadTodos()
        restoreTimer()
        updateTimerDisplay()
    }

    deinit {
        timer?.invalidate()
    }

    func toggle(tab: ProductivityTab, attachedTo petFrame: NSRect, on screen: NSRect) {
        if panel.isVisible, selectedTab == tab {
            close()
            return
        }

        selectedTab = tab
        segmentedControl.selectedSegment = tab.rawValue
        updateSelectedTab()
        position(attachedTo: petFrame, on: screen)
        panel.orderFrontRegardless()
        onVisibilityChanged?(true)
        onTabChanged?(tab)
    }

    func close() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        onVisibilityChanged?(false)
    }

    func position(attachedTo petFrame: NSRect, on screen: NSRect) {
        let spacing: CGFloat = 12
        let panelSize = panel.frame.size
        let fitsOnRight = petFrame.maxX + spacing + panelSize.width <= screen.maxX
        var origin = NSPoint(
            x: fitsOnRight
                ? petFrame.maxX + spacing
                : petFrame.minX - spacing - panelSize.width,
            y: petFrame.midY - panelSize.height / 2
        )

        origin.x = min(max(origin.x, screen.minX), screen.maxX - panelSize.width)
        origin.y = min(max(origin.y, screen.minY), screen.maxY - panelSize.height)
        panel.setFrameOrigin(origin)
    }

    private func configurePanel(size: NSSize) {
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        rootView.frame = NSRect(origin: .zero, size: size)
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.windowBackgroundColor
            .withAlphaComponent(0.96)
            .cgColor
        rootView.layer?.cornerRadius = 18
        rootView.layer?.borderWidth = 1
        rootView.layer?.borderColor = NSColor.separatorColor
            .withAlphaComponent(0.45)
            .cgColor
        panel.contentView = rootView

        let title = NSTextField(labelWithString: "Julie 的小助手")
        title.frame = NSRect(x: 18, y: size.height - 39, width: 220, height: 24)
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        rootView.addSubview(title)

        let closeButton = NSButton(title: "×", target: self, action: #selector(closePressed))
        closeButton.frame = NSRect(x: size.width - 42, y: size.height - 43, width: 28, height: 28)
        closeButton.bezelStyle = .inline
        closeButton.font = .systemFont(ofSize: 18)
        rootView.addSubview(closeButton)

        segmentedControl.frame = NSRect(x: 16, y: size.height - 79, width: size.width - 32, height: 28)
        segmentedControl.target = self
        segmentedControl.action = #selector(tabChanged)
        segmentedControl.selectedSegment = ProductivityTab.todo.rawValue
        rootView.addSubview(segmentedControl)

        let contentFrame = NSRect(x: 16, y: 16, width: size.width - 32, height: size.height - 105)
        todoContainer.frame = contentFrame
        timerContainer.frame = contentFrame
        rootView.addSubview(todoContainer)
        rootView.addSubview(timerContainer)

        configureTodoView()
        configureTimerView()
        updateSelectedTab()
    }

    private func configureTodoView() {
        let width = todoContainer.bounds.width
        let height = todoContainer.bounds.height

        todoInput.frame = NSRect(x: 0, y: height - 34, width: width - 65, height: 28)
        todoInput.placeholderString = "添加一个待办事项"
        todoInput.delegate = self
        todoInput.target = self
        todoInput.action = #selector(addTodo)
        todoContainer.addSubview(todoInput)

        let addButton = NSButton(title: "添加", target: self, action: #selector(addTodo))
        addButton.frame = NSRect(x: width - 59, y: height - 35, width: 59, height: 30)
        addButton.bezelStyle = .rounded
        todoContainer.addSubview(addButton)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("todo"))
        column.width = width
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 34
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        tableView.dataSource = self
        tableView.delegate = self

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 38, width: width, height: height - 82))
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        todoContainer.addSubview(scrollView)

        let clearButton = NSButton(
            title: "清除已完成",
            target: self,
            action: #selector(clearCompleted)
        )
        clearButton.frame = NSRect(x: width - 110, y: 2, width: 110, height: 28)
        clearButton.bezelStyle = .inline
        clearButton.contentTintColor = .secondaryLabelColor
        todoContainer.addSubview(clearButton)
    }

    private func configureTimerView() {
        let width = timerContainer.bounds.width
        let height = timerContainer.bounds.height

        timerPhaseLabel.frame = NSRect(x: 0, y: height - 45, width: width, height: 24)
        timerPhaseLabel.alignment = .center
        timerPhaseLabel.font = .systemFont(ofSize: 16, weight: .medium)
        timerContainer.addSubview(timerPhaseLabel)

        timerValueLabel.frame = NSRect(x: 0, y: height - 120, width: width, height: 64)
        timerValueLabel.alignment = .center
        timerValueLabel.font = .monospacedDigitSystemFont(ofSize: 48, weight: .semibold)
        timerContainer.addSubview(timerValueLabel)

        timerProgress.frame = NSRect(x: 20, y: height - 145, width: width - 40, height: 10)
        timerProgress.style = .bar
        timerProgress.minValue = 0
        timerProgress.maxValue = 1
        timerContainer.addSubview(timerProgress)

        timerToggleButton.frame = NSRect(x: 42, y: 72, width: 94, height: 36)
        timerToggleButton.bezelStyle = .rounded
        timerToggleButton.target = self
        timerToggleButton.action = #selector(toggleTimer)
        timerContainer.addSubview(timerToggleButton)

        let resetButton = NSButton(title: "重置", target: self, action: #selector(resetTimer))
        resetButton.frame = NSRect(x: width - 136, y: 72, width: 94, height: 36)
        resetButton.bezelStyle = .rounded
        timerContainer.addSubview(resetButton)

        let hint = NSTextField(labelWithString: "专注 25 分钟 · 休息 5 分钟")
        hint.frame = NSRect(x: 0, y: 28, width: width, height: 22)
        hint.alignment = .center
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: 12)
        timerContainer.addSubview(hint)
    }

    private func updateSelectedTab() {
        todoContainer.isHidden = selectedTab != .todo
        timerContainer.isHidden = selectedTab != .timer
    }

    @objc private func tabChanged() {
        selectedTab = ProductivityTab(rawValue: segmentedControl.selectedSegment) ?? .todo
        updateSelectedTab()
        onTabChanged?(selectedTab)
    }

    @objc private func closePressed() {
        close()
    }

    @objc private func addTodo() {
        let title = todoInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        todos.append(TodoItem(id: UUID(), title: title, isCompleted: false))
        todoInput.stringValue = ""
        saveTodos()
        tableView.reloadData()
    }

    @objc private func clearCompleted() {
        todos.removeAll(where: \.isCompleted)
        saveTodos()
        tableView.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        todos.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard todos.indices.contains(row) else { return nil }

        let cell = TodoCellView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 34))
        cell.configure(with: todos[row])
        cell.onToggle = { [weak self] in
            guard let self, self.todos.indices.contains(row) else { return }
            self.todos[row].isCompleted.toggle()
            self.saveTodos()
            self.tableView.reloadData()
        }
        cell.onDelete = { [weak self] in
            guard let self, self.todos.indices.contains(row) else { return }
            self.todos.remove(at: row)
            self.saveTodos()
            self.tableView.reloadData()
        }
        return cell
    }

    private func loadTodos() {
        guard
            let data = UserDefaults.standard.data(forKey: DefaultsKey.todos),
            let decoded = try? JSONDecoder().decode([TodoItem].self, from: data)
        else {
            todos = []
            return
        }
        todos = decoded
    }

    private func saveTodos() {
        guard let data = try? JSONEncoder().encode(todos) else { return }
        UserDefaults.standard.set(data, forKey: DefaultsKey.todos)
    }

    private func restoreTimer() {
        let defaults = UserDefaults.standard
        phase = PomodoroPhase(
            rawValue: defaults.string(forKey: DefaultsKey.timerPhase) ?? ""
        ) ?? .focus

        let savedRemaining = defaults.double(forKey: DefaultsKey.timerRemaining)
        remaining = savedRemaining > 0 ? savedRemaining : phase.duration
        isTimerRunning = defaults.bool(forKey: DefaultsKey.timerRunning)

        if isTimerRunning {
            let timestamp = defaults.double(forKey: DefaultsKey.timerEndDate)
            endDate = timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
            if let endDate, endDate > Date() {
                startTicking()
            } else {
                isTimerRunning = false
                remaining = phase.duration
                endDate = nil
            }
        }
        persistTimer()
    }

    @objc private func toggleTimer() {
        if isTimerRunning {
            pauseTimer()
        } else {
            startTimer()
        }
    }

    private func startTimer() {
        isTimerRunning = true
        endDate = Date().addingTimeInterval(remaining)
        startTicking()
        persistTimer()
        updateTimerDisplay()
        onTimerRunningChanged?(true)
    }

    private func pauseTimer() {
        if let endDate {
            remaining = max(0, endDate.timeIntervalSinceNow)
        }
        isTimerRunning = false
        endDate = nil
        timer?.invalidate()
        timer = nil
        persistTimer()
        updateTimerDisplay()
        onTimerRunningChanged?(false)
    }

    @objc private func resetTimer() {
        isTimerRunning = false
        endDate = nil
        remaining = phase.duration
        timer?.invalidate()
        timer = nil
        persistTimer()
        updateTimerDisplay()
        onTimerRunningChanged?(false)
    }

    private func startTicking() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: 0.25,
            target: self,
            selector: #selector(timerTick),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer!, forMode: .common)
    }

    @objc private func timerTick() {
        guard isTimerRunning, let endDate else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)

        if remaining <= 0 {
            completeTimerPhase()
        } else {
            updateTimerDisplay()
        }
    }

    private func completeTimerPhase() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        endDate = nil
        phase = phase == .focus ? .breakTime : .focus
        remaining = phase.duration
        NSSound.beep()
        persistTimer()
        updateTimerDisplay()
        onTimerRunningChanged?(false)
        onTimerFinished?()
    }

    private func updateTimerDisplay() {
        let seconds = max(0, Int(ceil(remaining)))
        timerPhaseLabel.stringValue = phase.title
        timerValueLabel.stringValue = String(format: "%02d:%02d", seconds / 60, seconds % 60)
        timerToggleButton.title = isTimerRunning ? "暂停" : "开始"
        timerProgress.doubleValue = 1 - (remaining / phase.duration)
    }

    private func persistTimer() {
        let defaults = UserDefaults.standard
        defaults.set(phase.rawValue, forKey: DefaultsKey.timerPhase)
        defaults.set(remaining, forKey: DefaultsKey.timerRemaining)
        defaults.set(endDate?.timeIntervalSince1970 ?? 0, forKey: DefaultsKey.timerEndDate)
        defaults.set(isTimerRunning, forKey: DefaultsKey.timerRunning)
    }
}
