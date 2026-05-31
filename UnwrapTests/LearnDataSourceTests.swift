//
//  LearnDataSourceTests.swift
//  UnwrapTests
//
//  Created by OpenAI on 30/05/2026.
//  Copyright © 2026 Hacking with Swift. All rights reserved.
//

import XCTest
@testable import Unwrap

final class LearnDataSourceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        User.current = makeUser()
    }

    override func tearDown() {
        User.current = nil
        super.tearDown()
    }

    //harness:criterion=c-learn-filter-enum-cases,c-learn-datasource-tests-file-exists,c-learn-datasource-tests-registered-in-project
    func testLearnFilterHasExpectedCases() {
        func name(for filter: LearnFilter) -> String {
            switch filter {
            case .all:
                return "all"
            case .notStarted:
                return "notStarted"
            case .completed:
                return "completed"
            }
        }

        XCTAssertEqual(name(for: .all), "all")
        XCTAssertEqual(name(for: .notStarted), "notStarted")
        XCTAssertEqual(name(for: .completed), "completed")
        XCTAssertNotEqual(LearnFilter.all, LearnFilter.notStarted)
        XCTAssertNotEqual(LearnFilter.all, LearnFilter.completed)
        XCTAssertNotEqual(LearnFilter.notStarted, LearnFilter.completed)
    }

    //harness:criterion=c-learn-datasource-default-filter-all
    func testDefaultFilterIsAll() {
        let dataSource = LearnDataSource()

        XCTAssertEqual(dataSource.filter, .all)
    }

    //harness:criterion=c-learn-filter-all-shows-every-chapter,c-learn-filter-all-preserves-order
    func testAllFilterShowsEveryChapterInOrder() {
        User.current = makeUser(learned: Set(Unwrap.chapters[0].sections.map { $0.bundleName }))
        let dataSource = LearnDataSource()
        dataSource.filter = .all

        XCTAssertEqual(dataSource.visibleChapters.count, Unwrap.chapters.count)
        XCTAssertEqual(dataSource.visibleChapters.map(\.name), Unwrap.chapters.map(\.name))
    }

    //harness:criterion=c-learn-filter-not-started-excludes-any-progress
    func testNotStartedExcludesProgressSections() {
        let learnedOnly = Unwrap.chapters[0].sections[0]
        let reviewedOnly = Unwrap.chapters[0].sections[1]
        User.current = makeUser(learned: [learnedOnly.bundleName], reviewed: [reviewedOnly.bundleName])
        let dataSource = LearnDataSource()

        dataSource.filter = .notStarted

        let visibleSections = flattenedVisibleSections(from: dataSource)
        XCTAssertFalse(visibleSections.contains(learnedOnly))
        XCTAssertFalse(visibleSections.contains(reviewedOnly))
        XCTAssertFalse(visibleSections.contains { section in
            User.current.hasLearned(section.bundleName) || User.current.hasReviewed(section.bundleName)
        })
    }

    //harness:criterion=c-learn-filter-not-started-includes-zero-progress
    func testNotStartedIncludesZeroProgressSections() {
        User.current = makeUser()
        let dataSource = LearnDataSource()

        dataSource.filter = .notStarted

        let visibleSections = flattenedVisibleSections(from: dataSource)
        XCTAssertFalse(visibleSections.isEmpty)
        XCTAssertTrue(visibleSections.allSatisfy { section in
            User.current.hasLearned(section.bundleName) == false && User.current.hasReviewed(section.bundleName) == false
        })
    }

    //harness:criterion=c-learn-filter-completed-includes-both-true
    func testCompletedIncludesBothTrueSections() {
        let completed = Unwrap.chapters[0].sections[0]
        let learnedOnly = Unwrap.chapters[0].sections[1]
        let reviewedOnly = Unwrap.chapters[0].sections[2]
        User.current = makeUser(
            learned: [completed.bundleName, learnedOnly.bundleName],
            reviewed: [completed.bundleName, reviewedOnly.bundleName]
        )
        let dataSource = LearnDataSource()

        dataSource.filter = .completed

        let visibleSections = flattenedVisibleSections(from: dataSource)
        XCTAssertTrue(visibleSections.contains(completed))
        XCTAssertTrue(visibleSections.allSatisfy { section in
            User.current.hasLearned(section.bundleName) && User.current.hasReviewed(section.bundleName)
        })
    }

    //harness:criterion=c-learn-filter-completed-excludes-partial-progress
    func testCompletedExcludesPartialProgress() {
        let completed = Unwrap.chapters[0].sections[0]
        let learnedOnly = Unwrap.chapters[0].sections[1]
        let reviewedOnly = Unwrap.chapters[0].sections[2]
        User.current = makeUser(
            learned: [completed.bundleName, learnedOnly.bundleName],
            reviewed: [completed.bundleName, reviewedOnly.bundleName]
        )
        let dataSource = LearnDataSource()

        dataSource.filter = .completed

        let visibleSections = flattenedVisibleSections(from: dataSource)
        XCTAssertFalse(visibleSections.contains(learnedOnly))
        XCTAssertFalse(visibleSections.contains(reviewedOnly))
        XCTAssertFalse(visibleSections.contains { section in
            User.current.hasLearned(section.bundleName) != User.current.hasReviewed(section.bundleName)
        })
    }

    //harness:criterion=c-learn-filter-empty-chapter-hidden
    func testEmptyChapterIsHidden() {
        let hiddenChapter = Unwrap.chapters[0]
        let progressedSections = Set(hiddenChapter.sections.map { $0.bundleName })
        User.current = makeUser(learned: progressedSections)
        let dataSource = LearnDataSource()

        dataSource.filter = .notStarted

        XCTAssertFalse(dataSource.visibleChapters.contains { $0.name == hiddenChapter.name })
    }

    //harness:criterion=c-learn-filter-partial-chapter-visible
    func testPartialChapterIsVisible() {
        let chapter = Unwrap.chapters[0]
        let progressedSection = chapter.sections[0]
        let zeroProgressSection = chapter.sections[1]
        User.current = makeUser(learned: [progressedSection.bundleName])
        let dataSource = LearnDataSource()

        dataSource.filter = .notStarted

        let visibleChapter = dataSource.visibleChapters.first { $0.name == chapter.name }
        XCTAssertNotNil(visibleChapter)
        XCTAssertFalse(visibleChapter?.sections.contains(progressedSection) ?? true)
        XCTAssertTrue(visibleChapter?.sections.contains(zeroProgressSection) ?? false)
        XCTAssertEqual(visibleChapter?.sections.count, chapter.sections.count - 1)
    }

    //harness:criterion=c-learn-datasource-number-of-sections
    func testNumberOfSectionsMatchesVisibleChapters() {
        configureMixedProgressUser()
        let dataSource = LearnDataSource()
        let tableView = UITableView()

        for filter in [LearnFilter.all, .notStarted, .completed] {
            dataSource.filter = filter
            XCTAssertEqual(dataSource.numberOfSections(in: tableView), dataSource.visibleChapters.count)
        }
    }

    //harness:criterion=c-learn-datasource-number-of-rows
    func testNumberOfRowsMatchesVisibleChapterSections() {
        configureMixedProgressUser()
        let dataSource = LearnDataSource()
        let tableView = UITableView()

        for filter in [LearnFilter.all, .notStarted, .completed] {
            dataSource.filter = filter

            for sectionIndex in dataSource.visibleChapters.indices {
                XCTAssertEqual(
                    dataSource.tableView(tableView, numberOfRowsInSection: sectionIndex),
                    dataSource.visibleChapters[sectionIndex].sections.count
                )
            }
        }
    }

    //harness:criterion=c-learn-datasource-title-for-section
    func testTitleForSectionUsesVisibleChapters() {
        let rawFirstSection = Unwrap.chapters[0].sections[0]
        User.current = makeUser(learned: [rawFirstSection.bundleName])
        let dataSource = LearnDataSource()

        dataSource.filter = .notStarted
        let indexPath = IndexPath(row: 0, section: 0)

        XCTAssertNotEqual(dataSource.visibleChapters[0].sections[0], rawFirstSection)
        XCTAssertEqual(dataSource.title(for: indexPath), dataSource.visibleChapters[0].sections[0])
    }

    //harness:criterion=c-learn-datasource-did-select-correct-section
    func testDidSelectRowUsesVisibleChapters() {
        let rawFirstSection = Unwrap.chapters[0].sections[0]
        User.current = makeUser(learned: [rawFirstSection.bundleName])
        let viewController = SpyLearnViewController(style: .plain)
        let dataSource = viewController.dataSource
        let indexPath = IndexPath(row: 0, section: 0)

        dataSource.delegate = viewController
        dataSource.filter = .notStarted
        dataSource.tableView(UITableView(), didSelectRowAt: indexPath)

        XCTAssertNotEqual(dataSource.visibleChapters[0].sections[0], rawFirstSection)
        XCTAssertEqual(viewController.startedStudyingTitle, dataSource.visibleChapters[0].sections[0])
    }

    //harness:criterion=c-learn-datasource-header-title-correct
    func testHeaderTitleUsesVisibleChapters() throws {
        let hiddenChapter = Unwrap.chapters[0]
        User.current = makeUser(learned: Set(hiddenChapter.sections.map { $0.bundleName }))
        let dataSource = LearnDataSource()
        let tableView = UITableView()
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")

        dataSource.filter = .notStarted
        let header = try XCTUnwrap(dataSource.tableView(tableView, viewForHeaderInSection: 0) as? DynamicHeightHeaderView)

        XCTAssertNotEqual(dataSource.visibleChapters[0].name, Unwrap.chapters[0].name)
        XCTAssertEqual(header.headerLabel.text, dataSource.visibleChapters[0].name)
    }

    //harness:criterion=c-learn-viewcontroller-segmented-control-present
    func testSegmentedControlHasThreeSegments() throws {
        let viewController = LearnViewController(style: .plain)
        viewController.loadViewIfNeeded()

        let segmentedControl = try XCTUnwrap(findSegmentedControl(in: viewController))

        XCTAssertEqual(segmentedControl.numberOfSegments, 3)
        XCTAssertEqual(segmentedControl.titleForSegment(at: 0), "All")
        XCTAssertEqual(segmentedControl.titleForSegment(at: 1), "Not Started")
        XCTAssertEqual(segmentedControl.titleForSegment(at: 2), "Completed")
        XCTAssertEqual(segmentedControl.accessibilityLabel, "Learn filter")
    }

    //harness:criterion=c-learn-segmented-control-default-all
    func testSegmentedControlDefaultsToAll() throws {
        let viewController = LearnViewController(style: .plain)
        viewController.loadViewIfNeeded()

        let segmentedControl = try XCTUnwrap(findSegmentedControl(in: viewController))

        XCTAssertEqual(segmentedControl.selectedSegmentIndex, 0)
        XCTAssertEqual(segmentedControl.accessibilityValue, "All")
    }

    //harness:criterion=c-learn-segmented-control-updates-filter
    func testSelectingNotStartedSegmentUpdatesFilter() throws {
        let viewController = LearnViewController(style: .plain)
        viewController.loadViewIfNeeded()
        let segmentedControl = try XCTUnwrap(findSegmentedControl(in: viewController))
        let tableView = ReloadCountingTableView()
        viewController.tableView = tableView

        segmentedControl.selectedSegmentIndex = 1
        try performRegisteredFilterAction(from: segmentedControl, on: viewController)

        XCTAssertEqual(viewController.dataSource.filter, .notStarted)
        XCTAssertEqual(segmentedControl.accessibilityValue, "Not Started")
        XCTAssertEqual(tableView.reloadDataCallCount, 1)
    }

    //harness:criterion=c-learn-segmented-control-completed-updates-filter
    func testSelectingCompletedSegmentUpdatesFilter() throws {
        let viewController = LearnViewController(style: .plain)
        viewController.loadViewIfNeeded()
        let segmentedControl = try XCTUnwrap(findSegmentedControl(in: viewController))
        let tableView = ReloadCountingTableView()
        viewController.tableView = tableView

        segmentedControl.selectedSegmentIndex = 2
        try performRegisteredFilterAction(from: segmentedControl, on: viewController)

        XCTAssertEqual(viewController.dataSource.filter, .completed)
        XCTAssertEqual(segmentedControl.accessibilityValue, "Completed")
        XCTAssertEqual(tableView.reloadDataCallCount, 1)
    }

    //harness:criterion=c-learn-segmented-control-does-not-displace-glossary
    func testGlossaryButtonStillPresent() {
        let viewController = LearnViewController(style: .plain)
        _ = UINavigationController(rootViewController: viewController)

        viewController.loadViewIfNeeded()

        XCTAssertNotNil(viewController.navigationItem.rightBarButtonItem)
        XCTAssertEqual(viewController.navigationItem.rightBarButtonItem?.title, "Glossary")
    }

    //harness:criterion=c-learn-no-new-persistence-fields
    func testLearnFilterIsNotPersistedOnUser() throws {
        let user = makeUser(
            learned: [Unwrap.chapters[0].sections[0].bundleName],
            reviewed: [Unwrap.chapters[0].sections[0].bundleName]
        )
        User.current = user
        let viewController = LearnViewController(style: .plain)
        viewController.loadViewIfNeeded()
        viewController.dataSource.filter = .completed

        let encodedUser = try JSONEncoder().encode(user)
        let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encodedUser) as? [String: Any])
        let persistedKeys = Set(jsonObject.keys)

        XCTAssertFalse(persistedKeys.contains("filter"))
        XCTAssertFalse(persistedKeys.contains("learnFilter"))
        XCTAssertFalse(persistedKeys.contains("LearnFilter"))
    }

    //harness:criterion=c-learn-user-data-changed-recomputes-filter
    func testUserDataChangedRecomputesFilter() {
        User.current = makeUser()
        let viewController = LearnViewController(style: .plain)
        viewController.loadViewIfNeeded()
        let tableView = ReloadCountingTableView()
        let sectionToStart = Unwrap.chapters[0].sections[0]
        viewController.tableView = tableView
        viewController.dataSource.filter = .notStarted

        XCTAssertTrue(flattenedVisibleSections(from: viewController.dataSource).contains(sectionToStart))

        User.current = makeUser(learned: [sectionToStart.bundleName])
        viewController.userDataChanged()

        XCTAssertFalse(flattenedVisibleSections(from: viewController.dataSource).contains(sectionToStart))
        XCTAssertEqual(tableView.reloadDataCallCount, 1)
    }

    //harness:criterion=c-learn-user-status-changed-notification-preserved
    func testUserStatusChangedNotificationTriggersRefresh() {
        User.current = makeUser()
        let viewController = LearnViewController(style: .plain)
        viewController.loadViewIfNeeded()
        let tableView = ReloadCountingTableView()
        let sectionToStart = Unwrap.chapters[0].sections[0]
        viewController.tableView = tableView
        viewController.dataSource.filter = .notStarted

        XCTAssertTrue(flattenedVisibleSections(from: viewController.dataSource).contains(sectionToStart))

        User.current = makeUser(learned: [sectionToStart.bundleName])
        NotificationCenter.default.post(name: .userStatusChanged, object: nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        XCTAssertFalse(flattenedVisibleSections(from: viewController.dataSource).contains(sectionToStart))
        XCTAssertGreaterThanOrEqual(tableView.reloadDataCallCount, 1)
    }

    //harness:criterion=c-learn-filter-all-context-menu-preserved
    func testContextMenuPreservedUnderAllFilter() {
        User.current = makeUser()
        let viewController = LearnViewController(style: .plain)
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        viewController.tableView.frame = viewController.view.bounds
        viewController.dataSource.filter = .all
        viewController.tableView.reloadData()
        viewController.tableView.layoutIfNeeded()

        let rowRect = viewController.tableView.rectForRow(at: IndexPath(row: 0, section: 0))
        let pointInsideFirstRow = CGPoint(x: rowRect.midX, y: rowRect.midY)
        let interaction = UIContextMenuInteraction(delegate: viewController)
        let configuration = viewController.contextMenuInteraction(interaction, configurationForMenuAtLocation: pointInsideFirstRow)

        XCTAssertNotNil(configuration)
    }

    private func configureMixedProgressUser() {
        let completed = Unwrap.chapters[0].sections[0]
        let learnedOnly = Unwrap.chapters[0].sections[1]
        let reviewedOnly = Unwrap.chapters[0].sections[2]
        User.current = makeUser(
            learned: [completed.bundleName, learnedOnly.bundleName],
            reviewed: [completed.bundleName, reviewedOnly.bundleName]
        )
    }

    private func flattenedVisibleSections(from dataSource: LearnDataSource) -> [String] {
        return dataSource.visibleChapters.flatMap(\.sections)
    }

    private func makeUser(learned: Set<String> = [], reviewed: Set<String> = []) -> User {
        let payload: [String: Any] = [
            "streakDays": 1,
            "bestStreak": 1,
            "lastStreakEntry": 0,
            "learnedSections": Array(learned),
            "reviewedSections": Array(reviewed),
            "practiceSessions": ["storage": [String: Int]()],
            "practicePoints": 0,
            "dailyChallenges": [],
            "scoreShareCount": 0,
            "latestNewsArticle": 0,
            "articlesRead": [],
            "theme": "Light"
        ]

        let data = try! JSONSerialization.data(withJSONObject: payload)
        return try! JSONDecoder().decode(User.self, from: data)
    }

    private func findSegmentedControl(in viewController: LearnViewController) -> UISegmentedControl? {
        guard let headerView = viewController.tableView.tableHeaderView else { return nil }
        return findSegmentedControl(in: headerView)
    }

    private func findSegmentedControl(in view: UIView) -> UISegmentedControl? {
        if let segmentedControl = view as? UISegmentedControl {
            return segmentedControl
        }

        for subview in view.subviews {
            if let segmentedControl = findSegmentedControl(in: subview) {
                return segmentedControl
            }
        }

        return nil
    }

    private func performRegisteredFilterAction(from segmentedControl: UISegmentedControl, on viewController: LearnViewController) throws {
        let actionName = try XCTUnwrap(segmentedControl.actions(forTarget: viewController, forControlEvent: .valueChanged)?.first)
        let selector = NSSelectorFromString(actionName)

        if actionName.hasSuffix(":") {
            _ = viewController.perform(selector, with: segmentedControl)
        } else {
            _ = viewController.perform(selector)
        }
    }
}

private final class SpyLearnViewController: LearnViewController {
    var startedStudyingTitle: String?

    override func startStudying(title: String) {
        startedStudyingTitle = title
    }
}

private final class ReloadCountingTableView: UITableView {
    var reloadDataCallCount = 0

    override func reloadData() {
        reloadDataCallCount += 1
        super.reloadData()
    }
}
