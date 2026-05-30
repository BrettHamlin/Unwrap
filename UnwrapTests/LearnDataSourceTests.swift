//
//  LearnDataSourceTests.swift
//  UnwrapTests
//
//  Created by OpenAI on 30/05/2026.
//

import UIKit
import XCTest
@testable import Unwrap

class LearnDataSourceTests: XCTestCase {
    private var originalUser: User?
    private var tableView: UITableView!

    override func setUp() {
        super.setUp()
        originalUser = User.current
        User.current = User()
        tableView = UITableView(frame: CGRect(x: 0, y: 0, width: 320, height: 640), style: .plain)
    }

    override func tearDown() {
        tableView = nil
        User.current = originalUser
        originalUser = nil
        super.tearDown()
    }

    // harness:criterion=c-learn-progress-filter-enum-cases
    func testProgressFilterHasExactlyTheExpectedCases() {
        XCTAssertEqual(LearnProgressFilter.allCases, [.all, .notStarted, .completed])
        XCTAssertEqual(LearnProgressFilter.allCases.count, 3)
    }

    // harness:criterion=c-learn-datasource-injectable-chapters,c-learn-datasource-default-filter-all,c-learn-all-filter-shows-all-chapters,c-learn-all-filter-shows-all-rows
    func testDefaultAllFilterShowsEveryInjectedChapterAndSection() {
        let chapters = makeChapters([
            ("Basics", ["Variables", "Constants"]),
            ("Collections", ["Arrays", "Dictionaries", "Sets"]),
            ("Flow", ["Loops"])
        ])
        let dataSource = makeDataSource(chapters: chapters, ratingsByTitle: [
            "Variables": 0,
            "Constants": 100,
            "Arrays": 200,
            "Dictionaries": 0,
            "Sets": 200,
            "Loops": 100
        ])

        XCTAssertEqual(dataSource.currentFilter, .all)
        XCTAssertEqual(dataSource.numberOfSections(in: tableView), 3)
        XCTAssertEqual(totalVisibleRows(in: dataSource), 6)
        XCTAssertEqual(visibleTitles(in: dataSource), [
            ["Variables", "Constants"],
            ["Arrays", "Dictionaries", "Sets"],
            ["Loops"]
        ])
    }

    // harness:criterion=c-learn-datasource-injectable-progress
    func testInjectedProgressProviderControlsCompletedFilterResults() {
        let chapters = makeChapters([
            ("Basics", ["Variables", "Constants"]),
            ("Collections", ["Arrays", "Dictionaries"])
        ])
        let dataSource = makeDataSource(chapters: chapters, ratingsByTitle: [
            "Variables": 200,
            "Constants": 200,
            "Arrays": 200,
            "Dictionaries": 200
        ])

        dataSource.currentFilter = .completed

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), 2)
        XCTAssertEqual(totalVisibleRows(in: dataSource), 4)
    }

    // harness:criterion=c-learn-datasource-filter-not-started,c-learn-not-started-chapter-partially-visible
    func testNotStartedFilterShowsOnlySectionsWithZeroRating() {
        let chapters = makeChapters([
            ("Basics", ["Variables", "Constants", "Operators"]),
            ("Collections", ["Arrays", "Dictionaries"])
        ])
        let dataSource = makeDataSource(chapters: chapters, ratingsByTitle: [
            "Variables": 0,
            "Constants": 100,
            "Operators": 0,
            "Arrays": 200,
            "Dictionaries": 0
        ])

        dataSource.currentFilter = .notStarted

        XCTAssertEqual(totalVisibleRows(in: dataSource), 3)
        XCTAssertEqual(visibleTitles(in: dataSource), [
            ["Variables", "Operators"],
            ["Dictionaries"]
        ])
        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: 0), 2)
    }

    // harness:criterion=c-learn-datasource-filter-completed,c-learn-completed-chapter-partially-visible
    func testCompletedFilterShowsOnlySectionsWithFullRating() {
        let chapters = makeChapters([
            ("Basics", ["Variables", "Constants", "Operators"]),
            ("Collections", ["Arrays", "Dictionaries"])
        ])
        let dataSource = makeDataSource(chapters: chapters, ratingsByTitle: [
            "Variables": 200,
            "Constants": 0,
            "Operators": 200,
            "Arrays": 100,
            "Dictionaries": 200
        ])

        dataSource.currentFilter = .completed

        XCTAssertEqual(totalVisibleRows(in: dataSource), 3)
        XCTAssertEqual(visibleTitles(in: dataSource), [
            ["Variables", "Operators"],
            ["Dictionaries"]
        ])
        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: 0), 2)
    }

    // harness:criterion=c-learn-datasource-empty-chapter-hidden
    func testFilteredOutChaptersAreHidden() {
        let chapters = makeChapters([
            ("Basics", ["Variables", "Constants"]),
            ("Collections", ["Arrays", "Dictionaries"]),
            ("Flow", ["Loops"])
        ])
        let dataSource = makeDataSource(chapters: chapters, ratingsByTitle: [
            "Variables": 0,
            "Constants": 0,
            "Arrays": 200,
            "Dictionaries": 200,
            "Loops": 0
        ])

        dataSource.currentFilter = .completed

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), 1)
        XCTAssertEqual(visibleTitles(in: dataSource), [["Arrays", "Dictionaries"]])
    }

    // harness:criterion=c-learn-datasource-row-resolves-correct-section,c-learn-datasource-title-resolves-correct-section
    func testFilteredIndexPathResolvesToCorrectUnderlyingSectionForTitleAndSelection() {
        let chapters = makeChapters([
            ("Basics", ["Alpha", "Beta", "Gamma"])
        ])
        let dataSource = makeDataSource(chapters: chapters, ratingsByTitle: [
            "Alpha": 0,
            "Beta": 200,
            "Gamma": 0
        ])
        let delegate = SelectionSpy()
        dataSource.delegate = delegate
        dataSource.currentFilter = .notStarted
        let indexPath = IndexPath(row: 1, section: 0)

        XCTAssertEqual(dataSource.title(for: indexPath), "Gamma")

        dataSource.tableView(tableView, didSelectRowAt: indexPath)

        XCTAssertEqual(delegate.startedTitle, "Gamma")
    }

    // harness:criterion=c-learn-datasource-current-filter-triggers-recompute
    func testChangingCurrentFilterImmediatelyRecomputesVisibleChapters() {
        let chapters = makeChapters([
            ("Basics", ["Variables", "Constants"]),
            ("Collections", ["Arrays", "Dictionaries"])
        ])
        let dataSource = makeDataSource(chapters: chapters, ratingsByTitle: [
            "Variables": 0,
            "Constants": 200,
            "Arrays": 200,
            "Dictionaries": 200
        ])

        XCTAssertEqual(dataSource.currentFilter, .all)
        XCTAssertEqual(dataSource.numberOfSections(in: tableView), 2)

        dataSource.currentFilter = .notStarted

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), 1)
        XCTAssertEqual(visibleTitles(in: dataSource), [["Variables"]])
    }

    // harness:criterion=c-learn-viewcontroller-segmented-control-exists,c-learn-segmented-control-default-selection
    func testLearnViewControllerConfiguresProgressFilterControl() throws {
        let (viewController, _) = makeLoadedLearnViewController()

        let control = try XCTUnwrap(viewController.navigationItem.titleView as? UISegmentedControl)

        XCTAssertEqual(control.numberOfSegments, 3)
        XCTAssertEqual(segmentTitles(in: control), ["All", "Not Started", "Completed"])
        XCTAssertEqual(control.selectedSegmentIndex, 0)
        XCTAssertEqual(viewController.dataSource.currentFilter, .all)
        XCTAssertEqual(control.accessibilityLabel, "Learn filter")
        XCTAssertEqual(control.accessibilityValue, "All")
    }

    // harness:criterion=c-learn-segmented-control-updates-filter,c-learn-segmented-control-reloads-table
    func testChangingProgressFilterControlUpdatesDataSourceAndReloadsTable() throws {
        let (viewController, _) = makeLoadedLearnViewController()
        let control = try XCTUnwrap(viewController.navigationItem.titleView as? UISegmentedControl)
        let trackingTableView = ReloadTrackingTableView(frame: tableView.frame, style: .plain)
        viewController.tableView = trackingTableView

        control.selectedSegmentIndex = 1
        performValueChangedAction(from: control, on: viewController)

        XCTAssertEqual(viewController.dataSource.currentFilter, .notStarted)
        XCTAssertEqual(control.accessibilityValue, "Not Started")
        XCTAssertEqual(trackingTableView.reloadDataCallCount, 1)

        control.selectedSegmentIndex = 2
        performValueChangedAction(from: control, on: viewController)

        XCTAssertEqual(viewController.dataSource.currentFilter, .completed)
        XCTAssertEqual(control.accessibilityValue, "Completed")
        XCTAssertEqual(trackingTableView.reloadDataCallCount, 2)
    }

    // harness:criterion=c-learn-user-data-changed-reloads-full-table
    func testUserDataChangedReloadsTheFullTable() {
        let (viewController, _) = makeLoadedLearnViewController()
        let trackingTableView = ReloadTrackingTableView(frame: tableView.frame, style: .plain)
        viewController.tableView = trackingTableView
        viewController.dataSource.currentFilter = .notStarted

        viewController.userDataChanged()

        XCTAssertEqual(trackingTableView.reloadDataCallCount, 1)
    }

    // harness:criterion=c-learn-context-menu-uses-filtered-model
    func testContextMenuPreviewRequestsSameTitleAsFilteredDataSourceLookup() {
        let (viewController, coordinator) = makeLoadedLearnViewController()
        let indexPath = IndexPath(row: 0, section: 0)
        viewController.dataSource.currentFilter = .notStarted
        viewController.tableView.reloadData()
        viewController.tableView.layoutIfNeeded()
        let rowRect = viewController.tableView.rectForRow(at: indexPath)
        let expectedTitle = viewController.dataSource.title(for: indexPath)
        let interaction = UIContextMenuInteraction(delegate: viewController)

        let configuration = viewController.contextMenuInteraction(
            interaction,
            configurationForMenuAtLocation: CGPoint(x: rowRect.midX, y: rowRect.midY)
        )

        XCTAssertNotNil(configuration)
        XCTAssertEqual(coordinator.requestedStudyTitle, expectedTitle)
    }

    private func makeChapters(_ definitions: [(String, [String])]) -> [Chapter] {
        return definitions.map { Chapter(name: $0.0, sections: $0.1) }
    }

    private func makeDataSource(chapters: [Chapter], ratingsByTitle: [String: Int]) -> LearnDataSource {
        var ratings = [String: Int]()

        for (title, rating) in ratingsByTitle {
            ratings[title] = rating
            ratings[title.bundleName] = rating
        }

        return LearnDataSource(chapters: chapters, progressProvider: StubProgressProvider(ratings: ratings))
    }

    private func totalVisibleRows(in dataSource: LearnDataSource) -> Int {
        return (0..<dataSource.numberOfSections(in: tableView)).reduce(0) { total, section in
            total + dataSource.tableView(tableView, numberOfRowsInSection: section)
        }
    }

    private func visibleTitles(in dataSource: LearnDataSource) -> [[String]] {
        return (0..<dataSource.numberOfSections(in: tableView)).map { section in
            (0..<dataSource.tableView(tableView, numberOfRowsInSection: section)).map { row in
                dataSource.title(for: IndexPath(row: row, section: section))
            }
        }
    }

    private func makeLoadedLearnViewController() -> (LearnViewController, SpyLearnCoordinator) {
        User.current = User()
        let coordinator = SpyLearnCoordinator()
        let viewController = LearnViewController(style: .plain)
        viewController.coordinator = coordinator
        viewController.loadViewIfNeeded()
        viewController.tableView.frame = tableView.frame
        return (viewController, coordinator)
    }

    private func segmentTitles(in control: UISegmentedControl) -> [String] {
        return (0..<control.numberOfSegments).compactMap { control.titleForSegment(at: $0) }
    }

    private func performValueChangedAction(from control: UISegmentedControl, on viewController: LearnViewController) {
        let actions = control.actions(forTarget: viewController, forControlEvent: .valueChanged) ?? []
        XCTAssertEqual(actions.count, 1)

        guard let action = actions.first else { return }
        _ = viewController.perform(NSSelectorFromString(action), with: control)
    }
}

private final class StubProgressProvider: LearnProgressProviding {
    private let ratings: [String: Int]

    init(ratings: [String: Int]) {
        self.ratings = ratings
    }

    func ratingForSection(_ section: String) -> Int {
        return ratings[section] ?? 0
    }
}

private final class SelectionSpy: LearnDataSourceDelegate {
    private(set) var startedTitle: String?

    func startStudying(title: String) {
        startedTitle = title
    }
}

private final class ReloadTrackingTableView: UITableView {
    private(set) var reloadDataCallCount = 0

    override func reloadData() {
        reloadDataCallCount += 1
        super.reloadData()
    }
}

private final class SpyLearnCoordinator: LearnCoordinator {
    private(set) var requestedStudyTitle: String?

    override func studyViewController(for title: String) -> StudyViewController {
        requestedStudyTitle = title

        let viewController = StudyViewController()
        viewController.title = title
        viewController.chapter = title.bundleName
        return viewController
    }
}
