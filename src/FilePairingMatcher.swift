import Foundation

struct FilePairingMatcher {
  struct Configuration {
    let minPairScore: Double
    let minAverageScore: Double
    let minTopSecondGap: Double
  }

  struct PairingCandidate {
    let videoURL: URL
    let audioURL: URL
    let score: Double
  }

  struct NormalizedFileName {
    let compactName: String
    let tokens: [String]
  }

  private let configuration: Configuration

  init(
    configuration: Configuration = Configuration(
      minPairScore: 0.45,
      minAverageScore: 0.58,
      minTopSecondGap: 0.03
    )
  ) {
    self.configuration = configuration
  }

  func suggestedPairs(videos: [URL], audios: [URL]) -> [(videoURL: URL, audioURL: URL)]? {
    let videoCount = videos.count
    let audioCount = audios.count

    guard videoCount == audioCount, videoCount > 1 else {
      return nil
    }

    let normalizedVideos = Dictionary(
      uniqueKeysWithValues: videos.map { url in
        (url.path, normalizedName(url.deletingPathExtension().lastPathComponent))
      })
    let normalizedAudios = Dictionary(
      uniqueKeysWithValues: audios.map { url in
        (url.path, normalizedName(url.deletingPathExtension().lastPathComponent))
      })
    let tokenWeights = tokenWeightsForCurrentBatch(
      videoNames: Array(normalizedVideos.values),
      audioNames: Array(normalizedAudios.values)
    )
    let videoTokenCounts = tokenCounts(Array(normalizedVideos.values))
    let audioTokenCounts = tokenCounts(Array(normalizedAudios.values))

    var candidates: [PairingCandidate] = []
    for videoURL in videos {
      for audioURL in audios {
        guard let normalizedVideo = normalizedVideos[videoURL.path],
          let normalizedAudio = normalizedAudios[audioURL.path]
        else {
          continue
        }

        let score = fuzzyPairScore(
          normalizedVideo: normalizedVideo,
          normalizedAudio: normalizedAudio,
          tokenWeights: tokenWeights,
          videoTokenCounts: videoTokenCounts,
          audioTokenCounts: audioTokenCounts,
          videoCount: videoCount,
          audioCount: audioCount
        )
        candidates.append(PairingCandidate(videoURL: videoURL, audioURL: audioURL, score: score))
      }
    }

    let sortedCandidates = candidates.sorted { lhs, rhs in
      if lhs.score == rhs.score {
        return lhs.videoURL.path < rhs.videoURL.path
      }
      return lhs.score > rhs.score
    }

    var usedVideoPaths = Set<String>()
    var usedAudioPaths = Set<String>()
    var chosen: [(videoURL: URL, audioURL: URL)] = []

    for candidate in sortedCandidates {
      if usedVideoPaths.contains(candidate.videoURL.path)
        || usedAudioPaths.contains(candidate.audioURL.path)
      {
        continue
      }

      usedVideoPaths.insert(candidate.videoURL.path)
      usedAudioPaths.insert(candidate.audioURL.path)
      chosen.append((videoURL: candidate.videoURL, audioURL: candidate.audioURL))

      if chosen.count == videoCount {
        break
      }
    }

    guard chosen.count == videoCount else {
      return nil
    }

    let scoredChosen = chosen.map { pair in
      guard let normalizedVideo = normalizedVideos[pair.videoURL.path],
        let normalizedAudio = normalizedAudios[pair.audioURL.path]
      else {
        return (pair, 0.0)
      }

      return (
        pair,
        fuzzyPairScore(
          normalizedVideo: normalizedVideo,
          normalizedAudio: normalizedAudio,
          tokenWeights: tokenWeights,
          videoTokenCounts: videoTokenCounts,
          audioTokenCounts: audioTokenCounts,
          videoCount: videoCount,
          audioCount: audioCount
        )
      )
    }

    guard scoredChosen.allSatisfy({ $0.1 >= configuration.minPairScore }) else {
      return nil
    }

    let averageScore = scoredChosen.map(\.1).reduce(0, +) / Double(scoredChosen.count)
    guard averageScore >= configuration.minAverageScore else {
      return nil
    }

    let chosenByVideoPath = Dictionary(
      uniqueKeysWithValues: scoredChosen.map { ($0.0.videoURL.path, $0.1) })
    for videoURL in videos {
      let candidatesForVideo =
        candidates
        .filter { $0.videoURL == videoURL }
        .map(\.score)
        .sorted(by: >)

      guard let topScore = candidatesForVideo.first,
        let selectedScore = chosenByVideoPath[videoURL.path]
      else {
        return nil
      }

      if candidatesForVideo.count > 1 {
        let secondScore = candidatesForVideo[1]
        if selectedScore >= topScore {
          guard selectedScore - secondScore >= configuration.minTopSecondGap else {
            return nil
          }
        }
      }
    }

    return chosen
  }

  private func fuzzyPairScore(
    normalizedVideo: NormalizedFileName,
    normalizedAudio: NormalizedFileName,
    tokenWeights: [String: Double],
    videoTokenCounts: [String: Int],
    audioTokenCounts: [String: Int],
    videoCount: Int,
    audioCount: Int
  ) -> Double {
    let baseTokenScore = tokenSimilarity(
      lhs: normalizedVideo.tokens,
      rhs: normalizedAudio.tokens,
      tokenWeights: tokenWeights
    )
    let tokenScore = max(
      baseTokenScore,
      exclusiveSharedTokenScore(
        lhs: normalizedVideo.tokens,
        rhs: normalizedAudio.tokens,
        tokenWeights: tokenWeights,
        videoTokenCounts: videoTokenCounts,
        audioTokenCounts: audioTokenCounts
      ),
      compoundSharedTokenScore(
        lhs: normalizedVideo.tokens,
        rhs: normalizedAudio.tokens,
        tokenWeights: tokenWeights,
        videoTokenCounts: videoTokenCounts,
        audioTokenCounts: audioTokenCounts,
        videoCount: videoCount,
        audioCount: audioCount
      )
    )
    let distanceScore = normalizedEditSimilarity(
      lhs: normalizedVideo.compactName, rhs: normalizedAudio.compactName)

    return tokenScore * 0.75 + distanceScore * 0.25
  }

  private func normalizedName(_ input: String) -> NormalizedFileName {
    let lowered = input.lowercased()
    let replaced = lowered.replacingOccurrences(
      of: "[^a-z0-9]+",
      with: " ",
      options: .regularExpression
    )
    let tokens =
      replaced
      .split(whereSeparator: \.isWhitespace)
      .map(String.init)
      .filter { !$0.isEmpty }
    let compactName = tokens.joined()

    return NormalizedFileName(compactName: compactName, tokens: tokens)
  }

  private func tokenWeightsForCurrentBatch(
    videoNames: [NormalizedFileName],
    audioNames: [NormalizedFileName]
  ) -> [String: Double] {
    let allNames = videoNames + audioNames
    var tokenDocumentFrequency: [String: Int] = [:]

    for name in allNames {
      for token in Set(name.tokens) {
        tokenDocumentFrequency[token, default: 0] += 1
      }
    }

    let totalNames = max(allNames.count, 1)
    var weights: [String: Double] = [:]
    for (token, frequency) in tokenDocumentFrequency {
      let normalizedFrequency = Double(frequency) / Double(totalNames)
      let distinctiveness = 1 - normalizedFrequency
      let floor = 0.1
      weights[token] = max(floor, distinctiveness)
    }

    return weights
  }

  private func tokenCounts(_ names: [NormalizedFileName]) -> [String: Int] {
    var counts: [String: Int] = [:]

    for name in names {
      for token in Set(name.tokens) {
        counts[token, default: 0] += 1
      }
    }

    return counts
  }

  private func tokenSimilarity(lhs: [String], rhs: [String], tokenWeights: [String: Double])
    -> Double
  {
    let lhsSet = Set(lhs)
    let rhsSet = Set(rhs)
    guard !lhsSet.isEmpty || !rhsSet.isEmpty else {
      return 1
    }

    let intersectionWeight = lhsSet.intersection(rhsSet).reduce(0.0) { partialResult, token in
      partialResult + (tokenWeights[token] ?? 1)
    }
    let unionWeight = lhsSet.union(rhsSet).reduce(0.0) { partialResult, token in
      partialResult + (tokenWeights[token] ?? 1)
    }
    let minSideWeight = min(
      lhsSet.reduce(0.0) { $0 + (tokenWeights[$1] ?? 1) },
      rhsSet.reduce(0.0) { $0 + (tokenWeights[$1] ?? 1) }
    )

    guard unionWeight > 0 else {
      return 0
    }

    let jaccard = intersectionWeight / unionWeight
    let containment = minSideWeight > 0 ? intersectionWeight / minSideWeight : 0
    return jaccard * 0.45 + containment * 0.55
  }

  private func exclusiveSharedTokenScore(
    lhs: [String],
    rhs: [String],
    tokenWeights: [String: Double],
    videoTokenCounts: [String: Int],
    audioTokenCounts: [String: Int]
  ) -> Double {
    let lhsSet = Set(lhs)
    let rhsSet = Set(rhs)
    let sharedExclusiveWeight = lhsSet.intersection(rhsSet).reduce(0.0) { result, token in
      guard videoTokenCounts[token] == 1, audioTokenCounts[token] == 1 else {
        return result
      }

      return max(result, tokenWeights[token] ?? 1)
    }

    guard sharedExclusiveWeight > 0 else {
      return 0
    }

    let videoDistinctiveWeight = lhsSet.reduce(0.0) { result, token in
      guard videoTokenCounts[token] == 1 else {
        return result
      }

      return max(result, tokenWeights[token] ?? 1)
    }
    let audioDistinctiveWeight = rhsSet.reduce(0.0) { result, token in
      guard audioTokenCounts[token] == 1 else {
        return result
      }

      return max(result, tokenWeights[token] ?? 1)
    }
    let maxDistinctiveWeight = max(videoDistinctiveWeight, audioDistinctiveWeight)

    guard maxDistinctiveWeight > 0 else {
      return 0
    }

    return sharedExclusiveWeight / maxDistinctiveWeight
  }

  private func compoundSharedTokenScore(
    lhs: [String],
    rhs: [String],
    tokenWeights: [String: Double],
    videoTokenCounts: [String: Int],
    audioTokenCounts: [String: Int],
    videoCount: Int,
    audioCount: Int
  ) -> Double {
    let lhsSet = Set(lhs)
    let rhsSet = Set(rhs)
    let lhsDistinctiveTokens = lhsSet.filter { (videoTokenCounts[$0] ?? 0) < videoCount }
    let rhsDistinctiveTokens = rhsSet.filter { (audioTokenCounts[$0] ?? 0) < audioCount }
    let sharedDistinctiveTokens = lhsDistinctiveTokens.intersection(rhsDistinctiveTokens)

    guard sharedDistinctiveTokens.count > 1 else {
      return 0
    }

    let sharedWeight = sharedDistinctiveTokens.reduce(0.0) { result, token in
      result + (tokenWeights[token] ?? 1)
    }
    let videoDistinctiveWeight = lhsDistinctiveTokens.reduce(0.0) { result, token in
      result + (tokenWeights[token] ?? 1)
    }
    let audioDistinctiveWeight = rhsDistinctiveTokens.reduce(0.0) { result, token in
      result + (tokenWeights[token] ?? 1)
    }
    let maxDistinctiveWeight = max(videoDistinctiveWeight, audioDistinctiveWeight)

    guard maxDistinctiveWeight > 0 else {
      return 0
    }

    return sharedWeight / maxDistinctiveWeight
  }

  private func normalizedEditSimilarity(lhs: String, rhs: String) -> Double {
    let maxLength = max(lhs.count, rhs.count)
    guard maxLength > 0 else {
      return 1
    }

    let distance = levenshteinDistance(lhs, rhs)
    let similarity = 1 - (Double(distance) / Double(maxLength))
    return min(max(similarity, 0), 1)
  }

  private func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
    let lhsChars = Array(lhs)
    let rhsChars = Array(rhs)

    if lhsChars.isEmpty {
      return rhsChars.count
    }
    if rhsChars.isEmpty {
      return lhsChars.count
    }

    var previousRow = Array(0...rhsChars.count)

    for (i, lhsChar) in lhsChars.enumerated() {
      var currentRow = Array(repeating: 0, count: rhsChars.count + 1)
      currentRow[0] = i + 1

      for (j, rhsChar) in rhsChars.enumerated() {
        let insertion = currentRow[j] + 1
        let deletion = previousRow[j + 1] + 1
        let substitution = previousRow[j] + (lhsChar == rhsChar ? 0 : 1)
        currentRow[j + 1] = min(insertion, deletion, substitution)
      }

      previousRow = currentRow
    }

    return previousRow[rhsChars.count]
  }
}
