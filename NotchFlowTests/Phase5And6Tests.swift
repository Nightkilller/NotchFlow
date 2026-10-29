import Testing
import Foundation
@testable import NotchFlow

// MARK: - TextNormalizationService Tests

@Suite("TextNormalizationService")
struct TextNormalizationServiceTests {
    
    @Test("Expands currency, percentages, and ordinal numbers")
    func expansions() {
        let text = "He paid $5 for a 20% discount on the 1st day."
        let normalized = TextNormalizationService.normalize(text)
        
        #expect(normalized.contains("five dollars"))
        #expect(normalized.contains("percent"))
        #expect(normalized.contains("first"))
    }
    
    @Test("Calculates Levenshtein edit distance accurately")
    func levenshteinDistance() {
        #expect(TextNormalizationService.levenshteinDistance("kitten", "sitting") == 3)
        #expect(TextNormalizationService.levenshteinDistance("teleprompter", "teleprompter") == 0)
        #expect(TextNormalizationService.levenshteinDistance("read", "read") == 0)
        #expect(TextNormalizationService.levenshteinDistance("spoke", "spoken") == 1)
    }
    
    @Test("Applies length-based fuzzy matching rules")
    func fuzzyMatchingRules() {
        // Words < 4 chars require exact match
        #expect(TextNormalizationService.wordsMatch("the", "the"))
        #expect(!TextNormalizationService.wordsMatch("the", "tea"))
        
        // Words 4-7 chars allow distance <= 1
        #expect(TextNormalizationService.wordsMatch("speech", "spech"))
        #expect(!TextNormalizationService.wordsMatch("speech", "spark"))
        
        // Words >= 8 chars allow distance <= 2
        #expect(TextNormalizationService.wordsMatch("presentation", "presentaion"))
        #expect(TextNormalizationService.wordsMatch("teleprompter", "telepromptor"))
    }
}

// MARK: - ScriptMatchingService Tests

@Suite("ScriptMatchingService")
struct ScriptMatchingServiceTests {
    
    private func createTestScript() -> Script {
        let text = """
        Welcome to NotchFlow, the native speech teleprompter.
        It tracks your voice in real time while you speak.
        You can deliver confident presentations effortlessly.
        """
        return ScriptStructuringService.structure(rawText: text, title: "Matching Test")
    }
    
    @Test("Advances reading position when speech tokens match forward")
    func forwardAdvancement() {
        let script = createTestScript()
        let matcher = ScriptMatchingService(initialPosition: 0)
        
        // Finalized result matching "Welcome to NotchFlow"
        let newPos = matcher.processSpeechTokens(["welcome", "to", "notchflow"], in: script.allWords, isFinal: true)
        
        #expect(newPos == 2)
        #expect(matcher.confirmedPosition == 2)
    }
    
    @Test("Requires consecutive confirmations for partial results")
    func partialResultStability() {
        let script = createTestScript()
        let matcher = ScriptMatchingService(config: SyncConfig(minConsecutiveConfirmations: 2), initialPosition: 0)
        
        // First partial: candidate registered but not yet committed
        let p1 = matcher.processSpeechTokens(["welcome", "to"], in: script.allWords, isFinal: false)
        #expect(p1 == 0)
        
        // Second partial matching the same position: committed!
        let p2 = matcher.processSpeechTokens(["welcome", "to"], in: script.allWords, isFinal: false)
        #expect(p2 == 1)
    }
    
    @Test("Prevents backward jitter without multi-word confirmation")
    func backwardJitterRejection() {
        let script = createTestScript()
        let matcher = ScriptMatchingService(initialPosition: 8)
        
        // A single rogue token matching an earlier word is rejected
        let pos = matcher.processSpeechTokens(["welcome"], in: script.allWords, isFinal: false)
        #expect(pos == 8) // Unchanged!
    }
    
    @Test("Allows backward jump when 4 or more consecutive words match")
    func intentionalBackwardRecovery() {
        let script = createTestScript()
        let matcher = ScriptMatchingService(initialPosition: 12)
        
        // Speaker restarted from beginning: 4 consecutive matching words
        let repeatedTokens = ["welcome", "to", "notchflow", "the"]
        let pos = matcher.processSpeechTokens(repeatedTokens, in: script.allWords, isFinal: true)
        
        #expect(pos == 3)
    }
    
    @Test("Tolerates minor speech recognition fuzzy errors")
    func fuzzySpeechTolerance() {
        let script = createTestScript()
        let matcher = ScriptMatchingService(initialPosition: 4)
        
        // "teleprompter" in script is index 6
        let tokens = ["speech", "telepromptor"]
        let pos = matcher.processSpeechTokens(tokens, in: script.allWords, isFinal: true)
        
        #expect(pos == 6)
    }
}
