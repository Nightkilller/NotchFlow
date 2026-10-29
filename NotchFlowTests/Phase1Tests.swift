import Testing
import Foundation
@testable import NotchFlow

// MARK: - ScriptStructuringService Tests

@Suite("ScriptStructuringService")
struct ScriptStructuringServiceTests {
    
    @Test("Structures single sentence correctly")
    func singleSentence() {
        let text = "Hello world!"
        let script = ScriptStructuringService.structure(rawText: text, title: "Test")
        
        #expect(script.sections.count == 1)
        #expect(script.sections[0].sentences.count == 1)
        #expect(script.sections[0].sentences[0].words.count == 2)
        #expect(script.sections[0].sentences[0].words[0].text == "Hello")
        #expect(script.sections[0].sentences[0].words[0].globalIndex == 0)
        #expect(script.sections[0].sentences[0].words[1].text == "world!")
        #expect(script.sections[0].sentences[0].words[1].globalIndex == 1)
        #expect(script.wordCount == 2)
    }
    
    @Test("Structures multiple paragraphs into separate sections")
    func multipleSections() {
        let text = """
        First paragraph has two sentences. Here is the second sentence.
        
        Second paragraph is here.
        """
        let script = ScriptStructuringService.structure(rawText: text, title: "Multi")
        
        #expect(script.sections.count == 2)
        #expect(script.sections[0].sentences.count == 2)
        #expect(script.sections[1].sentences.count == 1)
        
        // Ensure global indices are continuous across sections
        let allWords = script.allWords
        for (i, word) in allWords.enumerated() {
            #expect(word.globalIndex == i)
        }
    }
    
    @Test("Handles empty or whitespace-only text gracefully")
    func emptyText() {
        let empty = ScriptStructuringService.structure(rawText: "   \n\n  \t  ")
        #expect(empty.sections.isEmpty)
        #expect(empty.wordCount == 0)
    }
}

// MARK: - EditorViewModel Tests

@Suite("EditorViewModel")
@MainActor
struct EditorViewModelTests {
    
    @Test("Initial state has empty text and zero word count")
    func initialState() {
        let vm = EditorViewModel(autoLoadSaved: false)
        #expect(vm.wordCount == 0)
        #expect(!vm.canStartTeleprompter)
        #expect(!vm.isTeleprompterPresented)
    }
    
    @Test("Updating raw text updates word count and enables teleprompter")
    func textUpdate() {
        let vm = EditorViewModel()
        vm.rawText = "The quick brown fox jumps over the lazy dog."
        
        #expect(vm.wordCount == 9)
        #expect(vm.canStartTeleprompter)
        #expect(vm.estimatedDurationSeconds > 0)
    }
    
    @Test("Load sample script populates text and sections")
    func sampleScript() {
        let vm = EditorViewModel()
        vm.loadSampleScript()
        
        #expect(vm.wordCount > 40)
        #expect(vm.canStartTeleprompter)
        #expect(vm.structuredScript.sections.count >= 3)
    }
    
    @Test("Start and dismiss teleprompter toggles presentation flag")
    func teleprompterPresentation() {
        let vm = EditorViewModel()
        vm.rawText = "Testing teleprompter presentation."
        
        vm.startTeleprompter()
        #expect(vm.isTeleprompterPresented)
        
        vm.dismissTeleprompter()
        #expect(!vm.isTeleprompterPresented)
    }
}

// MARK: - TeleprompterViewModel Tests

@Suite("TeleprompterViewModel")
@MainActor
struct TeleprompterViewModelTests {
    
    private func createTestScript() -> Script {
        let text = "First sentence has words. Second sentence also has words."
        return ScriptStructuringService.structure(rawText: text, title: "Playback Test")
    }
    
    @Test("Initial playback state is paused at first word")
    func initialPlaybackState() {
        let script = createTestScript()
        let vm = TeleprompterViewModel(script: script)
        
        #expect(!vm.isPlaying)
        #expect(vm.position.currentWordIndex == 0)
        #expect(vm.currentWordDisplayIndex == 1)
        #expect(vm.totalWordsCount == script.wordCount)
    }
    
    @Test("Step forward advances word and updates visual states")
    func stepForward() {
        let script = createTestScript()
        let vm = TeleprompterViewModel(script: script)
        
        let firstWord = script.allWords[0]
        let secondWord = script.allWords[1]
        let thirdWord = script.allWords[2]
        
        #expect(vm.visualState(for: firstWord) == .current)
        #expect(vm.visualState(for: secondWord) == .upcoming)
        
        vm.stepForward()
        #expect(vm.position.currentWordIndex == 1)
        #expect(vm.visualState(for: firstWord) == .completed)
        #expect(vm.visualState(for: secondWord) == .current)
        #expect(vm.visualState(for: thirdWord) == .upcoming)
    }
    
    @Test("Step backward decrements position")
    func stepBackward() {
        let script = createTestScript()
        let vm = TeleprompterViewModel(script: script)
        
        vm.stepForward()
        vm.stepForward()
        #expect(vm.position.currentWordIndex == 2)
        
        vm.stepBackward()
        #expect(vm.position.currentWordIndex == 1)
    }
    
    @Test("Step sentence forward jumps to start of next sentence")
    func stepSentenceForward() {
        let script = createTestScript()
        let vm = TeleprompterViewModel(script: script)
        
        // Jump to next sentence
        vm.stepSentenceForward()
        
        let secondSentenceFirstWordIndex = script.sections[0].sentences[1].firstWordGlobalIndex!
        #expect(vm.position.currentWordIndex == secondSentenceFirstWordIndex)
    }
    
    @Test("Reset restores position to start")
    func resetTest() {
        let script = createTestScript()
        let vm = TeleprompterViewModel(script: script)
        
        vm.stepForward()
        vm.stepForward()
        vm.reset()
        
        #expect(!vm.isPlaying)
        #expect(vm.position.currentWordIndex == 0)
        #expect(vm.elapsedTime == 0)
    }
    
    @Test("Countdown initiates on play from beginning when configured")
    func countdownInitiation() {
        let script = createTestScript()
        var settings = ReadingSettings()
        settings.countdownSeconds = 3
        let vm = TeleprompterViewModel(script: script, settings: settings)
        
        #expect(vm.countdownRemaining == nil)
        vm.play()
        #expect(vm.countdownRemaining == 3)
        
        // Pausing during countdown clears countdown
        vm.pause()
        #expect(vm.countdownRemaining == nil)
        #expect(!vm.isPlaying)
    }
    
    @Test("Speed and font adjustments clamp within valid boundaries")
    func tuningClamping() {
        let script = createTestScript()
        let vm = TeleprompterViewModel(script: script)
        
        // Font size bounds
        vm.updateFontSize(delta: 100)
        #expect(vm.settings.fontSize <= AppTypography.teleprompterMaxSize)
        vm.updateFontSize(delta: -200)
        #expect(vm.settings.fontSize >= AppTypography.teleprompterMinSize)
        
        // Speed bounds
        vm.updateSpeed(delta: 500)
        #expect(vm.settings.autoScrollSpeed <= 350)
        vm.updateSpeed(delta: -500)
        #expect(vm.settings.autoScrollSpeed >= 60)
    }
}

