//
//  AppConfigTests.swift
//  UnwrapTests
//
//  Created by OpenAI on 30/05/2026.
//  Copyright © 2026 Hacking with Swift.
//

import XCTest
@testable import Unwrap

/// Tests that runtime configuration is bundled and wired into app behavior.
class AppConfigTests: XCTestCase {
    let expectedRankLevels = [
        0,
        200,
        500,
        1000,
        2000,
        3000,
        4000,
        5000,
        6500,
        8000,
        10000,
        12500,
        15000,
        20000,
        25000,
        30000,
        40000,
        50000,
        65000,
        80000,
        100000,
        Int.max
    ]

    let expectedJSONKeys: Set<String> = [
        "points_for_learning",
        "points_for_reviewing",
        "points_for_practicing",
        "rank_levels",
        "smallest_rank_fraction"
    ]

    //harness:criterion=c-appconfig-json-bundled,c-appconfig-json-decodes-without-error
    func testAppConfigDecodes() {
        _ = Bundle.main.decode(AppConfig.self, from: "AppConfig.json")
    }

    //harness:criterion=c-appconfig-json-keys-present,c-appconfig-json-all-keys-valid
    func testAppConfigKeys() throws {
        let config = Bundle.main.decode(AppConfig.self, from: "AppConfig.json")
        assertDefaultValues(in: config)

        guard let jsonURL = Bundle.main.url(forResource: "AppConfig.json", withExtension: nil) else {
            XCTFail("AppConfig.json should be present in the app bundle.")
            return
        }

        let jsonData = try Data(contentsOf: jsonURL)
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
        let dictionary = try XCTUnwrap(jsonObject as? [String: Any])

        XCTAssertEqual(Set(dictionary.keys), expectedJSONKeys)
    }

    //harness:criterion=c-unwrap-config-static-property
    func testUnwrapConfigLoadsBundledDefaults() {
        let config = Unwrap.config

        assertDefaultValues(in: config)
    }

    //harness:criterion=c-user-static-props-reads-config,c-appconfig-no-hardcoded-literals-remain
    func testUserStaticPropertiesReadCurrentConfig() {
        let originalConfig = Unwrap.config
        let replacementConfig = AppConfig(
            pointsForLearning: 11,
            pointsForReviewing: 22,
            pointsForPracticing: 33,
            rankLevels: [0, 44, Int.max],
            smallestRankFraction: 0.044
        )

        Unwrap.config = replacementConfig
        defer { Unwrap.config = originalConfig }

        XCTAssertEqual(User.pointsForLearning, replacementConfig.pointsForLearning)
        XCTAssertEqual(User.pointsForReviewing, replacementConfig.pointsForReviewing)
        XCTAssertEqual(User.pointsForPracticing, replacementConfig.pointsForPracticing)
        XCTAssertEqual(User.rankLevels, replacementConfig.rankLevels)
        XCTAssertEqual(User.smallestRankFraction, replacementConfig.smallestRankFraction)
    }

    //harness:criterion=c-decode-if-present-returns-nil
    func testDecodeIfPresentReturnsNilForMissingFile() {
        let config = Bundle.main.decodeIfPresent(AppConfig.self, from: "MissingAppConfig.json")

        XCTAssertNil(config)
    }

    //harness:criterion=c-decode-if-present-returns-value
    func testDecodeIfPresentReturnsConfigForBundledFile() throws {
        let config = try XCTUnwrap(Bundle.main.decodeIfPresent(AppConfig.self, from: "AppConfig.json"))

        XCTAssertEqual(config.pointsForPracticing, 20)
    }

    //harness:criterion=c-existing-bundle-decode-unaffected
    func testRequiredBundleDecodeStillLoadsChapters() {
        let chapters = Bundle.main.decode([Chapter].self, from: "Chapters.json")

        XCTAssertFalse(chapters.isEmpty)
        XCTAssertFalse(Unwrap.chapters.isEmpty)
    }

    func assertDefaultValues(in config: AppConfig, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(config.pointsForLearning, 100, file: file, line: line)
        XCTAssertEqual(config.pointsForReviewing, 100, file: file, line: line)
        XCTAssertEqual(config.pointsForPracticing, 20, file: file, line: line)
        XCTAssertEqual(config.rankLevels, expectedRankLevels, file: file, line: line)
        XCTAssertEqual(config.smallestRankFraction, 0.001, file: file, line: line)
    }
}
