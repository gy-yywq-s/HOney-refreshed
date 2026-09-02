// Visual evidence (fidelity spec v2 §18): the same contract fixtures the Web
// pins, rendered through the real app shell at 390 × 844 in the required
// theme combinations, written as PNGs for the parity board when
// HONEY_SNAPSHOT_DIR is set (the CI lane publishes them). Alongside: the
// font is really bundled, the appearance choices persist, and no uppercase
// transform hides in the sources.

import XCTest
import SwiftUI
import HOneyCore
@testable import HOneyNative

// MARK: - Fixture transport

/// Answers the HOney API from `packages/shared/fixtures/api/*.json`, moving
/// the lesson times so "now" and "in 1 h 4 min" hold at test time.
final class FixtureTransport: HTTPTransport, @unchecked Sendable {
    enum LessonState { case now, upcoming, none }
    var lessonState: LessonState = .now

    static let repoRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        return url
    }()

    static func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: repoRoot.appendingPathComponent("packages/shared/fixtures/api/\(name).json"))
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let path = request.url.path
        let name: String?
        switch path {
        case "/api/me": name = "me"
        case "/api/next-lesson":
            switch lessonState {
            case .now: name = "next-lesson-now"
            case .upcoming: name = "next-lesson-upcoming"
            case .none: name = "next-lesson-none"
            }
        case "/api/timetable": name = "timetable-day"
        case "/api/timetable/range": name = "timetable-range"
        case "/api/history": name = "history"
        case "/api/directory": name = "directory"
        case "/api/entities": name = "entities"
        case "/api/experiences/feed": name = "feed-page"
        case "/api/experiences/feed/updates": name = "feed-updates"
        case "/api/experiences/from-my-classes": name = "from-my-classes"
        case "/api/experiences/search": name = "search"
        case "/api/experiences/stats": name = "stats"
        case "/api/experiences/mine": name = "mine"
        case "/api/portal/entry": name = "portal-entry-ok"
        default: name = nil
        }
        guard let name else {
            return HTTPResponse(status: 404, headers: ["Content-Type": "application/json"], body: (try? Self.fixture("error")) ?? Data())
        }
        var data = try Self.fixture(name)
        if name.hasPrefix("next-lesson") { data = Self.shiftNextLesson(data) }
        if name == "timetable-day" { data = Self.retimeDay(data) }
        if name == "timetable-range" { data = Self.retimeWeek(data) }
        return HTTPResponse(status: 200, headers: ["Content-Type": "application/json"], body: data)
    }

    /// The running lesson sits at 50 %; the upcoming one starts in 1 h 4 min.
    private static func shiftNextLesson(_ data: Data) -> Data {
        guard var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var lesson = json["nextLesson"] as? [String: Any],
              let starts = lesson["startsAt"] as? Double, let ends = lesson["endsAt"] as? Double else { return data }
        let now = Date().timeIntervalSince1970 * 1000
        let length = ends - starts
        if lesson["temporalState"] as? String == "now" {
            lesson["startsAt"] = now - length / 2
            lesson["endsAt"] = now + length / 2
        } else {
            lesson["startsAt"] = now + 64 * 60_000
            lesson["endsAt"] = now + 64 * 60_000 + length
            lesson["minutesUntilStart"] = 64
        }
        json["nextLesson"] = lesson
        return (try? JSONSerialization.data(withJSONObject: json)) ?? data
    }

    /// Today's date with the fixture's wall times, so the Day view is "today".
    private static func retimeDay(_ data: Data) -> Data {
        guard var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lessons = json["lessons"] as? [[String: Any]], let date = json["date"] as? String else { return data }
        let today = Formatters.todayIsoDate()
        json["date"] = today
        json["lessons"] = lessons.map { retime($0, from: date, to: today) }
        return (try? JSONSerialization.data(withJSONObject: json)) ?? data
    }

    private static func retimeWeek(_ data: Data) -> Data {
        guard var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let days = json["days"] as? [[String: Any]], let from = json["from"] as? String else { return data }
        // Move the fixture week onto the current week, day for day.
        let monday = Formatters.mondayOf(Formatters.todayIsoDate())
        let offset = daysBetween(from, monday)
        json["from"] = monday
        json["to"] = Formatters.shiftIsoDate(monday, days: 6)
        json["days"] = days.map { day -> [String: Any] in
            var d = day
            let date = day["date"] as? String ?? from
            let target = Formatters.shiftIsoDate(date, days: offset)
            d["date"] = target
            d["lessons"] = (day["lessons"] as? [[String: Any]] ?? []).map { retime($0, from: date, to: target) }
            return d
        }
        return (try? JSONSerialization.data(withJSONObject: json)) ?? data
    }

    private static func daysBetween(_ from: String, _ to: String) -> Int {
        let a = Formatters.parseIsoDate(from), b = Formatters.parseIsoDate(to)
        return Int((b.timeIntervalSince(a) / 86_400).rounded())
    }

    private static func retime(_ lesson: [String: Any], from: String, to: String) -> [String: Any] {
        var l = lesson
        let delta = Double(daysBetween(from, to)) * 86_400_000
        if let s = l["startsAt"] as? Double { l["startsAt"] = s + delta }
        if let e = l["endsAt"] as? Double { l["endsAt"] = e + delta }
        return l
    }
}

// MARK: - Snapshot harness

@MainActor
enum SnapshotHarness {
    static let size = CGSize(width: 390, height: 844)

    static var outputDirectory: URL? {
        guard let path = ProcessInfo.processInfo.environment["HONEY_SNAPSHOT_DIR"], !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func makeEnvironment(lesson: FixtureTransport.LessonState = .now) async throws -> AppEnvironment {
        let transport = FixtureTransport()
        transport.lessonState = lesson
        let secrets = InMemorySecretStore()
        try SecretSessionStore(store: secrets).save(SessionTokens(
            accessToken: "fixture-access", accessExpiresAt: "2099-01-01T00:00:00.000Z",
            refreshToken: "fixture-refresh", refreshExpiresAt: "2099-01-01T00:00:00.000Z"
        ))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("HOneySnapshots-\(UUID().uuidString)", isDirectory: true)
        let defaults = UserDefaults(suiteName: "HOneySnapshots.\(UUID().uuidString)")!
        let env = AppEnvironment(
            config: AppConfig.fromBundle(),
            secrets: secrets,
            storageDirectory: dir,
            prefs: Preferences(defaults: defaults),
            writeOptions: [],
            transport: transport,
            portalTransport: transport
        )
        env.themeStore.choose(language: .en)
        await env.bootstrap()
        return env
    }

    /// Hosts the real root in a phone-sized window, lets the fixtures land,
    /// draws the hierarchy, writes the PNG. Returns the image for assertions.
    static func snapshot(_ env: AppEnvironment, name: String, settle: TimeInterval = 1.6) async throws -> UIImage {
        let root = ThemedRoot(store: env.themeStore) { RootView() }
            .environment(env)
            .environment(env.navigator)
        let host = UIHostingController(rootView: root)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: UInt64(settle * 1_000_000_000))
        host.view.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: { let f = UIGraphicsImageRendererFormat(); f.scale = 2; return f }()).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        if let dir = outputDirectory, let data = image.pngData() {
            try data.write(to: dir.appendingPathComponent("\(name).png"))
        }
        window.isHidden = true
        return image
    }

    /// A rendered screen has more than one colour in it.
    static func isBlank(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage, let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return true }
        let count = CFDataGetLength(data)
        var first: (UInt8, UInt8, UInt8)?
        var i = 0
        while i + 3 < count {
            let px = (bytes[i], bytes[i + 1], bytes[i + 2])
            if let f = first, f != px { return false }
            if first == nil { first = px }
            i += 4 * 97 // sample
        }
        return true
    }
}

// MARK: - Tests

@MainActor
final class VisualFixtureTests: XCTestCase {
    private func theme(_ env: AppEnvironment, _ background: HOneyBackground, _ accent: HOneyAccent, _ size: HOneyTextSize = .default) {
        env.themeStore.choose(background: background)
        env.themeStore.choose(accent: accent)
        env.themeStore.choose(textSize: size)
    }

    private func assertRendered(_ image: UIImage, _ name: String) {
        XCTAssertFalse(SnapshotHarness.isBlank(image), "\(name) rendered nothing")
    }

    func testHomeThemeFixtures() async throws {
        // §6.7: five Home fixtures; Cobalt current-lesson proves accent ≠ accent2.
        let cases: [(String, HOneyBackground, HOneyAccent, HOneyTextSize, FixtureTransport.LessonState)] = [
            ("home-stone-harbour-default-next", .stone, .harbour, .default, .upcoming),
            ("home-white-cobalt-default-now", .white, .cobalt, .default, .now),
            ("home-mist-moss-large-next", .mist, .moss, .large, .upcoming),
            ("home-night-cobalt-default-now", .night, .cobalt, .default, .now),
            ("home-stone-clay-larger-none", .stone, .clay, .larger, .none),
        ]
        for (name, bg, accent, size, lesson) in cases {
            let env = try await SnapshotHarness.makeEnvironment(lesson: lesson)
            XCTAssertEqual(env.phase.key, 2, "signed in from the fixtures")
            theme(env, bg, accent, size)
            env.navigator.selected = .home
            assertRendered(try await SnapshotHarness.snapshot(env, name: name), name)
        }
    }

    func testCoreScreensInStoneHarbourAndNightCobalt() async throws {
        for (suffix, bg, accent) in [("stone-harbour", HOneyBackground.stone, HOneyAccent.harbour), ("night-cobalt", .night, .cobalt)] {
            let env = try await SnapshotHarness.makeEnvironment()
            theme(env, bg, accent)
            env.navigator.selected = .experiences
            assertRendered(try await SnapshotHarness.snapshot(env, name: "experiences-\(suffix)"), "experiences")
            env.navigator.push(.explore)
            assertRendered(try await SnapshotHarness.snapshot(env, name: "explore-\(suffix)"), "explore")
            env.navigator.experiencesPath = [.compose(nil)]
            assertRendered(try await SnapshotHarness.snapshot(env, name: "compose-picker-\(suffix)"), "compose picker")
            env.navigator.experiencesPath = [.mine]
            assertRendered(try await SnapshotHarness.snapshot(env, name: "mine-\(suffix)"), "mine")
            env.navigator.experiencesPath = [.why]
            assertRendered(try await SnapshotHarness.snapshot(env, name: "why-\(suffix)"), "why")
            env.navigator.experiencesPath = []
            env.navigator.selected = .timetable
            assertRendered(try await SnapshotHarness.snapshot(env, name: "timetable-day-\(suffix)"), "timetable day")
            env.navigator.timetableIntent = TimetableIntent(date: nil, view: .week)
            assertRendered(try await SnapshotHarness.snapshot(env, name: "timetable-week-\(suffix)"), "timetable week")
            env.navigator.timetablePath = [.history(select: false)]
            assertRendered(try await SnapshotHarness.snapshot(env, name: "history-\(suffix)"), "history")
            env.navigator.timetablePath = []
            env.navigator.selected = .access
            assertRendered(try await SnapshotHarness.snapshot(env, name: "access-\(suffix)"), "access")
            env.navigator.selected = .settings
            assertRendered(try await SnapshotHarness.snapshot(env, name: "settings-\(suffix)"), "settings")
            env.navigator.settingsPath = [.settingsAppearance]
            assertRendered(try await SnapshotHarness.snapshot(env, name: "appearance-\(suffix)"), "appearance")
            env.navigator.settingsPath = [.settingsConnection]
            assertRendered(try await SnapshotHarness.snapshot(env, name: "connection-\(suffix)"), "connection")
            env.navigator.settingsPath = [.settingsPrivacy]
            assertRendered(try await SnapshotHarness.snapshot(env, name: "privacy-\(suffix)"), "privacy")
            env.navigator.settingsPath = []
            await env.signOut()
            assertRendered(try await SnapshotHarness.snapshot(env, name: "login-\(suffix)", settle: 0.6), "login")
        }
    }

    func testAllBackgroundsOnTheAppearanceScreen() async throws {
        // §18.1: every Background with every swatch visible.
        for bg in HOneyBackground.allCases {
            let env = try await SnapshotHarness.makeEnvironment()
            theme(env, bg, .harbour)
            env.navigator.selected = .settings
            env.navigator.settingsPath = [.settingsAppearance]
            assertRendered(try await SnapshotHarness.snapshot(env, name: "appearance-\(bg.rawValue)", settle: 0.8), "appearance \(bg.rawValue)")
        }
    }
}

final class TypographyTests: XCTestCase {
    func testSourceSans3IsBundledAndUsedForEveryRole() {
        XCTAssertTrue(HOneyFont.isAvailable, "SourceSans3VF must be registered from the bundle (UIAppFonts)")
        let title = HOneyFont.uiFont(role: .pageTitle, scale: 1)
        XCTAssertTrue(title.fontName.contains("SourceSans3VF"), title.fontName)
        XCTAssertEqual(title.pointSize, 30, accuracy: 0.5)
        let body = HOneyFont.uiFont(role: .body, scale: 1.22)
        XCTAssertEqual(body.pointSize, 16 * 1.22, accuracy: 0.5, "the text-size scale multiplies the base size")
        let italic = HOneyFont.uiFont(role: .readingItalic, scale: 1)
        XCTAssertTrue(italic.fontName.contains("Italic"), italic.fontName)
    }

    func testWeightsAreDistinctOnTheVariableAxis() {
        // A 600 and a 400 instance must not collapse to one face.
        let regular = HOneyFont.uiFont(role: .body, scale: 1)
        let semibold = HOneyFont.uiFont(role: .bodySemibold, scale: 1)
        let sample = "Written by students, for students." as NSString
        let w1 = sample.size(withAttributes: [.font: regular]).width
        let w2 = sample.size(withAttributes: [.font: semibold]).width
        XCTAssertGreaterThan(w2, w1, "semibold sets wider than regular")
    }
}

@MainActor
final class AppearancePersistenceTests: XCTestCase {
    func testChoicesPersistUnderTheWebKeys() {
        let defaults = UserDefaults(suiteName: "AppearancePersistenceTests.\(UUID().uuidString)")!
        let prefs = Preferences(defaults: defaults)
        let store = ThemeStore(prefs: prefs, systemPrefersDark: true)
        XCTAssertEqual(store.background, .night, "no choice yet: the system's dark preference picks Night")
        store.choose(background: .mist)
        store.choose(accent: .plum)
        store.choose(textSize: .small)
        XCTAssertEqual(defaults.string(forKey: "honey.theme.surface"), "mist")
        XCTAssertEqual(defaults.string(forKey: "honey.theme.accent"), "plum")
        XCTAssertEqual(defaults.string(forKey: "honey.textsize"), "small")
        let again = ThemeStore(prefs: Preferences(defaults: defaults), systemPrefersDark: true)
        XCTAssertEqual(again.background, .mist, "a saved choice beats the system preference")
        XCTAssertEqual(again.accent, .plum)
        XCTAssertEqual(again.textSize, .small)
        XCTAssertEqual(again.theme.palette.accent, RGBA(hex: 0x745170))
        again.systemAppearanceChanged(prefersDark: false)
        XCTAssertEqual(again.background, .mist, "the system no longer decides once chosen")
    }
}

final class TextCaseAuditTests: XCTestCase {
    func testNoUnapprovedUppercaseTransformInProductionSources() throws {
        let root = FixtureTransport.repoRoot.appendingPathComponent("ios-web-port/HOneyNative")
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        let forbidden = [".textCase(.uppercase)", ".smallCaps()", ".uppercased()", ".lowercaseSmallCaps()"]
        var offenders: [String] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            for (index, line) in text.components(separatedBy: "\n").enumerated() {
                if forbidden.contains(where: { line.contains($0) }), !line.contains("case-allowed:") {
                    offenders.append("\(url.lastPathComponent):\(index + 1)")
                }
            }
        }
        XCTAssertEqual(offenders, [], "uppercase transforms without an allowance")
    }
}
