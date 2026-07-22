import AppKit
import QuartzCore

private enum PetAnimation: String, CaseIterable {
    case idle
    case walkingLeft = "running-left"
    case walkingRight = "running-right"
    case waving
    case jumping
    case failed
    case waiting
    case working = "running"
    case review
    case belly
    case todoLoaf = "todo-loaf"
    case timerYawn = "timer-yawn"
}

private enum PetMode {
    case idle
    case walking
    case special
}

private final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class PetView: NSView {
    let imageView = NSImageView()
    var onSingleClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    var onSecondaryClick: ((NSPoint) -> Void)?
    var onDragBegan: (() -> Void)?
    var onDragged: ((NSPoint) -> Void)?
    var onDragEnded: (() -> Void)?
    var onResize: ((CGFloat) -> Void)?
    var onProductivityTab: ((ProductivityTab) -> Void)?

    private let todoButton = NSButton(title: "✓", target: nil, action: nil)
    private let timerButton = NSButton(title: "◷", target: nil, action: nil)
    private var trackingArea: NSTrackingArea?
    private var mouseDownLocation = NSPoint.zero
    private var windowOriginAtMouseDown = NSPoint.zero
    private var didDrag = false
    private var clickCount = 1
    private var toolsVisible = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        imageView.frame = bounds
        imageView.autoresizingMask = [.width, .height]
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true
        addSubview(imageView)

        configureToolButton(todoButton, title: "✓", action: #selector(showTodo))
        configureToolButton(timerButton, title: "◷", action: #selector(showTimer))
        updateToolButtonFrames()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func layout() {
        super.layout()
        updateToolButtonFrames()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if !todoButton.isHidden, todoButton.alphaValue > 0, todoButton.frame.contains(point) {
            return todoButton
        }
        if !timerButton.isHidden, timerButton.alphaValue > 0, timerButton.frame.contains(point) {
            return timerButton
        }
        return bounds.contains(point) ? self : nil
    }

    override func mouseEntered(with event: NSEvent) {
        setToolsVisible(true)
    }

    override func mouseExited(with event: NSEvent) {
        setToolsVisible(false)
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = NSEvent.mouseLocation
        windowOriginAtMouseDown = window?.frame.origin ?? .zero
        didDrag = false
        clickCount = event.clickCount
    }

    override func mouseDragged(with event: NSEvent) {
        let current = NSEvent.mouseLocation
        let delta = NSPoint(
            x: current.x - mouseDownLocation.x,
            y: current.y - mouseDownLocation.y
        )

        if !didDrag, hypot(delta.x, delta.y) >= 4 {
            didDrag = true
            onDragBegan?()
        }

        guard didDrag else { return }
        onDragged?(
            NSPoint(
                x: windowOriginAtMouseDown.x + delta.x,
                y: windowOriginAtMouseDown.y + delta.y
            )
        )
    }

    override func mouseUp(with event: NSEvent) {
        if didDrag {
            onDragEnded?()
        } else if clickCount >= 2 {
            onDoubleClick?()
        } else {
            onSingleClick?()
        }
    }

    override func scrollWheel(with event: NSEvent) {
        onResize?(event.scrollingDeltaY)
    }

    override func rightMouseDown(with event: NSEvent) {
        onSecondaryClick?(convert(event.locationInWindow, from: nil))
    }

    private func configureToolButton(_ button: NSButton, title: String, action: Selector) {
        button.title = title
        button.bezelStyle = .circular
        button.font = .systemFont(ofSize: 14, weight: .semibold)
        button.target = self
        button.action = action
        button.isHidden = true
        addSubview(button)
    }

    private func updateToolButtonFrames() {
        let buttonSize: CGFloat = max(26, min(34, bounds.width * 0.14))
        let y = bounds.height - buttonSize - 6
        todoButton.frame = NSRect(x: 7, y: y, width: buttonSize, height: buttonSize)
        timerButton.frame = NSRect(
            x: 12 + buttonSize,
            y: y,
            width: buttonSize,
            height: buttonSize
        )
    }

    private func setToolsVisible(_ visible: Bool) {
        toolsVisible = visible
        if visible {
            todoButton.isHidden = false
            timerButton.isHidden = false
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            todoButton.animator().alphaValue = visible ? 1 : 0
            timerButton.animator().alphaValue = visible ? 1 : 0
        } completionHandler: { [weak self] in
            guard let self, !self.toolsVisible else { return }
            self.todoButton.isHidden = true
            self.timerButton.isHidden = true
        }
    }

    @objc private func showTodo() {
        onProductivityTab?(.todo)
    }

    @objc private func showTimer() {
        onProductivityTab?(.timer)
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum DefaultsKey {
        static let petSize = "desktopCat.pet.size"
        static let petOriginX = "desktopCat.pet.originX"
        static let petOriginY = "desktopCat.pet.originY"
    }

    private let minimumPetSize: CGFloat = 140
    private let maximumPetSize: CGFloat = 360
    private let bottomPadding: CGFloat = 10
    private let movementSpeed: CGFloat = 0.9

    private var panel: PetPanel!
    private var petView: PetView!
    private var productivityController: ProductivityPanelController!
    private var statusItem: NSStatusItem!
    private var timer: Timer?

    private var mode: PetMode = .idle
    private var currentAnimation: PetAnimation?
    private var horizontalVelocity: CGFloat = 0
    private var modeEndsAt = Date()
    private var isPaused = false
    private var isDragging = false
    private var petDimension: CGFloat = 220

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        restorePetSize()
        createPanel()
        createProductivityPanel()
        createStatusItem()
        installScreenObservers()
        enterIdle(for: 10.0)

        timer = Timer.scheduledTimer(
            timeInterval: 1.0 / 30.0,
            target: self,
            selector: #selector(tick),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer!, forMode: .common)
    }

    func applicationWillTerminate(_ notification: Notification) {
        savePetLayout()
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    private func createPanel() {
        let screenFrame = activeScreenFrame()
        let petSize = NSSize(width: petDimension, height: petDimension)
        let origin = restoredPetOrigin(on: screenFrame, petSize: petSize)

        panel = PetPanel(
            contentRect: NSRect(origin: origin, size: petSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        petView = PetView(frame: NSRect(origin: .zero, size: petSize))
        petView.onSingleClick = { [weak self] in
            self?.productivityController.close()
            self?.playSpecial(.belly, duration: 2.8)
        }
        petView.onDoubleClick = { [weak self] in
            self?.productivityController.close()
            self?.playSpecial(.waving, duration: 1.5)
        }
        petView.onSecondaryClick = { [weak self] point in
            self?.showPetMenu(at: point)
        }
        petView.onDragBegan = { [weak self] in
            self?.isDragging = true
            self?.horizontalVelocity = 0
        }
        petView.onDragged = { [weak self] origin in
            self?.movePet(to: origin)
        }
        petView.onDragEnded = { [weak self] in
            self?.isDragging = false
            self?.savePetLayout()
            self?.enterIdle(for: 10.0)
        }
        petView.onResize = { [weak self] delta in
            self?.resizePet(by: delta)
        }
        petView.onProductivityTab = { [weak self] tab in
            self?.toggleProductivityPanel(tab)
        }
        panel.contentView = petView
        panel.orderFrontRegardless()
    }

    private func createProductivityPanel() {
        productivityController = ProductivityPanelController()
        productivityController.onVisibilityChanged = { [weak self] visible in
            guard let self else { return }
            if !visible {
                self.enterIdle(for: 10.0)
            }
        }
        productivityController.onTabChanged = { [weak self] tab in
            guard let self else { return }
            switch tab {
            case .todo:
                self.setAnimation(.todoLoaf)
            case .timer:
                self.setAnimation(.waiting)
            }
        }
        productivityController.onTimerRunningChanged = { [weak self] running in
            guard let self, self.productivityController.isVisible else { return }
            self.setAnimation(running ? .working : .waiting)
        }
        productivityController.onTimerFinished = { [weak self] in
            self?.setAnimation(.timerYawn)
        }
    }

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🐾 Julie"
        statusItem.menu = buildUserMenu()
    }

    private func buildUserMenu() -> NSMenu {
        let menu = NSMenu()

        let header = NSMenuItem(title: "Julie-LaoTai", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let interactionItem = NSMenuItem(title: "互动", action: nil, keyEquivalent: "")
        let interactionMenu = NSMenu(title: "互动")
        interactionMenu.addItem(menuItem("摸摸肚子", action: #selector(touchBelly)))
        interactionMenu.addItem(menuItem("招招手", action: #selector(wave)))
        interactionMenu.addItem(menuItem("现在休息", action: #selector(restNow)))
        interactionItem.submenu = interactionMenu
        menu.addItem(interactionItem)

        let toolsItem = NSMenuItem(title: "效率工具", action: nil, keyEquivalent: "")
        let toolsMenu = NSMenu(title: "效率工具")
        toolsMenu.addItem(menuItem("待办清单", action: #selector(openTodo)))
        toolsMenu.addItem(menuItem("番茄钟", action: #selector(openPomodoro)))
        toolsItem.submenu = toolsMenu
        menu.addItem(toolsItem)

        let sizeItem = NSMenuItem(title: "Julie 大小", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu(title: "Julie 大小")
        sizeMenu.addItem(sizeMenuItem("小", dimension: 160))
        sizeMenu.addItem(sizeMenuItem("中", dimension: 220))
        sizeMenu.addItem(sizeMenuItem("大", dimension: 300))
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        menu.addItem(menuItem(
            isPaused ? "继续走动" : "暂停走动",
            action: #selector(togglePause(_:))
        ))
        menu.addItem(menuItem("回到屏幕中央", action: #selector(resetPosition)))

        menu.addItem(.separator())
        menu.addItem(menuItem("使用说明", action: #selector(showUserGuide)))
        menu.addItem(menuItem("关于 DesktopCat", action: #selector(showAbout)))
        menu.addItem(.separator())
        menu.addItem(menuItem("退出 DesktopCat", action: #selector(quit), keyEquivalent: "q"))

        return menu
    }

    private func menuItem(
        _ title: String,
        action: Selector,
        keyEquivalent: String = ""
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private func sizeMenuItem(_ title: String, dimension: Int) -> NSMenuItem {
        let item = menuItem(title, action: #selector(selectPetSize(_:)))
        item.tag = dimension
        return item
    }

    private func installScreenObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func tick() {
        if productivityController.isVisible {
            positionProductivityPanel()
            return
        }

        guard !isPaused, !isDragging else { return }

        if mode == .walking {
            var frame = panel.frame
            frame.origin.x += horizontalVelocity

            let screen = activeScreenFrame()
            let minX = screen.minX
            let maxX = screen.maxX - frame.width
            let minY = screen.minY
            let maxY = screen.maxY - frame.height

            if frame.origin.x <= minX {
                frame.origin.x = minX
                horizontalVelocity = abs(movementSpeed)
                setAnimation(.walkingRight)
            } else if frame.origin.x >= maxX {
                frame.origin.x = maxX
                horizontalVelocity = -abs(movementSpeed)
                setAnimation(.walkingLeft)
            }

            frame.origin.y = min(max(frame.origin.y, minY), maxY)
            panel.setFrameOrigin(frame.origin)
        }

        guard Date() >= modeEndsAt else { return }

        switch mode {
        case .idle, .special:
            chooseNextAction()
        case .walking:
            enterIdle(for: Double.random(in: 14.0...28.0))
        }
    }

    private func chooseNextAction() {
        let roll = Int.random(in: 0..<100)

        switch roll {
        case 0..<20:
            startWalking()
        case 20..<27:
            playSpecial(.waiting, duration: 1.8)
        case 27..<34:
            playSpecial(.review, duration: 1.7)
        case 34..<40:
            playSpecial(.working, duration: 1.7)
        case 40..<44:
            playSpecial(.jumping, duration: 1.4)
        case 44..<48:
            playSpecial(.waving, duration: 1.5)
        default:
            enterIdle(for: Double.random(in: 12.0...30.0))
        }
    }

    private func startWalking() {
        let screen = activeScreenFrame()
        let panelMidX = panel.frame.midX
        let shouldMoveRight: Bool

        if panelMidX < screen.minX + screen.width * 0.25 {
            shouldMoveRight = true
        } else if panelMidX > screen.minX + screen.width * 0.75 {
            shouldMoveRight = false
        } else {
            shouldMoveRight = Bool.random()
        }

        mode = .walking
        horizontalVelocity = shouldMoveRight ? movementSpeed : -movementSpeed
        setAnimation(shouldMoveRight ? .walkingRight : .walkingLeft)
        modeEndsAt = Date().addingTimeInterval(Double.random(in: 5.0...12.0))
    }

    private func enterIdle(for duration: TimeInterval) {
        mode = .idle
        horizontalVelocity = 0
        setAnimation(.idle)
        modeEndsAt = Date().addingTimeInterval(duration)
    }

    private func playSpecial(_ animation: PetAnimation, duration: TimeInterval) {
        mode = .special
        horizontalVelocity = 0
        setAnimation(animation)
        modeEndsAt = Date().addingTimeInterval(duration)
    }

    private func setAnimation(_ animation: PetAnimation) {
        guard currentAnimation != animation else { return }
        currentAnimation = animation

        guard
            let resourceURL = Bundle.main.resourceURL,
            let image = NSImage(
                contentsOf: resourceURL
                    .appendingPathComponent("animations")
                    .appendingPathComponent("\(animation.rawValue).gif")
            )
        else {
            showMissingAssetAlert(animation)
            return
        }

        let transition = CATransition()
        transition.type = .fade
        transition.duration = 0.16
        petView.imageView.wantsLayer = true
        petView.imageView.layer?.add(transition, forKey: "petAnimationFade")
        petView.imageView.image = image
        petView.imageView.animates = true
    }

    private func toggleProductivityPanel(_ tab: ProductivityTab) {
        productivityController.toggle(
            tab: tab,
            attachedTo: panel.frame,
            on: activeScreenFrame()
        )

        if !productivityController.isVisible {
            enterIdle(for: 10.0)
        }
    }

    private func positionProductivityPanel() {
        productivityController.position(
            attachedTo: panel.frame,
            on: activeScreenFrame()
        )
    }

    private func movePet(to requestedOrigin: NSPoint) {
        let screen = activeScreenFrame()
        let frame = panel.frame
        let clamped = NSPoint(
            x: min(max(requestedOrigin.x, screen.minX), screen.maxX - frame.width),
            y: min(max(requestedOrigin.y, screen.minY), screen.maxY - frame.height)
        )
        panel.setFrameOrigin(clamped)
        positionProductivityPanel()
    }

    private func resizePet(by scrollDelta: CGFloat) {
        guard abs(scrollDelta) > 0.05 else { return }

        let newDimension = min(
            maximumPetSize,
            max(minimumPetSize, petDimension + scrollDelta * 2.2)
        )
        guard abs(newDimension - petDimension) >= 0.5 else { return }
        setPetSize(newDimension)
    }

    private func setPetSize(_ newDimension: CGFloat) {
        let oldFrame = panel.frame
        petDimension = newDimension
        var newFrame = NSRect(
            x: oldFrame.midX - newDimension / 2,
            y: oldFrame.midY - newDimension / 2,
            width: newDimension,
            height: newDimension
        )
        let screen = activeScreenFrame()
        newFrame.origin.x = min(max(newFrame.origin.x, screen.minX), screen.maxX - newDimension)
        newFrame.origin.y = min(max(newFrame.origin.y, screen.minY), screen.maxY - newDimension)

        panel.setFrame(newFrame, display: true)
        petView.frame = NSRect(origin: .zero, size: newFrame.size)
        positionProductivityPanel()
        savePetLayout()
    }

    private func restorePetSize() {
        let saved = UserDefaults.standard.double(forKey: DefaultsKey.petSize)
        if saved > 0 {
            petDimension = min(maximumPetSize, max(minimumPetSize, CGFloat(saved)))
        }
    }

    private func restoredPetOrigin(on screen: NSRect, petSize: NSSize) -> NSPoint {
        let defaults = UserDefaults.standard
        guard
            defaults.object(forKey: DefaultsKey.petOriginX) != nil,
            defaults.object(forKey: DefaultsKey.petOriginY) != nil
        else {
            return NSPoint(
                x: screen.midX - petSize.width / 2,
                y: screen.minY + bottomPadding
            )
        }

        return NSPoint(
            x: min(
                max(CGFloat(defaults.double(forKey: DefaultsKey.petOriginX)), screen.minX),
                screen.maxX - petSize.width
            ),
            y: min(
                max(CGFloat(defaults.double(forKey: DefaultsKey.petOriginY)), screen.minY),
                screen.maxY - petSize.height
            )
        )
    }

    private func savePetLayout() {
        guard panel != nil else { return }
        let defaults = UserDefaults.standard
        defaults.set(Double(petDimension), forKey: DefaultsKey.petSize)
        defaults.set(Double(panel.frame.origin.x), forKey: DefaultsKey.petOriginX)
        defaults.set(Double(panel.frame.origin.y), forKey: DefaultsKey.petOriginY)
    }

    private func activeScreenFrame() -> NSRect {
        panel?.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }

    private func showPetMenu(at point: NSPoint) {
        buildUserMenu().popUp(positioning: nil, at: point, in: petView)
    }

    private func showMissingAssetAlert(_ animation: PetAnimation) {
        let alert = NSAlert()
        alert.messageText = "找不到 Julie 的动画"
        alert.informativeText = "缺少 animations/\(animation.rawValue).gif"
        alert.alertStyle = .warning
        alert.runModal()
    }

    @objc private func togglePause(_ sender: NSMenuItem?) {
        isPaused.toggle()
        sender?.title = isPaused ? "继续走动" : "暂停走动"
        if isPaused {
            setAnimation(.idle)
        } else {
            enterIdle(for: 0.5)
        }
    }

    @objc private func touchBelly() {
        productivityController.close()
        playSpecial(.belly, duration: 2.8)
    }

    @objc private func wave() {
        productivityController.close()
        playSpecial(.waving, duration: 1.5)
    }

    @objc private func restNow() {
        productivityController.close()
        enterIdle(for: 30.0)
    }

    @objc private func openTodo() {
        toggleProductivityPanel(.todo)
    }

    @objc private func openPomodoro() {
        toggleProductivityPanel(.timer)
    }

    @objc private func selectPetSize(_ sender: NSMenuItem) {
        let dimension = min(
            maximumPetSize,
            max(minimumPetSize, CGFloat(sender.tag))
        )
        setPetSize(dimension)
    }

    @objc private func showUserGuide() {
        let alert = NSAlert()
        alert.messageText = "DesktopCat 使用说明"
        alert.informativeText = """
        拖动 Julie：移动位置
        滚动鼠标滚轮：缩放大小
        单击：摸摸肚子
        双击：招手
        悬停后的 ✓：待办清单
        悬停后的 ◷：番茄钟
        右键或菜单栏 🐾 Julie：打开完整用户菜单
        """
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "DesktopCat 1.1.1"
        alert.informativeText = "Julie-LaoTai 的原生 macOS 桌面宠物、待办清单和番茄钟。"
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    @objc private func resetPosition() {
        let screen = activeScreenFrame()
        panel.setFrameOrigin(
            NSPoint(
                x: screen.midX - petDimension / 2,
                y: screen.minY + bottomPadding
            )
        )
        savePetLayout()
        positionProductivityPanel()
        enterIdle(for: 1.0)
    }

    @objc private func screenConfigurationChanged() {
        movePet(to: panel.frame.origin)
        positionProductivityPanel()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let application = NSApplication.shared
private let delegate = AppDelegate()
application.delegate = delegate
application.run()
