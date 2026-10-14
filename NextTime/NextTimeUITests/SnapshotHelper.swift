import Foundation
import XCTest

private enum StoreSnapshot {
    static var outputDirectory: URL?
}

@MainActor
func setupSnapshot(_ app: XCUIApplication) {
    guard let simulatorHome = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] else {
        XCTFail("SIMULATOR_HOST_HOME is unavailable")
        return
    }

    let cacheDirectory = URL(fileURLWithPath: simulatorHome)
        .appendingPathComponent("Library/Caches/tools.fastlane", isDirectory: true)
    StoreSnapshot.outputDirectory = cacheDirectory.appendingPathComponent("screenshots", isDirectory: true)

    if let language = try? String(
        contentsOf: cacheDirectory.appendingPathComponent("language.txt"),
        encoding: .utf8
    ).trimmingCharacters(in: .whitespacesAndNewlines), !language.isEmpty {
        app.launchArguments += ["-AppleLanguages", "(\(language))"]
    }

    if let locale = try? String(
        contentsOf: cacheDirectory.appendingPathComponent("locale.txt"),
        encoding: .utf8
    ).trimmingCharacters(in: .whitespacesAndNewlines), !locale.isEmpty {
        app.launchArguments += ["-AppleLocale", locale]
    }
}

@MainActor
func snapshot(_ name: String) {
    guard let outputDirectory = StoreSnapshot.outputDirectory else {
        XCTFail("Call setupSnapshot before taking screenshots")
        return
    }

    do {
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        let device = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "iPhone"
        let safeDevice = device.replacingOccurrences(of: "Clone [0-9]+ of ", with: "", options: .regularExpression)
        let outputURL = outputDirectory.appendingPathComponent("\(safeDevice)-\(name).png")
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: outputURL, options: .atomic)
    } catch {
        XCTFail("Unable to save \(name): \(error.localizedDescription)")
    }
}
