import Foundation

enum UpdateState: Equatable {
  case idle
  case checking
  case upToDate
  case updateAvailable(version: String)
  case downloading
  case installing
  case failed(message: String)
  case unavailable(message: String)

  var statusText: String {
    switch self {
    case .idle:
      return "Idle"
    case .checking:
      return "Checking for updates..."
    case .upToDate:
      return "Up to date"
    case .updateAvailable(let version):
      return "Update available: v\(version)"
    case .downloading:
      return "Downloading update..."
    case .installing:
      return "Installing update..."
    case .failed(let message):
      return "Update failed: \(message)"
    case .unavailable(let message):
      return message
    }
  }
}
