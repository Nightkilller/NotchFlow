import Testing
import Foundation
@testable import NotchFlow

// MARK: - ReadingPositionService Tests

@Suite("ReadingPositionService")
@MainActor
struct ReadingPositionServiceTests {
    
    private func createTestScript() -> Script {
        let text = "First sentence has words. Second sentence is here. Third sentence ends it."
        return ScriptStructuringService.structure(rawText: text, title: "Position Service Test")
    }
    
    @Test("Initial state is at first word")
    func initialState() {
        let script = createTestScript()
        let service = ReadingPositionService(script: script)
        
        #expect(service.currentWordIndex == 0)
        #expect(service.currentWord?.text == "First")
        #expect(service.totalWords == script.wordCount)
        #expect(!service.isSimulating)
    }
    
    @Test("Advance word updates position and visual state correctly")
    func advanceWord() {
        let script = createTestScript()
        let service = ReadingPositionService(script: script)
        
        let word0 = script.allWords[0]
        let word1 = script.allWords[1]
        
        #expect(service.visualState(for: word0) == .current)
        #expect(service.visualState(for: word1) == .upcoming)
        
        let advanced = service.advanceWord()
        #expect(advanced)
        #expect(service.currentWordIndex == 1)
        #expect(service.visualState(for: word0) == .completed)
        #expect(service.visualState(for: word1) == .current)
    }
    
    @Test("Detects current sentence accurately across sentence boundaries")
    func currentSentenceDetection() {
        let script = createTestScript()
        let service = ReadingPositionService(script: script)
        
        let firstSentence = script.sections[0].sentences[0]
        let secondSentence = script.sections[0].sentences[1]
        
        #expect(service.isCurrentSentence(firstSentence))
        #expect(!service.isCurrentSentence(secondSentence))
        
        // Advance to second sentence
        service.advanceSentence()
        #expect(!service.isCurrentSentence(firstSentence))
        #expect(service.isCurrentSentence(secondSentence))
    }
    
    @Test("Simulation mode toggles and stops at end of script")
    func simulationMode() async throws {
        let script = createTestScript()
        let service = ReadingPositionService(script: script)
        
        service.startSimulation(wordsPerMinute: 600)
        #expect(service.isSimulating)
        
        // Wait briefly for a tick
        try await Task.sleep(nanoseconds: 150_000_000)
        #expect(service.currentWordIndex > 0)
        
        service.stopSimulation()
        #expect(!service.isSimulating)
    }
}
