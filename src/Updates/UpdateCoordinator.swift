import Foundation
import Sparkle

@MainActor
final class UpdateCoordinator: NSObject, ObservableObject {
  static let shared = UpdateCoordinator()

  @Published private(set) var state: UpdateState = .idle

  private var updaterController: SPUStandardUpdaterController?
  private let defaults: UserDefaults

  private override init() {
    defaults = .standard
    super.init()
  }

  var isAvailable: Bool {
    updaterController != nil
  }

  var automaticallyChecksForUpdates: Bool {
    get {
      updaterController?.updater.automaticallyChecksForUpdates ?? true
    }
    set {
      guard let updater = updaterController?.updater else {
        return
      }

      updater.automaticallyChecksForUpdates = newValue

      if !newValue {
        state = .idle
      }
    }
  }

  var betaUpdatesEnabled: Bool {
    get {
      defaults.bool(forKey: UpdateSettings.betaUpdatesEnabledDefaultsKey)
    }
    set {
      defaults.set(newValue, forKey: UpdateSettings.betaUpdatesEnabledDefaultsKey)
      updaterController?.updater.resetUpdateCycleAfterShortDelay()
    }
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
}

extension UpdateCoordinator: SPUUpdaterDelegate {
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
  }

  func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
    state = .upToDate
  }

  func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
    state = .upToDate
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
    state = .failed(message: error.localizedDescription)
  }

  func updater(
    _ updater: SPUUpdater,
    didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
    error: Error?
  ) {
    if let error {
      state = .failed(message: error.localizedDescription)
      return
    }

    if case .checking = state {
      state = .upToDate
    }
  }
}
