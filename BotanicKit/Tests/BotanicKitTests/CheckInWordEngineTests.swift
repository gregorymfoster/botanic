import XCTest
@testable import BotanicKit

final class CheckInWordEngineTests: XCTestCase {
    // MARK: - valenceWord

    func testValenceWordBands() {
        XCTAssertEqual(CheckInWordEngine.valenceWord(0), "rough")
        XCTAssertEqual(CheckInWordEngine.valenceWord(0.24), "rough")
        XCTAssertEqual(CheckInWordEngine.valenceWord(0.25), "uneasy")
        XCTAssertEqual(CheckInWordEngine.valenceWord(0.49), "uneasy")
        XCTAssertEqual(CheckInWordEngine.valenceWord(0.5), "pleasant")
        XCTAssertEqual(CheckInWordEngine.valenceWord(0.74), "pleasant")
        XCTAssertEqual(CheckInWordEngine.valenceWord(0.75), "lovely")
        XCTAssertEqual(CheckInWordEngine.valenceWord(1), "lovely")
    }

    func testValenceWordClampsOutOfRange() {
        XCTAssertEqual(CheckInWordEngine.valenceWord(-5), "rough")
        XCTAssertEqual(CheckInWordEngine.valenceWord(5), "lovely")
    }

    // MARK: - intensityWord

    func testIntensityWordBands() {
        XCTAssertEqual(CheckInWordEngine.intensityWord(0), "still")
        XCTAssertEqual(CheckInWordEngine.intensityWord(0.19), "still")
        XCTAssertEqual(CheckInWordEngine.intensityWord(0.20), "gentle")
        XCTAssertEqual(CheckInWordEngine.intensityWord(0.44), "gentle")
        XCTAssertEqual(CheckInWordEngine.intensityWord(0.45), "steady")
        XCTAssertEqual(CheckInWordEngine.intensityWord(0.74), "steady")
        XCTAssertEqual(CheckInWordEngine.intensityWord(0.75), "strong")
        XCTAssertEqual(CheckInWordEngine.intensityWord(1), "strong")
    }

    // MARK: - bodyLoadWord

    func testBodyLoadWordBands() {
        XCTAssertEqual(CheckInWordEngine.bodyLoadWord(0), "light")
        XCTAssertEqual(CheckInWordEngine.bodyLoadWord(0.24), "light")
        XCTAssertEqual(CheckInWordEngine.bodyLoadWord(0.25), "soft")
        XCTAssertEqual(CheckInWordEngine.bodyLoadWord(0.49), "soft")
        XCTAssertEqual(CheckInWordEngine.bodyLoadWord(0.5), "present")
        XCTAssertEqual(CheckInWordEngine.bodyLoadWord(0.74), "present")
        XCTAssertEqual(CheckInWordEngine.bodyLoadWord(0.75), "heavy")
        XCTAssertEqual(CheckInWordEngine.bodyLoadWord(1), "heavy")
    }

    // MARK: - orbWord

    func testOrbWordLowValenceHighIntensityIsNotCalm() {
        let word = CheckInWordEngine.orbWord(valence: 0.1, intensity: 0.9, bodyLoad: 0.9)
        XCTAssertEqual(word, .restless)
        XCTAssertNotEqual(word, .calm)
        XCTAssertNotEqual(word, .settled)
    }

    func testOrbWordLowValenceLowIntensityReadsTired() {
        let word = CheckInWordEngine.orbWord(valence: 0.1, intensity: 0.1, bodyLoad: 0.1)
        XCTAssertEqual(word, .tired)
    }

    func testOrbWordHighValenceLowEnergyIsSettled() {
        let word = CheckInWordEngine.orbWord(valence: 0.95, intensity: 0.1, bodyLoad: 0.1)
        XCTAssertEqual(word, .settled)
    }

    func testOrbWordHighValenceHighEnergyIsLuminous() {
        let word = CheckInWordEngine.orbWord(valence: 0.95, intensity: 0.8, bodyLoad: 0.8)
        XCTAssertEqual(word, .luminous)
    }

    func testOrbWordMidHighValenceCalmVsWarm() {
        XCTAssertEqual(CheckInWordEngine.orbWord(valence: 0.7, intensity: 0.1, bodyLoad: 0.1), .calm)
        XCTAssertEqual(CheckInWordEngine.orbWord(valence: 0.7, intensity: 0.8, bodyLoad: 0.1), .warm)
    }

    func testOrbWordMidValenceBodyLoadPullsTender() {
        XCTAssertEqual(CheckInWordEngine.orbWord(valence: 0.5, intensity: 0.1, bodyLoad: 0.9), .tender)
    }

    func testOrbWordMidValenceIntensityAlonePullsClear() {
        XCTAssertEqual(CheckInWordEngine.orbWord(valence: 0.5, intensity: 0.9, bodyLoad: 0.1), .clear)
    }

    func testOrbWordMidValenceLowEnergyIsGrounded() {
        XCTAssertEqual(CheckInWordEngine.orbWord(valence: 0.5, intensity: 0.1, bodyLoad: 0.1), .grounded)
    }

    func testOrbWordClampsOutOfRangeInputs() {
        // valence -1 clamps to 0, intensity 2 clamps to 1 (energized), bodyLoad -3 clamps to 0.
        let word = CheckInWordEngine.orbWord(valence: -1, intensity: 2, bodyLoad: -3)
        XCTAssertEqual(word, .restless)
    }

    func testOrbWordClampsOutOfRangeInputsAllLow() {
        let word = CheckInWordEngine.orbWord(valence: -1, intensity: -1, bodyLoad: -1)
        XCTAssertEqual(word, .tired)
    }

    // MARK: - orderedTags

    func testOrderedTagsSortsByUsageDescending() {
        let tags = ["Warm", "Soft", "Heavy"]
        let counts = ["Warm": 1, "Soft": 5, "Heavy": 2]
        XCTAssertEqual(CheckInWordEngine.orderedTags(tags, usageCounts: counts), ["Soft", "Heavy", "Warm"])
    }

    func testOrderedTagsKeepsCanonicalOrderOnTies() {
        let tags = ["Warm", "Soft", "Heavy", "Tingly"]
        let counts: [String: Int] = [:]
        XCTAssertEqual(CheckInWordEngine.orderedTags(tags, usageCounts: counts), tags)
    }

    func testOrderedTagsMixedTiesAndUsage() {
        let tags = ["Clear", "Quiet", "Foggy", "Racing", "Curious"]
        let counts = ["Racing": 3, "Foggy": 3]
        // Racing/Foggy tie at 3 — canonical order preserved between them (Foggy before Racing).
        // Then the untouched-zero-usage ones keep canonical order: Clear, Quiet, Curious.
        XCTAssertEqual(
            CheckInWordEngine.orderedTags(tags, usageCounts: counts),
            ["Foggy", "Racing", "Clear", "Quiet", "Curious"]
        )
    }
}
