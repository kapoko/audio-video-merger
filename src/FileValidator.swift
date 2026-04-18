import Foundation
import UniformTypeIdentifiers

struct ValidationResult {
  var audioURLs: [URL] = []
  var videoURLs: [URL] = []
  var unrecognizedURLs: [URL] = []

  var isValid: Bool {
    !audioURLs.isEmpty && !videoURLs.isEmpty
  }

  var numVideos: Int {
    audioURLs.count * videoURLs.count
  }
}

enum FileValidator {
  static func validate(urls: [URL]) -> ValidationResult {
    var result = ValidationResult()

    for url in urls {
      guard let contentType = resolvedContentType(for: url) else {
        result.unrecognizedURLs.append(url)
        continue
      }

      if contentType.conforms(to: .audio) {
        result.audioURLs.append(url)
      } else if contentType.conforms(to: .movie) || contentType.conforms(to: .video) {
        result.videoURLs.append(url)
      } else {
        result.unrecognizedURLs.append(url)
      }
    }

    return result
  }

  private static func resolvedContentType(for url: URL) -> UTType? {
    if let values = try? url.resourceValues(forKeys: [.contentTypeKey]),
      let contentType = values.contentType
    {
      return contentType
    }

    let fileExtension = url.pathExtension
    guard !fileExtension.isEmpty else {
      return nil
    }

    return UTType(filenameExtension: fileExtension)
  }
}
