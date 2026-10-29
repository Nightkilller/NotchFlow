import Foundation

// MARK: - Alignment Decision

/// Categorizes the rationale behind accepting, deferring, or rejecting an alignment proposal.
enum AlignmentDecision: Sendable, Equatable {
    case initialStart
    case sequentialAdvance(words: Int)
    case multiWordPhraseMatch(matchedWords: Int, jumpDistance: Int)
    case backwardCorrection(matchedWords: Int, jumpDistance: Int)
    case provisionalMatch(candidateIndex: Int, score: Double, stabilityCount: Int)
    case rejectedWeakMatch(score: Double, threshold: Double)
    case rejectedLargeForwardJump(proposedIndex: Int, current: Int, jump: Int)
    case rejectedBackwardJitter(proposedIndex: Int, current: Int)
    case emptyTranscription
    case staleTranscript
    case manualReset(to: Int)
    case endOfScriptReached
}

// MARK: - Alignment Result

/// Structured result describing the outcome of a speech-to-script alignment evaluation.
struct AlignmentResult: Sendable, Equatable {
    let wordIndex: Int
    let decision: AlignmentDecision
    let confidence: Double
    let matchedPhrase: String
    let matchedScriptText: String
    let timestamp: Date
}

// MARK: - Script Word Token

/// Indexed script token carrying both normalized and original text representations
/// with positional mapping into the parent script.
struct ScriptWordToken: Sendable, Equatable, Identifiable {
    var id: UUID
    let globalIndex: Int
    let originalText: String
    let normalizedText: String
    let sentenceIndex: Int
    let sectionIndex: Int
    
    init(word: ScriptWord) {
        self.id = word.id
        self.globalIndex = word.globalIndex
        self.originalText = word.text
        self.normalizedText = TextNormalizationService.normalize(word.text)
        self.sentenceIndex = word.indexInSentence
        self.sectionIndex = 0
    }
    
    init(globalIndex: Int, text: String, sentenceIndex: Int = 0, sectionIndex: Int = 0) {
        self.id = UUID()
        self.globalIndex = globalIndex
        self.originalText = text
        self.normalizedText = TextNormalizationService.normalize(text)
        self.sentenceIndex = sentenceIndex
        self.sectionIndex = sectionIndex
    }
}

// MARK: - Alignment Configuration

/// Tunable parameters for sequence-based script alignment and jump protection.
struct AlignmentConfig: Sendable, Equatable {
    /// Number of words behind the confirmed position to include in the search window.
    var searchWindowBehind: Int = 10
    /// Number of words ahead of the confirmed position to search for normal forward advances.
    var searchWindowAhead: Int = 12
    /// Maximum forward jump allowed without a 3+ word consecutive sequence match.
    var maxUnconfirmedForwardJump: Int = 4
    /// Minimum consecutive words matching required to allow a backward jump.
    var minBackwardConsecutiveWords: Int = 3
    /// Consecutive matching partial results required to confirm an ambiguous forward advance.
    var requiredConfirmationsForAmbiguous: Int = 2
    /// Minimum similarity score required to accept a single word match (0.0 to 1.0).
    var wordSimilarityThreshold: Double = 0.75
    
    init() {}
}

// MARK: - Script Alignment Service

/// Dedicated, testable service that aligns recognized speech tokens against an ordered script.
/// Employs local bounded sequence alignment, Levenshtein distance, multi-token lookbehind,
/// and hypothesis stabilization to prevent erratic highlighting jumps while handling
/// natural pauses, repeats, skipped words, and corrections.
final class ScriptAlignmentService: @unchecked Sendable {
    
    let config: AlignmentConfig
    
    // MARK: - State Properties
    
    private(set) var scriptTokens: [ScriptWordToken] = []
    private(set) var confirmedIndex: Int = 0
    private(set) var provisionalIndex: Int?
    private(set) var provisionalStabilityCount: Int = 0
    private(set) var lastProcessedTranscript: String = ""
    private(set) var lastResult: AlignmentResult
    
    // MARK: - Initialization
    
    init(config: AlignmentConfig = AlignmentConfig(), initialIndex: Int = 0) {
        self.config = config
        self.confirmedIndex = initialIndex
        self.lastResult = AlignmentResult(
            wordIndex: initialIndex,
            decision: .initialStart,
            confidence: 1.0,
            matchedPhrase: "",
            matchedScriptText: "",
            timestamp: Date()
        )
    }
    
    // MARK: - Script Loading
    
    /// Prepares the internal token mapping from a list of script words.
    func loadScript(words: [ScriptWord], startIndex: Int = 0) {
        self.scriptTokens = words.map { ScriptWordToken(word: $0) }
        reset(to: startIndex)
    }
    
    /// Prepares internal token mapping directly from raw strings (useful for unit tests).
    func loadScript(tokens: [String], startIndex: Int = 0) {
        self.scriptTokens = tokens.enumerated().map { index, text in
            ScriptWordToken(globalIndex: index, text: text)
        }
        reset(to: startIndex)
    }
    
    /// Resets the confirmed reading position to a specific word index (e.g. after manual navigation).
    func reset(to index: Int = 0) {
        let validIndex = scriptTokens.isEmpty ? 0 : max(0, min(scriptTokens.count - 1, index))
        self.confirmedIndex = validIndex
        self.provisionalIndex = nil
        self.provisionalStabilityCount = 0
        self.lastProcessedTranscript = ""
        self.lastResult = AlignmentResult(
            wordIndex: validIndex,
            decision: .manualReset(to: validIndex),
            confidence: 1.0,
            matchedPhrase: "",
            matchedScriptText: "",
            timestamp: Date()
        )
    }
    
    // MARK: - Alignment Processing
    
    /// Processes incoming recognized speech tokens and estimates the correct script position.
    /// - Parameters:
    ///   - recognizedTokens: Array of recognized words (from Whisper or Apple Speech).
    ///   - fullTranscript: The raw string transcript (for cumulative delta detection).
    ///   - isFinal: Whether this speech segment is finalized.
    /// - Returns: An AlignmentResult containing the confirmed word index and decision metadata.
    func processSpeech(
        tokens recognizedTokens: [String],
        fullTranscript: String = "",
        isFinal: Bool = false
    ) -> AlignmentResult {
        guard !scriptTokens.isEmpty else {
            return recordDecision(.emptyTranscription, index: confirmedIndex, confidence: 0)
        }
        
        let normalizedTokens = recognizedTokens
            .map { TextNormalizationService.normalize($0) }
            .filter { !$0.isEmpty }
        
        guard !normalizedTokens.isEmpty else {
            return recordDecision(.emptyTranscription, index: confirmedIndex, confidence: 0)
        }
        
        // Stale transcript check: if transcript is non-empty and identical to already finalized transcript
        if !fullTranscript.isEmpty && fullTranscript == lastProcessedTranscript && !isFinal {
            return lastResult
        }
        if isFinal && !fullTranscript.isEmpty {
            lastProcessedTranscript = fullTranscript
        }
        
        // If we are already at the last word, remain there cleanly
        if confirmedIndex >= scriptTokens.count - 1 {
            return recordDecision(.endOfScriptReached, index: confirmedIndex, confidence: 1.0)
        }
        
        // Evaluate candidate alignments using local sequence matching within the bounded window
        let bestCandidate = findBestCandidate(recentTokens: normalizedTokens)
        
        guard let candidate = bestCandidate else {
            return recordDecision(
                .rejectedWeakMatch(score: 0.0, threshold: config.wordSimilarityThreshold),
                index: confirmedIndex,
                confidence: 0
            )
        }
        
        let targetIndex = candidate.scriptIndex
        let consecutive = candidate.consecutiveMatches
        let score = candidate.similarityScore
        
        // 1. Evaluate Forward Movement
        if targetIndex > confirmedIndex {
            let jump = targetIndex - confirmedIndex
            
            // Sequential immediate next word (jump == 1)
            if jump == 1 && score >= config.wordSimilarityThreshold {
                return commitIndex(
                    targetIndex,
                    decision: .sequentialAdvance(words: 1),
                    confidence: score,
                    phrase: candidate.matchedPhrase,
                    scriptText: scriptTokens[targetIndex].originalText
                )
            }
            
            // Moderate forward advance (jump <= maxUnconfirmedForwardJump)
            if jump <= config.maxUnconfirmedForwardJump {
                if consecutive >= 2 || isFinal {
                    return commitIndex(
                        targetIndex,
                        decision: .sequentialAdvance(words: jump),
                        confidence: score,
                        phrase: candidate.matchedPhrase,
                        scriptText: scriptTokens[targetIndex].originalText
                    )
                } else {
                    // Single-word jump requires stability confirmation
                    if provisionalIndex == targetIndex {
                        provisionalStabilityCount += 1
                        if provisionalStabilityCount >= config.requiredConfirmationsForAmbiguous {
                            return commitIndex(
                                targetIndex,
                                decision: .sequentialAdvance(words: jump),
                                confidence: score,
                                phrase: candidate.matchedPhrase,
                                scriptText: scriptTokens[targetIndex].originalText
                            )
                        }
                    } else {
                        provisionalIndex = targetIndex
                        provisionalStabilityCount = 1
                    }
                    return recordDecision(
                        .provisionalMatch(candidateIndex: targetIndex, score: score, stabilityCount: provisionalStabilityCount),
                        index: confirmedIndex,
                        confidence: score,
                        phrase: candidate.matchedPhrase
                    )
                }
            }
            
            // Larger forward advance (jump <= searchWindowAhead): requires at least 2 consecutive words
            if jump <= config.searchWindowAhead {
                if consecutive >= 2 {
                    return commitIndex(
                        targetIndex,
                        decision: .multiWordPhraseMatch(matchedWords: consecutive, jumpDistance: jump),
                        confidence: score,
                        phrase: candidate.matchedPhrase,
                        scriptText: scriptTokens[targetIndex].originalText
                    )
                } else {
                    return recordDecision(
                        .rejectedLargeForwardJump(proposedIndex: targetIndex, current: confirmedIndex, jump: jump),
                        index: confirmedIndex,
                        confidence: score,
                        phrase: candidate.matchedPhrase
                    )
                }
            }
            
            // Excessive jump beyond window ahead: rejected to prevent jumping to distant paragraphs
            return recordDecision(
                .rejectedLargeForwardJump(proposedIndex: targetIndex, current: confirmedIndex, jump: jump),
                index: confirmedIndex,
                confidence: score,
                phrase: candidate.matchedPhrase
            )
        }
        
        // 2. Evaluate Backward Movement (re-reading / restarting)
        if targetIndex < confirmedIndex {
            let backwardDistance = confirmedIndex - targetIndex
            let requiredConsecutive = backwardDistance > 8 ? 4 : config.minBackwardConsecutiveWords
            
            if consecutive >= requiredConsecutive {
                return commitIndex(
                    targetIndex,
                    decision: .backwardCorrection(matchedWords: consecutive, jumpDistance: backwardDistance),
                    confidence: score,
                    phrase: candidate.matchedPhrase,
                    scriptText: scriptTokens[targetIndex].originalText
                )
            } else {
                return recordDecision(
                    .rejectedBackwardJitter(proposedIndex: targetIndex, current: confirmedIndex),
                    index: confirmedIndex,
                    confidence: score,
                    phrase: candidate.matchedPhrase
                )
            }
        }
        
        // 3. Same Position: re-affirming current word
        return recordDecision(
            .sequentialAdvance(words: 0),
            index: confirmedIndex,
            confidence: score,
            phrase: candidate.matchedPhrase,
            scriptText: scriptTokens[confirmedIndex].originalText
        )
    }
    
    // MARK: - Candidate Search & Sequence Alignment
    
    private struct CandidateMatch {
        let scriptIndex: Int
        let consecutiveMatches: Int
        let similarityScore: Double
        let matchedPhrase: String
    }
    
    private func findBestCandidate(recentTokens: [String]) -> CandidateMatch? {
        guard !recentTokens.isEmpty, !scriptTokens.isEmpty else { return nil }
        
        let startIdx = max(0, confirmedIndex - config.searchWindowBehind)
        let endIdx = min(scriptTokens.count - 1, confirmedIndex + config.searchWindowAhead)
        
        guard startIdx <= endIdx else { return nil }
        
        var bestCandidate: CandidateMatch?
        var highestScore: Double = -1.0
        
        // Inspect up to 4 trailing speech tokens from newest to oldest
        let maxLookbehind = min(4, recentTokens.count)
        
        for tokenOffset in 0..<maxLookbehind {
            let tokenIdx = recentTokens.count - 1 - tokenOffset
            let pivotToken = recentTokens[tokenIdx]
            
            for sIdx in startIdx...endIdx {
                let scriptWord = scriptTokens[sIdx]
                let sim = tokenSimilarity(scriptWord.normalizedText, pivotToken)
                
                guard sim >= config.wordSimilarityThreshold else { continue }
                
                // Trace consecutive preceding token matches
                var consecutive = 1
                var cumulativeSim = sim
                var matchedTokens = [pivotToken]
                
                var offset = 1
                while offset <= tokenIdx && (sIdx - offset) >= 0 {
                    let prevScript = scriptTokens[sIdx - offset].normalizedText
                    let prevSpoken = recentTokens[tokenIdx - offset]
                    let prevSim = tokenSimilarity(prevScript, prevSpoken)
                    
                    if prevSim >= config.wordSimilarityThreshold {
                        consecutive += 1
                        cumulativeSim += prevSim
                        matchedTokens.insert(prevSpoken, at: 0)
                        offset += 1
                    } else {
                        break
                    }
                }
                
                let avgSim = cumulativeSim / Double(consecutive)
                // Composite score weighting: length of consecutive match heavily prioritized over proximity
                let proximityPenalty = Double(abs(sIdx - (confirmedIndex + 1))) * 0.02
                let totalScore = (Double(consecutive) * 1.5) + avgSim - proximityPenalty
                
                if totalScore > highestScore {
                    highestScore = totalScore
                    bestCandidate = CandidateMatch(
                        scriptIndex: sIdx,
                        consecutiveMatches: consecutive,
                        similarityScore: avgSim,
                        matchedPhrase: matchedTokens.joined(separator: " ")
                    )
                }
            }
            
            // If we have a confident multi-word match, stop looking further back
            if let best = bestCandidate, best.consecutiveMatches >= 2 {
                break
            }
        }
        
        return bestCandidate
    }
    
    // MARK: - Token Similarity
    
    func tokenSimilarity(_ s1: String, _ s2: String) -> Double {
        if s1 == s2 { return 1.0 }
        if s1.isEmpty || s2.isEmpty { return 0.0 }
        
        // Check colloquial equivalents (e.g. gonna/going to, ok/okay)
        if areEquivalents(s1, s2) { return 0.95 }
        
        let maxLen = max(s1.count, s2.count)
        guard maxLen > 0 else { return 1.0 }
        
        let dist = TextNormalizationService.levenshteinDistance(s1, s2)
        
        // Exact match required for very short words (< 4 chars) unless standard homophones
        if maxLen < 4 {
            return dist == 0 ? 1.0 : (dist == 1 && s1.first == s2.first ? 0.75 : 0.0)
        }
        
        return max(0.0, 1.0 - (Double(dist) / Double(maxLen)))
    }
    
    private func areEquivalents(_ a: String, _ b: String) -> Bool {
        let pairs: Set<Set<String>> = [
            ["ok", "okay"],
            ["gonna", "going"],
            ["wanna", "want"],
            ["kinda", "kind"],
            ["cant", "cannot"],
            ["dont", "do"],
            ["wont", "will"],
            ["colour", "color"],
            ["favour", "favor"],
            ["centre", "center"],
            ["recognise", "recognize"]
        ]
        return pairs.contains([a, b])
    }
    
    // MARK: - State Mutation
    
    private func commitIndex(
        _ index: Int,
        decision: AlignmentDecision,
        confidence: Double,
        phrase: String = "",
        scriptText: String = ""
    ) -> AlignmentResult {
        self.confirmedIndex = index
        self.provisionalIndex = nil
        self.provisionalStabilityCount = 0
        let result = AlignmentResult(
            wordIndex: index,
            decision: decision,
            confidence: confidence,
            matchedPhrase: phrase,
            matchedScriptText: scriptText,
            timestamp: Date()
        )
        self.lastResult = result
        return result
    }
    
    private func recordDecision(
        _ decision: AlignmentDecision,
        index: Int,
        confidence: Double,
        phrase: String = "",
        scriptText: String = ""
    ) -> AlignmentResult {
        let result = AlignmentResult(
            wordIndex: index,
            decision: decision,
            confidence: confidence,
            matchedPhrase: phrase,
            matchedScriptText: scriptText,
            timestamp: Date()
        )
        self.lastResult = result
        return result
    }
}
