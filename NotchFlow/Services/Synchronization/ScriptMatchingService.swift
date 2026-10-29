import Foundation

// MARK: - Synchronization Configuration

/// Tunable parameters for script matching and speech tracking per Section 22 specification.
struct SyncConfig: Sendable, Equatable {
    /// Number of words behind the confirmed position to include in the search window.
    var searchWindowBehind: Int = 5
    /// Number of words ahead of the confirmed position to search.
    var searchWindowAhead: Int = 40
    /// Number of consecutive partial results required to commit a forward advance.
    var minConsecutiveConfirmations: Int = 1
    /// Minimum number of consecutive matched words required to allow a backward jump.
    var minBackwardConsecutiveWords: Int = 4
}

// MARK: - Script Matching Service

/// Matches recognized spoken words against the prepared script to deterministically
/// track reading position, handle repeats, prevent jitter, and recover from skips.
final class ScriptMatchingService: @unchecked Sendable {
    
    let config: SyncConfig
    private(set) var confirmedPosition: Int
    private var candidatePosition: Int?
    private var candidateStabilityCount: Int = 0
    
    init(config: SyncConfig = SyncConfig(), initialPosition: Int = 0) {
        self.config = config
        self.confirmedPosition = initialPosition
    }
    
    func reset(to position: Int = 0) {
        self.confirmedPosition = position
        self.candidatePosition = nil
        self.candidateStabilityCount = 0
    }
    
    /// Matches incoming speech recognition tokens against the script.
    /// - Parameters:
    ///   - recognizedTokens: Words recognized from recent speech.
    ///   - scriptWords: The complete ordered script words.
    ///   - isFinal: Whether this is a finalized recognition segment.
    /// - Returns: The updated confirmed reading position index.
    func processSpeechTokens(
        _ recognizedTokens: [String],
        in scriptWords: [ScriptWord],
        isFinal: Bool = false
    ) -> Int {
        guard !recognizedTokens.isEmpty, !scriptWords.isEmpty else {
            return confirmedPosition
        }
        
        // Take the trailing tokens (most recently spoken words)
        let recentTokens = Array(recognizedTokens.suffix(5))
        guard let bestMatchIndex = findBestMatch(recentTokens: recentTokens, in: scriptWords) else {
            return confirmedPosition
        }
        
        if bestMatchIndex > confirmedPosition {
            // Forward movement
            if isFinal {
                commitPosition(bestMatchIndex)
            } else {
                if candidatePosition == bestMatchIndex {
                    candidateStabilityCount += 1
                    if candidateStabilityCount >= config.minConsecutiveConfirmations {
                        commitPosition(bestMatchIndex)
                    }
                } else {
                    candidatePosition = bestMatchIndex
                    candidateStabilityCount = 1
                    if candidateStabilityCount >= config.minConsecutiveConfirmations {
                        commitPosition(bestMatchIndex)
                    }
                }
            }
        } else if bestMatchIndex < confirmedPosition {
            // Potential backward jump: require high-confidence multi-word match
            if verifyBackwardMatch(recentTokens: recentTokens, targetIndex: bestMatchIndex, in: scriptWords) {
                AppLogger.sync.info("Confirmed intentional backward jump to word index \(bestMatchIndex)")
                commitPosition(bestMatchIndex)
            } else {
                AppLogger.sync.debug("Rejected tentative backward jump from \(self.confirmedPosition) to \(bestMatchIndex)")
            }
        }
        
        return confirmedPosition
    }
    
    private func findBestMatch(recentTokens: [String], in scriptWords: [ScriptWord]) -> Int? {
        // If 4+ tokens are provided, allow searching from beginning to detect repeated sentences
        let startIndex: Int
        if recentTokens.count >= config.minBackwardConsecutiveWords {
            startIndex = 0
        } else {
            startIndex = max(0, confirmedPosition - config.searchWindowBehind)
        }
        let endIndex = min(scriptWords.count - 1, confirmedPosition + config.searchWindowAhead)
        
        guard startIndex <= endIndex else { return nil }
        
        let lastToken = recentTokens.last!
        var bestIndex: Int?
        var bestScore: Int = -1
        
        // Scan the bounded window
        for i in startIndex...endIndex {
            if TextNormalizationService.wordsMatch(scriptWords[i].text, lastToken) {
                // Verify preceding tokens if available
                var score = 1
                for offset in 1..<recentTokens.count {
                    let scriptIdx = i - offset
                    let tokenIdx = recentTokens.count - 1 - offset
                    guard scriptIdx >= 0 && tokenIdx >= 0 else { break }
                    if TextNormalizationService.wordsMatch(scriptWords[scriptIdx].text, recentTokens[tokenIdx]) {
                        score += 1
                    }
                }
                
                if score > bestScore {
                    bestScore = score
                    bestIndex = i
                }
            }
        }
        
        return bestIndex
    }
    
    private func verifyBackwardMatch(recentTokens: [String], targetIndex: Int, in scriptWords: [ScriptWord]) -> Bool {
        guard recentTokens.count >= config.minBackwardConsecutiveWords else { return false }
        
        var matchCount = 0
        for (offset, token) in recentTokens.reversed().enumerated() {
            let scriptIdx = targetIndex - offset
            guard scriptIdx >= 0 else { break }
            if TextNormalizationService.wordsMatch(scriptWords[scriptIdx].text, token) {
                matchCount += 1
            } else {
                break
            }
        }
        
        return matchCount >= config.minBackwardConsecutiveWords
    }
    
    private func commitPosition(_ newPosition: Int) {
        confirmedPosition = newPosition
        candidatePosition = nil
        candidateStabilityCount = 0
    }
}
