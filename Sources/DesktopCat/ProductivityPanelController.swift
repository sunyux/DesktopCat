import AppKit

enum ProductivityTab: Int {
    case todo = 0
    case timer = 1
}

private struct TodoItem: Codable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var folderID: UUID?
}

private struct TodoFolder: Codable {
    let id: UUID
    var name: String
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
        case .focus: return L10n.text("专注时间", "Focus")
        case .breakTime: return L10n.text("休息时间", "Break")
        }
    }
}

private final class ProductivityPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class TodoCellView: NSTableCellView {
    private let checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let deleteButton = NSButton(
        title: L10n.text("删除", "Delete"),
        target: nil,
        action: nil
    )

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
        static let todoFolders = "desktopCat.todoFolders"
        static let timerPhase = "desktopCat.timer.phase"
        static let timerRemaining = "desktopCat.timer.remaining"
        static let timerEndDate = "desktopCat.timer.endDate"
        static let timerRunning = "desktopCat.timer.running"
        static let focusMinutes = "desktopCat.timer.focusMinutes"
        static let breakMinutes = "desktopCat.timer.breakMinutes"
    }

    let panel: NSPanel

    var onVisibilityChanged: ((Bool) -> Void)?
    var onTabChanged: ((ProductivityTab) -> Void)?
    var onTimerRunningChanged: ((Bool) -> Void)?
    var onTimerFinished: (() -> Void)?

    private let rootView = NSView()
    private let segmentedControl = NSSegmentedControl(
        labels: [
            L10n.text("待办", "To-do"),
            L10n.text("番茄钟", "Pomodoro")
        ],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let todoContainer = NSView()
    private let timerContainer = NSView()
    private let folderPopup = NSPopUpButton()
    private let todoInput = NSTextField()
    private let tableView = NSTableView()
    private let timerPhaseLabel = NSTextField(labelWithString: "")
    private let timerValueLabel = NSTextField(labelWithString: "25:00")
    private let timerProgress = NSProgressIndicator()
    private let timerToggleButton = NSButton(
        title: L10n.text("开始", "Start"),
        target: nil,
        action: nil
    )
    private let focusMinutesField = NSTextField()
    private let breakMinutesField = NSTextField()

    private var todos: [TodoItem] = []
    private var folders: [TodoFolder] = []
    private var selectedFolderID: UUID?
    private var selectedTab: ProductivityTab = .todo
    private var phase: PomodoroPhase = .focus
    private var remaining: TimeInterval = PomodoroPhase.focus.duration
    private var endDate: Date?
    private var isTimerRunning = false
    private var timer: Timer?
    private var focusMinutes = 25
    private var breakMinutes = 5

    var isVisible: Bool {
        panel.isVisible
    }

    init(size: NSSize = NSSize(width: 340, height: 460)) {
        panel = ProductivityPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        super.init()

        configurePanel(size: size)
        loadFolders()
        loadTodos()
        refreshFolderPopup()
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

        let title = NSTextField(
            labelWithString: L10n.text("Julie 的小助手", "Julie's Assistant")
        )
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

        folderPopup.frame = NSRect(x: 0, y: height - 32, width: width - 76, height: 28)
        folderPopup.target = self
        folderPopup.action = #selector(folderChanged)
        todoContainer.addSubview(folderPopup)

        let addFolderButton = NSButton(title: "+", target: self, action: #selector(addFolder))
        addFolderButton.frame = NSRect(x: width - 72, y: height - 33, width: 34, height: 30)
        addFolderButton.bezelStyle = .rounded
        addFolderButton.toolTip = L10n.text("添加文件夹", "Add folder")
        todoContainer.addSubview(addFolderButton)

        let deleteFolderButton = NSButton(title: "−", target: self, action: #selector(deleteFolder))
        deleteFolderButton.frame = NSRect(x: width - 36, y: height - 33, width: 34, height: 30)
        deleteFolderButton.bezelStyle = .rounded
        deleteFolderButton.toolTip = L10n.text("删除当前文件夹", "Delete current folder")
        todoContainer.addSubview(deleteFolderButton)

        todoInput.frame = NSRect(x: 0, y: height - 70, width: width - 65, height: 28)
        todoInput.placeholderString = L10n.text("添加一个待办事项", "Add a task")
        todoInput.delegate = self
        todoInput.target = self
        todoInput.action = #selector(addTodo)
        todoContainer.addSubview(todoInput)

        let addButton = NSButton(
            title: L10n.text("添加", "Add"),
            target: self,
            action: #selector(addTodo)
        )
        addButton.frame = NSRect(x: width - 59, y: height - 71, width: 59, height: 30)
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

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 38, width: width, height: height - 118))
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        todoContainer.addSubview(scrollView)

        let clearButton = NSButton(
            title: L10n.text("清除已完成", "Clear completed"),
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

        timerToggleButton.frame = NSRect(x: 52, y: 132, width: 94, height: 36)
        timerToggleButton.bezelStyle = .rounded
        timerToggleButton.target = self
        timerToggleButton.action = #selector(toggleTimer)
        timerContainer.addSubview(timerToggleButton)

        let resetButton = NSButton(
            title: L10n.text("重置", "Reset"),
            target: self,
            action: #selector(resetTimer)
        )
        resetButton.frame = NSRect(x: width - 146, y: 132, width: 94, height: 36)
        resetButton.bezelStyle = .rounded
        timerContainer.addSubview(resetButton)

        let durationTitle = NSTextField(
            labelWithString: L10n.text("自定义分钟数", "Custom minutes")
        )
        durationTitle.frame = NSRect(x: 0, y: 94, width: width, height: 22)
        durationTitle.alignment = .center
        durationTitle.textColor = .secondaryLabelColor
        durationTitle.font = .systemFont(ofSize: 12)
        timerContainer.addSubview(durationTitle)

        let focusLabel = NSTextField(labelWithString: L10n.text("专注", "Focus"))
        focusLabel.frame = NSRect(x: 18, y: 54, width: 46, height: 24)
        timerContainer.addSubview(focusLabel)

        focusMinutesField.frame = NSRect(x: 66, y: 52, width: 54, height: 26)
        focusMinutesField.alignment = .right
        focusMinutesField.formatter = minuteFormatter(maximum: 180)
        timerContainer.addSubview(focusMinutesField)

        let breakLabel = NSTextField(labelWithString: L10n.text("休息", "Break"))
        breakLabel.frame = NSRect(x: 138, y: 54, width: 46, height: 24)
        timerContainer.addSubview(breakLabel)

        breakMinutesField.frame = NSRect(x: 186, y: 52, width: 54, height: 26)
        breakMinutesField.alignment = .right
        breakMinutesField.formatter = minuteFormatter(maximum: 60)
        timerContainer.addSubview(breakMinutesField)

        let saveButton = NSButton(
            title: L10n.text("保存", "Save"),
            target: self,
            action: #selector(saveTimerDurations)
        )
        saveButton.frame = NSRect(x: width - 70, y: 50, width: 68, height: 30)
        saveButton.bezelStyle = .rounded
        timerContainer.addSubview(saveButton)
    }

    private func minuteFormatter(maximum: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 1
        formatter.maximum = NSNumber(value: maximum)
        formatter.allowsFloats = false
        return formatter
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

    private var visibleTodos: [TodoItem] {
        guard let selectedFolderID else { return todos }
        return todos.filter { $0.folderID == selectedFolderID }
    }

    @objc private func folderChanged() {
        let index = folderPopup.indexOfSelectedItem
        selectedFolderID = index <= 0 ? nil : folders[index - 1].id
        tableView.reloadData()
    }

    @objc private func addFolder() {
        let alert = NSAlert()
        alert.messageText = L10n.text("新建文件夹", "New folder")
        alert.informativeText = L10n.text("输入文件夹名称。", "Enter a folder name.")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        input.placeholderString = L10n.text("例如：工作", "For example: Work")
        alert.accessoryView = input
        alert.addButton(withTitle: L10n.text("创建", "Create"))
        alert.addButton(withTitle: L10n.text("取消", "Cancel"))

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let folder = TodoFolder(id: UUID(), name: name)
        folders.append(folder)
        selectedFolderID = folder.id
        saveFolders()
        refreshFolderPopup()
        tableView.reloadData()
    }

    @objc private func deleteFolder() {
        guard
            let selectedFolderID,
            let folder = folders.first(where: { $0.id == selectedFolderID })
        else {
            NSSound.beep()
            return
        }

        let alert = NSAlert()
        alert.messageText = L10n.text(
            "删除“\(folder.name)”？",
            "Delete “\(folder.name)”?"
        )
        alert.informativeText = L10n.text(
            "文件夹中的任务会移到收件箱。",
            "Tasks in this folder will move to Inbox."
        )
        alert.addButton(withTitle: L10n.text("删除", "Delete"))
        alert.addButton(withTitle: L10n.text("取消", "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let inbox = folders.first(where: { $0.id != selectedFolderID })
        for index in todos.indices where todos[index].folderID == selectedFolderID {
            todos[index].folderID = inbox?.id
        }
        folders.removeAll(where: { $0.id == selectedFolderID })
        if folders.isEmpty {
            folders = [
                TodoFolder(id: UUID(), name: L10n.text("收件箱", "Inbox"))
            ]
        }
        self.selectedFolderID = nil
        saveFolders()
        saveTodos()
        refreshFolderPopup()
        tableView.reloadData()
    }

    @objc private func addTodo() {
        let title = todoInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let folderID = selectedFolderID ?? folders.first?.id
        todos.append(
            TodoItem(
                id: UUID(),
                title: title,
                isCompleted: false,
                folderID: folderID
            )
        )
        todoInput.stringValue = ""
        saveTodos()
        tableView.reloadData()
    }

    @objc private func clearCompleted() {
        if let selectedFolderID {
            todos.removeAll {
                $0.folderID == selectedFolderID && $0.isCompleted
            }
        } else {
            todos.removeAll(where: \.isCompleted)
        }
        saveTodos()
        tableView.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        visibleTodos.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let displayedTodos = visibleTodos
        guard displayedTodos.indices.contains(row) else { return nil }
        let item = displayedTodos[row]

        let cell = TodoCellView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 34))
        cell.configure(with: item)
        cell.onToggle = { [weak self] in
            guard
                let self,
                let index = self.todos.firstIndex(where: { $0.id == item.id })
            else { return }
            self.todos[index].isCompleted.toggle()
            self.saveTodos()
            self.tableView.reloadData()
        }
        cell.onDelete = { [weak self] in
            guard let self else { return }
            self.todos.removeAll(where: { $0.id == item.id })
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
        if let inboxID = folders.first?.id {
            for index in todos.indices where todos[index].folderID == nil {
                todos[index].folderID = inboxID
            }
            saveTodos()
        }
    }

    private func saveTodos() {
        guard let data = try? JSONEncoder().encode(todos) else { return }
        UserDefaults.standard.set(data, forKey: DefaultsKey.todos)
    }

    private func loadFolders() {
        if
            let data = UserDefaults.standard.data(forKey: DefaultsKey.todoFolders),
            let decoded = try? JSONDecoder().decode([TodoFolder].self, from: data),
            !decoded.isEmpty
        {
            folders = decoded
        } else {
            folders = [
                TodoFolder(id: UUID(), name: L10n.text("收件箱", "Inbox"))
            ]
            saveFolders()
        }
    }

    private func saveFolders() {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        UserDefaults.standard.set(data, forKey: DefaultsKey.todoFolders)
    }

    private func refreshFolderPopup() {
        folderPopup.removeAllItems()
        folderPopup.addItem(withTitle: L10n.text("全部任务", "All tasks"))
        folders.forEach { folderPopup.addItem(withTitle: $0.name) }

        if
            let selectedFolderID,
            let index = folders.firstIndex(where: { $0.id == selectedFolderID })
        {
            folderPopup.selectItem(at: index + 1)
        } else {
            folderPopup.selectItem(at: 0)
        }
    }

    private var phaseDuration: TimeInterval {
        TimeInterval(
            (phase == .focus ? focusMinutes : breakMinutes) * 60
        )
    }

    private func restoreTimer() {
        let defaults = UserDefaults.standard
        let savedFocus = defaults.integer(forKey: DefaultsKey.focusMinutes)
        let savedBreak = defaults.integer(forKey: DefaultsKey.breakMinutes)
        focusMinutes = savedFocus > 0 ? min(savedFocus, 180) : 25
        breakMinutes = savedBreak > 0 ? min(savedBreak, 60) : 5
        phase = PomodoroPhase(
            rawValue: defaults.string(forKey: DefaultsKey.timerPhase) ?? ""
        ) ?? .focus

        let savedRemaining = defaults.double(forKey: DefaultsKey.timerRemaining)
        remaining = savedRemaining > 0 ? savedRemaining : phaseDuration
        isTimerRunning = defaults.bool(forKey: DefaultsKey.timerRunning)

        if isTimerRunning {
            let timestamp = defaults.double(forKey: DefaultsKey.timerEndDate)
            endDate = timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
            if let endDate, endDate > Date() {
                startTicking()
            } else {
                isTimerRunning = false
                remaining = phaseDuration
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
        remaining = phaseDuration
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
        remaining = phaseDuration
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
        timerToggleButton.title = isTimerRunning
            ? L10n.text("暂停", "Pause")
            : L10n.text("开始", "Start")
        timerProgress.doubleValue = 1 - (remaining / phaseDuration)
        focusMinutesField.integerValue = focusMinutes
        breakMinutesField.integerValue = breakMinutes
    }

    private func persistTimer() {
        let defaults = UserDefaults.standard
        defaults.set(focusMinutes, forKey: DefaultsKey.focusMinutes)
        defaults.set(breakMinutes, forKey: DefaultsKey.breakMinutes)
        defaults.set(phase.rawValue, forKey: DefaultsKey.timerPhase)
        defaults.set(remaining, forKey: DefaultsKey.timerRemaining)
        defaults.set(endDate?.timeIntervalSince1970 ?? 0, forKey: DefaultsKey.timerEndDate)
        defaults.set(isTimerRunning, forKey: DefaultsKey.timerRunning)
    }

    @objc private func saveTimerDurations() {
        let newFocus = min(max(focusMinutesField.integerValue, 1), 180)
        let newBreak = min(max(breakMinutesField.integerValue, 1), 60)
        focusMinutes = newFocus
        breakMinutes = newBreak

        isTimerRunning = false
        endDate = nil
        timer?.invalidate()
        timer = nil
        remaining = phaseDuration
        persistTimer()
        updateTimerDisplay()
        onTimerRunningChanged?(false)
    }
}
