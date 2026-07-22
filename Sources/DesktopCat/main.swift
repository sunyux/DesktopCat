import AppKit
import QuartzCore
import UniformTypeIdentifiers

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

private enum PetAppearanceMode: String {
    case julie
    case staticImage
    case animationPack
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
        static let appearanceMode = "desktopCat.pet.appearanceMode"
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
    private var appearanceMode: PetAppearanceMode = .julie

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        restoreAppearanceMode()
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
        statusItem.button?.title = "🐾 DesktopCat"
        statusItem.menu = buildUserMenu()
    }

    private func buildUserMenu() -> NSMenu {
        let menu = NSMenu()

        let header = NSMenuItem(title: "DesktopCat", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let interactionTitle = L10n.text("互动", "Interactions")
        let interactionItem = NSMenuItem(title: interactionTitle, action: nil, keyEquivalent: "")
        let interactionMenu = NSMenu(title: interactionTitle)
        interactionMenu.addItem(
            menuItem(L10n.text("摸摸肚子", "Belly rub"), action: #selector(touchBelly))
        )
        interactionMenu.addItem(
            menuItem(L10n.text("招招手", "Wave"), action: #selector(wave))
        )
        interactionMenu.addItem(
            menuItem(L10n.text("现在休息", "Rest now"), action: #selector(restNow))
        )
        interactionItem.submenu = interactionMenu
        menu.addItem(interactionItem)

        let toolsTitle = L10n.text("效率工具", "Productivity")
        let toolsItem = NSMenuItem(title: toolsTitle, action: nil, keyEquivalent: "")
        let toolsMenu = NSMenu(title: toolsTitle)
        toolsMenu.addItem(
            menuItem(L10n.text("待办清单", "To-do list"), action: #selector(openTodo))
        )
        toolsMenu.addItem(
            menuItem(L10n.text("番茄钟", "Pomodoro timer"), action: #selector(openPomodoro))
        )
        toolsItem.submenu = toolsMenu
        menu.addItem(toolsItem)

        let appearanceTitle = L10n.text("宠物外观", "Pet appearance")
        let appearanceItem = NSMenuItem(title: appearanceTitle, action: nil, keyEquivalent: "")
        let appearanceMenu = NSMenu(title: appearanceTitle)
        appearanceMenu.addItem(
            menuItem(
                L10n.text("选择单张图片…", "Choose a single image…"),
                action: #selector(chooseStaticPetImage)
            )
        )
        appearanceMenu.addItem(
            menuItem(
                L10n.text("导入动画包文件夹…", "Import animation-pack folder…"),
                action: #selector(importAnimationPack)
            )
        )
        appearanceMenu.addItem(.separator())
        appearanceMenu.addItem(
            menuItem(
                L10n.text("恢复 Julie", "Restore Julie"),
                action: #selector(restoreJulieAppearance)
            )
        )
        appearanceItem.submenu = appearanceMenu
        menu.addItem(appearanceItem)

        let sizeTitle = L10n.text("宠物大小", "Pet size")
        let sizeItem = NSMenuItem(title: sizeTitle, action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu(title: sizeTitle)
        sizeMenu.addItem(sizeMenuItem(L10n.text("小", "Small"), dimension: 160))
        sizeMenu.addItem(sizeMenuItem(L10n.text("中", "Medium"), dimension: 220))
        sizeMenu.addItem(sizeMenuItem(L10n.text("大", "Large"), dimension: 300))
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        menu.addItem(menuItem(
            isPaused
                ? L10n.text("继续走动", "Resume movement")
                : L10n.text("暂停走动", "Pause movement"),
            action: #selector(togglePause(_:))
        ))
        menu.addItem(
            menuItem(
                L10n.text("回到屏幕中央", "Move to screen center"),
                action: #selector(resetPosition)
            )
        )

        menu.addItem(.separator())
        menu.addItem(
            menuItem(L10n.text("使用说明", "User guide"), action: #selector(showUserGuide))
        )
        menu.addItem(
            menuItem(L10n.text("关于 DesktopCat", "About DesktopCat"), action: #selector(showAbout))
        )
        menu.addItem(.separator())
        menu.addItem(
            menuItem(
                L10n.text("退出 DesktopCat", "Quit DesktopCat"),
                action: #selector(quit),
                keyEquivalent: "q"
            )
        )

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
            let animationURL = animationURL(for: animation),
            let image = NSImage(contentsOf: animationURL)
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

    private var customPetDirectory: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return base
            .appendingPathComponent("DesktopCat", isDirectory: true)
            .appendingPathComponent("CustomPet", isDirectory: true)
    }

    private func animationURL(for animation: PetAnimation) -> URL? {
        let fileManager = FileManager.default

        switch appearanceMode {
        case .staticImage:
            if
                let files = try? fileManager.contentsOfDirectory(
                    at: customPetDirectory,
                    includingPropertiesForKeys: nil
                ),
                let image = files.first(where: { $0.lastPathComponent.hasPrefix("static-pet.") })
            {
                return image
            }
        case .animationPack:
            let customAnimation = customPetDirectory
                .appendingPathComponent("animations", isDirectory: true)
                .appendingPathComponent("\(animation.rawValue).gif")
            if fileManager.fileExists(atPath: customAnimation.path) {
                return customAnimation
            }
        case .julie:
            break
        }

        return Bundle.main.resourceURL?
            .appendingPathComponent("animations")
            .appendingPathComponent("\(animation.rawValue).gif")
    }

    private func restoreAppearanceMode() {
        appearanceMode = PetAppearanceMode(
            rawValue: UserDefaults.standard.string(forKey: DefaultsKey.appearanceMode) ?? ""
        ) ?? .julie
    }

    private func saveAppearanceMode() {
        UserDefaults.standard.set(
            appearanceMode.rawValue,
            forKey: DefaultsKey.appearanceMode
        )
    }

    private func reloadAppearance() {
        currentAnimation = nil
        enterIdle(for: 20.0)
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
        alert.messageText = L10n.text("找不到宠物动画", "Pet animation not found")
        alert.informativeText = L10n.text(
            "缺少 animations/\(animation.rawValue).gif",
            "Missing animations/\(animation.rawValue).gif"
        )
        alert.alertStyle = .warning
        alert.runModal()
    }

    @objc private func togglePause(_ sender: NSMenuItem?) {
        isPaused.toggle()
        sender?.title = isPaused
            ? L10n.text("继续走动", "Resume movement")
            : L10n.text("暂停走动", "Pause movement")
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

    @objc private func chooseStaticPetImage() {
        let picker = NSOpenPanel()
        picker.title = L10n.text("选择宠物图片", "Choose a pet image")
        picker.message = L10n.text(
            "推荐使用透明背景的 PNG 图片。",
            "A PNG with a transparent background works best."
        )
        picker.allowedContentTypes = [.png, .jpeg, .gif]
        picker.canChooseFiles = true
        picker.canChooseDirectories = false
        picker.allowsMultipleSelection = false

        guard picker.runModal() == .OK, let source = picker.url else { return }

        do {
            let fileManager = FileManager.default
            try fileManager.createDirectory(
                at: customPetDirectory,
                withIntermediateDirectories: true
            )

            if let files = try? fileManager.contentsOfDirectory(
                at: customPetDirectory,
                includingPropertiesForKeys: nil
            ) {
                for file in files where file.lastPathComponent.hasPrefix("static-pet.") {
                    try? fileManager.removeItem(at: file)
                }
            }

            let destination = customPetDirectory.appendingPathComponent(
                "static-pet.\(source.pathExtension.lowercased())"
            )
            try fileManager.copyItem(at: source, to: destination)
            appearanceMode = .staticImage
            saveAppearanceMode()
            reloadAppearance()
        } catch {
            showImportError(error.localizedDescription)
        }
    }

    @objc private func importAnimationPack() {
        let picker = NSOpenPanel()
        picker.title = L10n.text("选择动画包文件夹", "Choose an animation-pack folder")
        picker.message = L10n.text(
            "文件夹必须包含 DesktopCat 的全部 GIF 动画文件。",
            "The folder must contain every DesktopCat GIF animation."
        )
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.allowsMultipleSelection = false

        guard picker.runModal() == .OK, let sourceFolder = picker.url else { return }

        let requiredFiles = PetAnimation.allCases.map { "\($0.rawValue).gif" }
        let missing = requiredFiles.filter {
            !FileManager.default.fileExists(
                atPath: sourceFolder.appendingPathComponent($0).path
            )
        }

        guard missing.isEmpty else {
            showImportError(
                L10n.text(
                    "缺少文件：\(missing.joined(separator: ", "))",
                    "Missing files: \(missing.joined(separator: ", "))"
                )
            )
            return
        }

        do {
            let fileManager = FileManager.default
            try fileManager.createDirectory(
                at: customPetDirectory,
                withIntermediateDirectories: true
            )
            let destination = customPetDirectory.appendingPathComponent(
                "animations",
                isDirectory: true
            )
            try? fileManager.removeItem(at: destination)
            try fileManager.copyItem(at: sourceFolder, to: destination)
            appearanceMode = .animationPack
            saveAppearanceMode()
            reloadAppearance()
        } catch {
            showImportError(error.localizedDescription)
        }
    }

    @objc private func restoreJulieAppearance() {
        appearanceMode = .julie
        saveAppearanceMode()
        reloadAppearance()
    }

    private func showImportError(_ details: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.text("无法导入宠物", "Could not import pet")
        alert.informativeText = details
        alert.addButton(withTitle: L10n.text("好", "OK"))
        alert.runModal()
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
        alert.messageText = L10n.text("DesktopCat 使用说明", "DesktopCat User Guide")
        alert.informativeText = L10n.text(
            """
            拖动宠物：移动位置
            滚动鼠标滚轮：缩放大小
            单击：摸摸肚子
            双击：招手
            悬停后的 ✓：待办清单
            悬停后的 ◷：番茄钟
            右键或菜单栏 🐾：打开完整用户菜单
            """,
            """
            Drag the pet: move it
            Scroll over the pet: resize it
            Single-click: belly rub
            Double-click: wave
            Hover ✓: To-do list
            Hover ◷: Pomodoro timer
            Right-click or menu-bar 🐾: full user menu
            """
        )
        alert.addButton(withTitle: L10n.text("知道了", "Got it"))
        alert.runModal()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "DesktopCat 1.3.0"
        alert.informativeText = L10n.text(
            "原生 macOS 桌面宠物、待办清单和番茄钟。",
            "A native macOS desktop pet with a to-do list and Pomodoro timer."
        )
        alert.addButton(withTitle: L10n.text("好", "OK"))
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
