import Testing
import Foundation
@testable import NotchFlow

@Suite("ScriptAlignmentServiceTests")
struct ScriptAlignmentServiceTests {
    
    // Sample test script with repeated vocabulary and realistic structure
    private let sampleScriptWords = [
        "Welcome", "to", "the", "annual", "presentation", "on", "modern", "speech", "technology.",
        "Today,", "we", "will", "explore", "the", "exciting", "future", "of", "on-device", "intelligence.",
        "The", "annual", "presentation", "focuses", "on", "speed,", "accuracy,", "and", "privacy.",
        "In", "conclusion,", "we", "thank", "you", "all", "for", "joining", "us", "today."
    ]
    
    private func createService(initialIndex: Int = 0) -> ScriptAlignmentService {
        let service = ScriptAlignmentService(initialIndex: initialIndex)
        service.loadScript(tokens: sampleScriptWords, startIndex: initialIndex)
        return service
    }
    
    // Test 1: Exact speech-to-script match
    @Test("1. Exact speech-to-script match")
    func exactMatchAdvances() {
        let service = createService(initialIndex: 0)
        let res = service.processSpeech(tokens: ["to"])
        #expect(res.wordIndex == 1)
        #expect(res.decision == .sequentialAdvance(words: 1))
    }
    
    // Test 2: Different capitalization
    @Test("2. Different capitalization matches cleanly")
    func capitalizationDifference() {
        let service = createService(initialIndex: 0)
        let res = service.processSpeech(tokens: ["TO", "THE"])
        #expect(res.wordIndex == 2)
        #expect(res.confidence >= 0.9)
    }
    
    // Test 3: Punctuation differences
    @Test("3. Punctuation differences do not impede alignment")
    func punctuationDifferences() {
        let service = createService(initialIndex: 3)
        // Script has "presentation"
        let res = service.processSpeech(tokens: ["presentation!"])
        #expect(res.wordIndex == 4)
    }
    
    // Test 4: Common contractions
    @Test("4. Common contractions and expansions align correctly")
    func contractionsAlignment() {
        let service = ScriptAlignmentService()
        service.loadScript(tokens: ["We", "cannot", "wait", "to", "start"])
        let res = service.processSpeech(tokens: ["we", "cant"])
        #expect(res.wordIndex == 1)
    }
    
    // Test 5: One incorrectly recognized word
    @Test("5. One incorrectly recognized word does not derail multi-word sequence")
    func oneIncorrectWordTolerated() {
        let service = createService(initialIndex: 0)
        // User says "to the annual", recognizer hears "to tha annual"
        let res = service.processSpeech(tokens: ["to", "tha", "annual"])
        #expect(res.wordIndex == 3)
    }
    
    // Test 6: Several repeated words
    @Test("6. Handles several repeated words without confusing current position")
    func repeatedWordsHandled() {
        let service = ScriptAlignmentService()
        service.loadScript(tokens: ["the", "very", "very", "very", "best", "prompter"])
        let res1 = service.processSpeech(tokens: ["the", "very"])
        #expect(res1.wordIndex == 1)
        let res2 = service.processSpeech(tokens: ["very"])
        #expect(res2.wordIndex == 2)
    }
    
    // Test 7: Repeated sentences in different parts of the script
    @Test("7. Distinguishes repeated sentences across different paragraphs using window constraints")
    func repeatedSentencesDistinguished() {
        let service = createService(initialIndex: 0)
        // First sentence has "annual presentation on modern speech"
        // Second paragraph (index 19) has "The annual presentation focuses"
        let res = service.processSpeech(tokens: ["the", "annual", "presentation"])
        // Must stay in first paragraph (index 4) rather than jumping to second paragraph (index 21)
        #expect(res.wordIndex == 4)
    }
    
    // Test 8: Revised partial transcription
    @Test("8. Revised partial transcription stabilizes before committing ambiguous jump")
    func revisedPartialTranscription() {
        let service = createService(initialIndex: 0)
        // Partial hypothesis 1 has typo: "anual"
        let res1 = service.processSpeech(tokens: ["anual"], isFinal: false)
        // Single word jump without consecutive match requires confirmation
        #expect(res1.wordIndex == 0) // held provisionally
        
        // Partial hypothesis 2 refines to "to the annual"
        let res2 = service.processSpeech(tokens: ["to", "the", "annual"], isFinal: false)
        #expect(res2.wordIndex == 3)
    }
    
    // Test 9: Cumulative transcription
    @Test("9. Cumulative speech recognition updates advance progressively without reprocessing history")
    func cumulativeTranscriptionProgress() {
        let service = createService(initialIndex: 0)
        _ = service.processSpeech(tokens: ["welcome", "to"], fullTranscript: "welcome to")
        #expect(service.confirmedIndex == 1)
        
        _ = service.processSpeech(tokens: ["welcome", "to", "the", "annual"], fullTranscript: "welcome to the annual")
        #expect(service.confirmedIndex == 3)
    }
    
    // Test 10: Empty recognition result
    @Test("10. Empty recognition result keeps current position cleanly")
    func emptyRecognitionKeepsPosition() {
        let service = createService(initialIndex: 4)
        let res = service.processSpeech(tokens: [])
        #expect(res.wordIndex == 4)
        #expect(res.decision == .emptyTranscription)
    }
    
    // Test 11: Stale recognition result
    @Test("11. Stale duplicate recognition result does not trigger extra state transitions")
    func staleRecognitionResult() {
        let service = createService(initialIndex: 2)
        let res1 = service.processSpeech(tokens: ["annual", "presentation"], fullTranscript: "annual presentation", isFinal: true)
        #expect(res1.wordIndex == 4)
        
        // Identical non-final callback arriving late
        let res2 = service.processSpeech(tokens: ["annual", "presentation"], fullTranscript: "annual presentation", isFinal: false)
        #expect(res2.wordIndex == 4)
    }
    
    // Test 12: A skipped word
    @Test("12. Skips a word cleanly when subsequent words are recognized")
    func skippedWordAdvances() {
        let service = createService(initialIndex: 0)
        // Speaker skips "to the" and says "annual presentation"
        let res = service.processSpeech(tokens: ["annual", "presentation"])
        #expect(res.wordIndex == 4)
    }
    
    // Test 13: A skipped sentence
    @Test("13. Multi-word phrase allows advancing when user skips a sentence")
    func skippedSentenceAllowedWithMultiWord() {
        let service = createService(initialIndex: 8) // at end of first sentence
        // Speaker skips to "will explore the exciting"
        let res = service.processSpeech(tokens: ["will", "explore", "the", "exciting"])
        #expect(res.wordIndex > 8)
    }
    
    // Test 14: A repeated phrase
    @Test("14. Re-reading a phrase within the local window holds current position without jumping")
    func repeatedPhraseLocalWindow() {
        let service = createService(initialIndex: 4) // on "presentation"
        // Speaker stumbles and repeats "presentation"
        let res = service.processSpeech(tokens: ["presentation"])
        #expect(res.wordIndex == 4)
    }
    
    // Test 15: A genuine backward correction
    @Test("15. Confirms genuine backward jump when 3+ consecutive words match earlier text")
    func genuineBackwardCorrection() {
        let service = createService(initialIndex: 8) // at index 8 ("technology")
        // Speaker restarts sentence: "Welcome to the annual"
        let res = service.processSpeech(tokens: ["welcome", "to", "the", "annual"])
        #expect(res.wordIndex == 3)
        #expect(res.decision == .backwardCorrection(matchedWords: 4, jumpDistance: 5))
    }
    
    // Test 16: A proposed jump to an unrelated paragraph
    @Test("16. Rejects isolated word match in distant paragraph")
    func rejectsDistantParagraphJump() {
        let service = createService(initialIndex: 0)
        // Word "conclusion" is at index 29 (in final sentence)
        let res = service.processSpeech(tokens: ["conclusion"])
        #expect(res.wordIndex == 0) // must reject jump > searchWindowAhead
    }
    
    // Test 17: A pause followed by resumed speech
    @Test("17. Handles pause cleanly and resumes upon next words")
    func pauseAndResume() {
        let service = createService(initialIndex: 3)
        // User pauses (empty / silence token)
        let res1 = service.processSpeech(tokens: [])
        #expect(res1.wordIndex == 3)
        
        // Resumes speaking
        let res2 = service.processSpeech(tokens: ["presentation", "on"])
        #expect(res2.wordIndex == 5)
    }
    
    // Test 18: End-of-script behavior
    @Test("18. Stops cleanly at end of script without out-of-bounds error")
    func endOfScriptBehavior() {
        let lastIdx = sampleScriptWords.count - 1
        let service = createService(initialIndex: lastIdx)
        let res = service.processSpeech(tokens: ["today", "thank", "you"])
        #expect(res.wordIndex == lastIdx)
        #expect(res.decision == .endOfScriptReached)
    }
    
    // Test 19: Manual navigation during recognition
    @Test("19. Manual navigation resets confirmed index and alignment window")
    func manualNavigationResetsAlignment() {
        let service = createService(initialIndex: 3)
        // User clicks back to word 1 manually
        service.reset(to: 1)
        #expect(service.confirmedIndex == 1)
        
        let res = service.processSpeech(tokens: ["the"])
        #expect(res.wordIndex == 2)
    }
    
    // Test 20: Loading a new script while recognition is active
    @Test("20. Loading a new script resets word count, indices, and candidate buffers")
    func loadingNewScriptResets() {
        let service = createService(initialIndex: 5)
        service.loadScript(tokens: ["Brand", "new", "short", "script"])
        #expect(service.confirmedIndex == 0)
        #expect(service.scriptTokens.count == 4)
        
        let res = service.processSpeech(tokens: ["brand", "new"])
        #expect(res.wordIndex == 1)
    }
}
