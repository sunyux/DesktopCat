import AppKit

private struct CompanionPetProfile: Codable {
    let id: UUID
    var name: String
    var imageFileName: String
    var originX: Double
    var originY: Double
    var size: Double
}

private final class CompanionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class CompanionPetView: NSView {
    let imageView = NSImageView()
    var onDragged: ((NSPoint) -> Void)?
    var onDragEnded: (() -> Void)?
    var onResize: ((CGFloat) -> Void)?
    var onRemove: (() -> Void)?

    private var mouseDownLocation = NSPoint.zero
    private var windowOriginAtMouseDown = NSPoint.zero
    private var didDrag = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        imageView.frame = bounds
        imageView.autoresizingMask = [.width, .height]
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true
        addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = NSEvent.mouseLocation
        windowOriginAtMouseDown = window?.frame.origin ?? .zero
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        let current = NSEvent.mouseLocation
        let delta = NSPoint(
            x: current.x - mouseDownLocation.x,
            y: current.y - mouseDownLocation.y
        )
        didDrag = didDrag || hypot(delta.x, delta.y) >= 4
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
        }
    }

    override func scrollWheel(with event: NSEvent) {
        onResize?(event.scrollingDeltaY)
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let remove = NSMenuItem(
            title: L10n.text("移除这只宠物", "Remove this pet"),
            action: #selector(removePet),
            keyEquivalent: ""
        )
        remove.target = self
        menu.addItem(remove)
        menu.popUp(
            positioning: nil,
            at: convert(event.locationInWindow, from: nil),
            in: self
        )
    }

    @objc private func removePet() {
        onRemove?()
    }
}

private final class CompanionPetController: NSObject {
    private let minimumSize: CGFloat = 100
    private let maximumSize: CGFloat = 320
    private let movementSpeed: CGFloat = 0.45

    private(set) var profile: CompanionPetProfile
    private let imageURL: URL
    private let panel: CompanionPanel
    private let petView: CompanionPetView
    private var timer: Timer?
    private var horizontalVelocity: CGFloat = 0
    private var walkingUntil = Date.distantPast
    private var nextWalkAt = Date().addingTimeInterval(Double.random(in: 20...60))

    var onProfileChanged: ((CompanionPetProfile) -> Void)?
    var onRemove: (() -> Void)?

    init(profile: CompanionPetProfile, imageURL: URL) {
        self.profile = profile
        self.imageURL = imageURL

        let size = CGFloat(profile.size)
        panel = CompanionPanel(
            contentRect: NSRect(
                x: profile.originX,
                y: profile.originY,
                width: size,
                height: size
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        petView = CompanionPetView(
            frame: NSRect(x: 0, y: 0, width: size, height: size)
        )

        super.init()
        configure()
    }

    deinit {
        timer?.invalidate()
    }

    func close() {
        timer?.invalidate()
        panel.orderOut(nil)
    }

    private func configure() {
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        petView.imageView.image = NSImage(contentsOf: imageURL)
        petView.onDragged = { [weak self] origin in
            self?.move(to: origin)
        }
        petView.onDragEnded = { [weak self] in
            self?.saveFrame()
        }
        petView.onResize = { [weak self] delta in
            self?.resize(by: delta)
        }
        petView.onRemove = { [weak self] in
            self?.onRemove?()
        }

        panel.contentView = petView
        panel.orderFrontRegardless()

        timer = Timer.scheduledTimer(
            timeInterval: 1.0 / 30.0,
            target: self,
            selector: #selector(tick),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer!, forMode: .common)
    }

    @objc private func tick() {
        let now = Date()
        if now < walkingUntil {
            var frame = panel.frame
            frame.origin.x += horizontalVelocity
            let screen = panel.screen?.visibleFrame
                ?? NSScreen.main?.visibleFrame
                ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

            if frame.minX <= screen.minX {
                frame.origin.x = screen.minX
                horizontalVelocity = abs(movementSpeed)
            } else if frame.maxX >= screen.maxX {
                frame.origin.x = screen.maxX - frame.width
                horizontalVelocity = -abs(movementSpeed)
            }
            panel.setFrameOrigin(frame.origin)
        } else if now >= nextWalkAt {
            horizontalVelocity = Bool.random() ? movementSpeed : -movementSpeed
            walkingUntil = now.addingTimeInterval(Double.random(in: 4...9))
            nextWalkAt = walkingUntil.addingTimeInterval(Double.random(in: 25...70))
        }
    }

    private func move(to requestedOrigin: NSPoint) {
        let screen = panel.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = panel.frame
        let origin = NSPoint(
            x: min(max(requestedOrigin.x, screen.minX), screen.maxX - frame.width),
            y: min(max(requestedOrigin.y, screen.minY), screen.maxY - frame.height)
        )
        panel.setFrameOrigin(origin)
        walkingUntil = .distantPast
        nextWalkAt = Date().addingTimeInterval(Double.random(in: 25...70))
    }

    private func resize(by delta: CGFloat) {
        guard abs(delta) > 0.05 else { return }
        let oldFrame = panel.frame
        let size = min(
            maximumSize,
            max(minimumSize, oldFrame.width + delta * 2)
        )
        var frame = NSRect(
            x: oldFrame.midX - size / 2,
            y: oldFrame.midY - size / 2,
            width: size,
            height: size
        )
        let screen = panel.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        frame.origin.x = min(max(frame.origin.x, screen.minX), screen.maxX - size)
        frame.origin.y = min(max(frame.origin.y, screen.minY), screen.maxY - size)
        panel.setFrame(frame, display: true)
        petView.frame = NSRect(origin: .zero, size: frame.size)
        saveFrame()
    }

    private func saveFrame() {
        profile.originX = panel.frame.origin.x
        profile.originY = panel.frame.origin.y
        profile.size = panel.frame.width
        onProfileChanged?(profile)
    }
}

final class CompanionPetManager {
    private enum DefaultsKey {
        static let profiles = "desktopCat.companionPets"
    }

    private var profiles: [CompanionPetProfile] = []
    private var controllers: [UUID: CompanionPetController] = [:]

    var count: Int { profiles.count }

    init() {
        loadProfiles()
        restoreControllers()
    }

    func addPet(name: String, sourceImage: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: companionsDirectory,
            withIntermediateDirectories: true
        )

        let id = UUID()
        let fileName = "\(id.uuidString).\(sourceImage.pathExtension.lowercased())"
        let destination = companionsDirectory.appendingPathComponent(fileName)
        try fileManager.copyItem(at: sourceImage, to: destination)

        let screen = NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let offset = CGFloat(profiles.count % 5) * 35
        let profile = CompanionPetProfile(
            id: id,
            name: name,
            imageFileName: fileName,
            originX: screen.midX - 90 + offset,
            originY: screen.minY + 40 + offset,
            size: 180
        )
        profiles.append(profile)
        saveProfiles()
        createController(for: profile)
    }

    func removeAll() {
        controllers.values.forEach { $0.close() }
        controllers.removeAll()
        profiles.removeAll()
        saveProfiles()
        try? FileManager.default.removeItem(at: companionsDirectory)
    }

    private var companionsDirectory: URL {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent("DesktopCat", isDirectory: true)
        .appendingPathComponent("Companions", isDirectory: true)
    }

    private func loadProfiles() {
        guard
            let data = UserDefaults.standard.data(forKey: DefaultsKey.profiles),
            let decoded = try? JSONDecoder().decode(
                [CompanionPetProfile].self,
                from: data
            )
        else {
            return
        }
        profiles = decoded
    }

    private func saveProfiles() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(data, forKey: DefaultsKey.profiles)
        UserDefaults.standard.synchronize()
    }

    private func restoreControllers() {
        let fileManager = FileManager.default
        profiles = profiles.filter {
            fileManager.fileExists(
                atPath: companionsDirectory
                    .appendingPathComponent($0.imageFileName)
                    .path
            )
        }
        saveProfiles()
        profiles.forEach(createController)
    }

    private func createController(for profile: CompanionPetProfile) {
        let controller = CompanionPetController(
            profile: profile,
            imageURL: companionsDirectory.appendingPathComponent(
                profile.imageFileName
            )
        )
        controller.onProfileChanged = { [weak self] updated in
            guard
                let self,
                let index = self.profiles.firstIndex(where: { $0.id == updated.id })
            else { return }
            self.profiles[index] = updated
            self.saveProfiles()
        }
        controller.onRemove = { [weak self] in
            self?.removePet(id: profile.id)
        }
        controllers[profile.id] = controller
    }

    private func removePet(id: UUID) {
        controllers[id]?.close()
        controllers[id] = nil
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        let profile = profiles.remove(at: index)
        try? FileManager.default.removeItem(
            at: companionsDirectory.appendingPathComponent(
                profile.imageFileName
            )
        )
        saveProfiles()
    }
}
