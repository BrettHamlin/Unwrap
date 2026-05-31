//
//  LearnDataSourceTests.swift
//  UnwrapTests
//

import XCTest
@testable import Unwrap

class LearnDataSourceTests: XCTestCase {
    private let tableView = LearnDataSourceTests.makeTableView()

    func testFilterModeCasesAndLabels() {
        //harness:criterion=c-filter-enum-cases
        XCTAssertEqual(LearnFilterMode.allCases, [.all, .notStarted, .completed])
        XCTAssertEqual(LearnFilterMode.all.label, "All")
        XCTAssertEqual(LearnFilterMode.notStarted.label, "Not Started")
        XCTAssertEqual(LearnFilterMode.completed.label, "Completed")
    }

    func testDefaultFilterShowsEveryInjectedChapterAndRow() {
        //harness:criterion=c-filter-defaults-all,c-all-mode-shows-all-chapters,c-all-mode-shows-all-rows,c-chapters-source-injectable
        let chapters = [
            Chapter(name: "Basics", sections: ["One", "Two", "Three", "Four"]),
            Chapter(name: "Advanced", sections: ["Five", "Six"]),
            Chapter(name: "Patterns", sections: ["Seven"])
        ]

        let dataSource = LearnDataSource(chapters: chapters, user: user())

        XCTAssertEqual(dataSource.filterMode, .all)
        XCTAssertEqual(dataSource.numberOfSections(in: tableView), chapters.count)
        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: 0), 4)
        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: 1), 2)
        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: 2), 1)
    }

    func testNotStartedFilterIncludesOnlySectionsWithoutLearnedOrReviewedProgress() {
        //harness:criterion=c-not-started-excludes-learned,c-not-started-excludes-reviewed,c-not-started-includes-unstarted
        let learned = "Learned Section"
        let reviewed = "Reviewed Section"
        let unstarted = "Unstarted Section"
        let dataSource = LearnDataSource(
            chapters: [Chapter(name: "Progress", sections: [learned, reviewed, unstarted])],
            user: user(learned: [learned.bundleName], reviewed: [reviewed.bundleName])
        )

        dataSource.filterMode = .notStarted

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), 1)
        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: 0), 1)
        XCTAssertEqual(dataSource.title(for: IndexPath(row: 0, section: 0)), unstarted)
    }

    func testCompletedFilterIncludesOnlySectionsWithLearnedAndReviewedProgress() {
        //harness:criterion=c-completed-includes-fully-done,c-completed-excludes-learned-only,c-completed-excludes-reviewed-only,c-completed-excludes-unstarted
        let completed = "Completed Section"
        let learnedOnly = "Learned Only Section"
        let reviewedOnly = "Reviewed Only Section"
        let unstarted = "Fresh Section"
        let dataSource = LearnDataSource(
            chapters: [Chapter(name: "Progress", sections: [learnedOnly, reviewedOnly, unstarted, completed])],
            user: user(
                learned: [completed.bundleName, learnedOnly.bundleName],
                reviewed: [completed.bundleName, reviewedOnly.bundleName]
            )
        )

        dataSource.filterMode = .completed

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), 1)
        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: 0), 1)
        XCTAssertEqual(dataSource.title(for: IndexPath(row: 0, section: 0)), completed)
    }

    func testCompletedFilterHidesChapterWhenNoSectionsAreCompleted() {
        //harness:criterion=c-completed-excludes-learned-only,c-completed-excludes-reviewed-only,c-completed-excludes-unstarted,c-empty-chapter-hidden
        let learnedOnly = "Learned Only Section"
        let reviewedOnly = "Reviewed Only Section"
        let unstarted = "Fresh Section"
        let dataSource = LearnDataSource(
            chapters: [Chapter(name: "Incomplete", sections: [learnedOnly, reviewedOnly, unstarted])],
            user: user(learned: [learnedOnly.bundleName], reviewed: [reviewedOnly.bundleName])
        )

        dataSource.filterMode = .completed

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), 0)
        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: 0), 0)
    }

    func testNonAllFilterHidesEmptyChaptersAndShowsChaptersWithVisibleSections() throws {
        //harness:criterion=c-empty-chapter-hidden,c-chapter-with-visible-sections-shown,c-header-maps-correct-chapter,c-single-mapping-helper
        let hiddenSection = "Already Started"
        let firstVisibleSection = "Ready One"
        let secondVisibleSection = "Ready Two"
        let dataSource = LearnDataSource(
            chapters: [
                Chapter(name: "Hidden Chapter", sections: [hiddenSection]),
                Chapter(name: "First Visible Chapter", sections: [firstVisibleSection]),
                Chapter(name: "Second Visible Chapter", sections: [secondVisibleSection])
            ],
            user: user(learned: [hiddenSection.bundleName])
        )

        dataSource.filterMode = .notStarted

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), 2)

        let firstHeader = try XCTUnwrap(dataSource.tableView(tableView, viewForHeaderInSection: 0) as? DynamicHeightHeaderView)
        let secondHeader = try XCTUnwrap(dataSource.tableView(tableView, viewForHeaderInSection: 1) as? DynamicHeightHeaderView)
        XCTAssertEqual(firstHeader.headerLabel.text, "First Visible Chapter")
        XCTAssertEqual(secondHeader.headerLabel.text, "Second Visible Chapter")
    }

    func testFilteredCellTitleAndSelectionUseUnderlyingVisibleSection() {
        //harness:criterion=c-cell-resolves-underlying-section,c-title-for-resolves-underlying-section,c-did-select-resolves-underlying-section,c-single-mapping-helper
        let hiddenSection = "Raw Row Zero"
        let visibleSection = "Underlying Visible Row"
        let dataSource = LearnDataSource(
            chapters: [Chapter(name: "Rows", sections: [hiddenSection, visibleSection])],
            user: user(learned: [hiddenSection.bundleName])
        )
        let delegate = SpyLearnViewController(style: .plain)
        dataSource.delegate = delegate
        dataSource.filterMode = .notStarted

        let filteredIndexPath = IndexPath(row: 0, section: 0)
        let cell = dataSource.tableView(tableView, cellForRowAt: filteredIndexPath)
        dataSource.tableView(tableView, didSelectRowAt: filteredIndexPath)

        XCTAssertEqual(cell.textLabel?.text, visibleSection)
        XCTAssertEqual(dataSource.title(for: filteredIndexPath), visibleSection)
        XCTAssertEqual(delegate.startedTitle, visibleSection)
    }

    func testLearnViewControllerRendersDefaultFilterControl() throws {
        //harness:criterion=c-filter-control-rendered,c-filter-control-defaults-all-segment
        let viewController = makeLearnViewController()
        let control = try XCTUnwrap(filterControl(in: viewController))

        XCTAssertEqual(control.numberOfSegments, 3)
        XCTAssertEqual(control.titleForSegment(at: 0), "All")
        XCTAssertEqual(control.titleForSegment(at: 1), "Not Started")
        XCTAssertEqual(control.titleForSegment(at: 2), "Completed")
        XCTAssertEqual(control.selectedSegmentIndex, LearnFilterMode.all.rawValue)
        XCTAssertEqual(control.accessibilityLabel, "Learn filter")
        XCTAssertEqual(control.accessibilityValue, "All")
    }

    func testFilterControlSelectionUpdatesDataSourceAndReloadsTable() throws {
        //harness:criterion=c-filter-control-updates-datasource
        let viewController = makeLearnViewController()
        let control = try XCTUnwrap(filterControl(in: viewController))
        let tableView = ReloadTrackingTableView()
        viewController.tableView = tableView

        for mode in LearnFilterMode.allCases {
            control.selectedSegmentIndex = mode.rawValue
            viewController.perform(Selector(("filterChanged")))

            XCTAssertEqual(viewController.dataSource.filterMode, mode)
            XCTAssertEqual(control.accessibilityValue, mode.label)
        }

        XCTAssertEqual(tableView.reloadDataCallCount, LearnFilterMode.allCases.count)
    }

    func testUserDataChangedReloadsDataForNonAllFiltersAndPreservesAllModeReloadRows() throws {
        //harness:criterion=c-user-data-changed-reloads-non-all,c-user-data-changed-preserves-all-mode
        let viewController = makeLearnViewController()
        let control = try XCTUnwrap(filterControl(in: viewController))
        let tableView = ReloadTrackingTableView()
        tableView.stubbedVisibleRows = [IndexPath(row: 0, section: 0)]
        viewController.tableView = tableView

        viewController.dataSource.filterMode = .all
        viewController.userDataChanged()
        XCTAssertEqual(tableView.reloadRowsCallCount, 1)
        XCTAssertEqual(tableView.reloadDataCallCount, 0)

        control.selectedSegmentIndex = LearnFilterMode.notStarted.rawValue
        viewController.perform(Selector(("filterChanged")))
        tableView.resetCounts()

        viewController.userDataChanged()
        XCTAssertEqual(viewController.dataSource.filterMode, .notStarted)
        XCTAssertEqual(tableView.reloadRowsCallCount, 0)
        XCTAssertEqual(tableView.reloadDataCallCount, 1)
    }

    func testFilterModeIsLocalToEachLearnViewControllerInstance() throws {
        //harness:criterion=c-filter-state-not-persisted
        let firstViewController = makeLearnViewController()
        let firstControl = try XCTUnwrap(filterControl(in: firstViewController))
        firstControl.selectedSegmentIndex = LearnFilterMode.completed.rawValue
        firstViewController.perform(Selector(("filterChanged")))
        XCTAssertEqual(firstViewController.dataSource.filterMode, .completed)

        let secondViewController = makeLearnViewController()
        let secondControl = try XCTUnwrap(filterControl(in: secondViewController))
        XCTAssertEqual(secondViewController.dataSource.filterMode, .all)
        XCTAssertEqual(secondControl.selectedSegmentIndex, LearnFilterMode.all.rawValue)
    }

    private static func makeTableView() -> UITableView {
        let tableView = UITableView()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
        return tableView
    }

    private func makeLearnViewController() -> LearnViewController {
        let viewController = LearnViewController(style: .plain)
        viewController.coordinator = LearnCoordinator()
        viewController.loadViewIfNeeded()
        return viewController
    }

    private func filterControl(in viewController: LearnViewController) -> UISegmentedControl? {
        return viewController.tableView.tableHeaderView?.subviews.compactMap { $0 as? UISegmentedControl }.first
    }

    private func user(learned: [String] = [], reviewed: [String] = []) -> User {
        let payload: [String: Any] = [
            "streakDays": 1,
            "bestStreak": 1,
            "lastStreakEntry": 0,
            "learnedSections": learned,
            "reviewedSections": reviewed,
            "practiceSessions": ["storage": [String: Int]()] as [String: Any],
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
}

private final class SpyLearnViewController: LearnViewController {
    var startedTitle: String?

    override func startStudying(title: String) {
        startedTitle = title
    }
}

private final class ReloadTrackingTableView: UITableView {
    var reloadDataCallCount = 0
    var reloadRowsCallCount = 0
    var stubbedVisibleRows: [IndexPath]?

    override var indexPathsForVisibleRows: [IndexPath]? {
        return stubbedVisibleRows
    }

    override func reloadData() {
        reloadDataCallCount += 1
    }

    override func reloadRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation) {
        reloadRowsCallCount += 1
    }

    func resetCounts() {
        reloadDataCallCount = 0
        reloadRowsCallCount = 0
    }
}
