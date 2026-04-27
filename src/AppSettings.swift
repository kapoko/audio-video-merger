import Foundation

enum AppSettings {
  enum Keys {
    static let preferHigherQualityAudio = "conversion.audio.preferHigherQuality"
  }

  struct HighQualityAudioPolicyRule: Identifiable {
    let containers: [String]
    let flags: [String]

    var id: String {
      containers.joined(separator: ",")
    }

    var containersLabel: String {
      containers.map { ".\($0)" }.joined(separator: ", ")
    }

    var flagsLabel: String {
      flags.joined(separator: " ")
    }

    func matches(extension outputExtension: String) -> Bool {
      containers.contains(outputExtension)
    }
  }

  static let highQualityAudioPolicy: [HighQualityAudioPolicyRule] = [
    HighQualityAudioPolicyRule(
      containers: ["mp4", "m4v"],
      flags: ["-c:a", "aac", "-b:a", "256k"]
    ),
    HighQualityAudioPolicyRule(
      containers: ["mov"],
      flags: ["-c:a", "aac", "-b:a", "320k"]
    ),
    HighQualityAudioPolicyRule(
      containers: ["3gp", "3g2"],
      flags: ["-c:a", "aac", "-b:a", "160k"]
    ),
    HighQualityAudioPolicyRule(
      containers: ["mkv", "webm"],
      flags: ["-c:a", "libopus", "-b:a", "192k"]
    ),
    HighQualityAudioPolicyRule(
      containers: ["avi"],
      flags: ["-c:a", "libmp3lame", "-b:a", "320k"]
    ),
    HighQualityAudioPolicyRule(
      containers: ["flv", "ts"],
      flags: ["-c:a", "aac", "-b:a", "256k"]
    ),
    HighQualityAudioPolicyRule(
      containers: ["m2ts", "mts"],
      flags: ["-c:a", "ac3", "-b:a", "448k"]
    ),
    HighQualityAudioPolicyRule(
      containers: ["mpg", "mpeg"],
      flags: ["-c:a", "mp2", "-b:a", "384k"]
    ),
    HighQualityAudioPolicyRule(
      containers: ["vob"],
      flags: ["-c:a", "ac3", "-b:a", "448k"]
    ),
    HighQualityAudioPolicyRule(
      containers: ["wmv", "asf"],
      flags: ["-c:a", "wmav2", "-b:a", "320k"]
    ),
    HighQualityAudioPolicyRule(
      containers: ["ogg", "ogv"],
      flags: ["-c:a", "libvorbis", "-q:a", "7"]
    ),
  ]

  static var prefersHigherQualityAudio: Bool {
    UserDefaults.standard.bool(forKey: Keys.preferHigherQualityAudio)
  }

  static func highQualityAudioArguments(forOutputExtension outputExtension: String) -> [String] {
    let normalizedExtension =
      outputExtension
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
      .replacingOccurrences(of: ".", with: "")

    guard !normalizedExtension.isEmpty else {
      return []
    }

    return
      highQualityAudioPolicy
      .first(where: { $0.matches(extension: normalizedExtension) })?
      .flags ?? []
  }
}
