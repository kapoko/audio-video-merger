import Foundation
import Sparkle

@MainActor
final class UpdateCoordinator: NSObject, ObservableObject {
  static let shared = UpdateCoordinator()

  @Published private(set) var state: UpdateState = .idle
  @Published private(set) var lastCheckedAt: Date?
  @Published var automaticallyChecksForUpdates: Bool = true {
    didSet {
      guard automaticallyChecksForUpdates != oldValue else {
        return
      }

      guard let updater = updaterController?.updater else {
        return
      }

      updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates

      if !automaticallyChecksForUpdates {
        state = .idle
      }
    }
  }

  @Published var betaUpdatesEnabled: Bool {
    didSet {
      guard betaUpdatesEnabled != oldValue else {
        return
      }

      defaults.set(betaUpdatesEnabled, forKey: UpdateSettings.betaUpdatesEnabledDefaultsKey)
      updaterController?.updater.resetUpdateCycleAfterShortDelay()
    }
  }

  private var updaterController: SPUStandardUpdaterController?
  private let defaults: UserDefaults
  private static let lastCheckedDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
  }()

  private override init() {
    defaults = .standard
    betaUpdatesEnabled = defaults.bool(forKey: UpdateSettings.betaUpdatesEnabledDefaultsKey)
    lastCheckedAt = defaults.object(forKey: UpdateSettings.lastCheckedAtDefaultsKey) as? Date
    super.init()
  }

  var statusText: String {
    let baseStatus = state.statusText
    guard let lastCheckedAt else {
      return baseStatus
    }

    return
      "\(baseStatus) • Last checked \(Self.lastCheckedDateFormatter.string(from: lastCheckedAt))"
  }

  var isAvailable: Bool {
    updaterController != nil
  }

  func initializeUpdater() {
    if updaterController != nil {
      return
    }

    guard isAppBundle else {
      state = .unavailable(message: "Updates are available in app bundle builds")
      return
    }

    if let configurationIssue = sparkleConfigurationIssue() {
      state = .unavailable(message: configurationIssue)
      return
    }

    let controller = SPUStandardUpdaterController(
      startingUpdater: false,
      updaterDelegate: self,
      userDriverDelegate: nil
    )

    controller.startUpdater()
    _ = controller.updater.clearFeedURLFromUserDefaults()

    updaterController = controller
    automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
    state = .idle
  }

  func performStartupCheckIfNeeded() {
    guard let updater = updaterController?.updater else {
      return
    }

    guard updater.automaticallyChecksForUpdates else {
      state = .idle
      return
    }

    state = .checking
    updater.checkForUpdatesInBackground()
  }

  func checkForUpdates() {
    guard let updater = updaterController?.updater else {
      return
    }

    state = .checking
    updater.checkForUpdates()
  }

  private var isAppBundle: Bool {
    Bundle.main.bundleURL.pathExtension == "app"
  }

  private func sparkleConfigurationIssue() -> String? {
    let infoDictionary = Bundle.main.infoDictionary ?? [:]

    let feedURLValue = infoDictionary["SUFeedURL"] as? String
    let feedURL = feedURLValue?.trimmingCharacters(in: .whitespacesAndNewlines)
    if feedURL?.isEmpty != false {
      return "Updates unavailable: SUFeedURL is not configured"
    }

    let publicKeyValue = infoDictionary["SUPublicEDKey"] as? String
    let publicKey = publicKeyValue?.trimmingCharacters(in: .whitespacesAndNewlines)
    if publicKey?.isEmpty != false || publicKey == "__SPARKLE_PUBLIC_ED_KEY__" {
      return "Updates unavailable: Sparkle signing key is not configured"
    }

    return nil
  }

  private func markLastCheckedNow() {
    let timestamp = Date()
    lastCheckedAt = timestamp
    defaults.set(timestamp, forKey: UpdateSettings.lastCheckedAtDefaultsKey)
  }
}

extension UpdateCoordinator: SPUUpdaterDelegate {
  private func isNoUpdateError(_ error: Error) -> Bool {
    let nsError = error as NSError
    return nsError.domain == SUSparkleErrorDomain
      && nsError.code == Int(SUError.noUpdateError.rawValue)
  }

  func feedURLString(for updater: SPUUpdater) -> String? {
    #if arch(arm64)
      return "https://audiovideomerger.github.io/appcast-arm64.xml"
    #else
      return "https://audiovideomerger.github.io/appcast-x86_64.xml"
    #endif
  }

  func allowedChannels(for updater: SPUUpdater) -> Set<String> {
    if betaUpdatesEnabled {
      return Set(["beta"])
    }

    return Set()
  }

  func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
    state = .updateAvailable(version: item.displayVersionString)
    markLastCheckedNow()
  }

  func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
    state = .upToDate
    markLastCheckedNow()
  }

  func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
    state = .upToDate
    markLastCheckedNow()
  }

  func updater(
    _ updater: SPUUpdater,
    willDownloadUpdate item: SUAppcastItem,
    with request: NSMutableURLRequest
  ) {
    state = .downloading
  }

  func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
    state = .downloading
  }

  func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
    state = .installing
  }

  func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
    if isNoUpdateError(error) {
      state = .upToDate
      markLastCheckedNow()
      return
    }

    state = .failed(message: error.localizedDescription)
    markLastCheckedNow()
  }

  func updater(
    _ updater: SPUUpdater,
    didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
    error: Error?
  ) {
    if let error {
      if isNoUpdateError(error) {
        state = .upToDate
        markLastCheckedNow()
        return
      }

      state = .failed(message: error.localizedDescription)
      markLastCheckedNow()
      return
    }

    if case .checking = state {
      state = .upToDate
      markLastCheckedNow()
    }
  }
}
