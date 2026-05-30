//
//  LearnDataSourceTests.swift
//  UnwrapTests
//
//  Created by Codex on 30/05/2026.
//

import XCTest
@testable import Unwrap

class LearnDataSourceTests: XCTestCase {
    func testLearnFilterCasesAndDefaultFilter() {
        //harness:criterion=c-learn-filter-enum-cases,c-learn-datasource-filter-default-all
        let cases = LearnFilter.allCases

        XCTAssertEqual(cases.count, 3)
        XCTAssertEqual(cases.map { String(describing: $0) }, ["all", "notStarted", "completed"])
        XCTAssertEqual(LearnDataSource().filter, .all)
    }

    func testAllFilterUsesInjectedChaptersAndPreservesOrder() {
        //harness:criterion=c-learn-datasource-all-shows-every-chapter,c-learn-datasource-all-preserves-order,c-learn-datasource-injectable-chapters
        let chapters = [
            Chapter(name: "First Chapter", sections: ["First Section", "Second Section"]),
            Chapter(name: "Second Chapter", sections: ["Third Section", "Fourth Section"])
        ]
        let dataSource = LearnDataSource(chapters: chapters, userProgress: StubProgress())

        dataSource.filter = .all

        XCTAssertEqual(dataSource.displayedChapters.count, chapters.count)
        XCTAssertEqual(dataSource.displayedChapters.map { $0.name }, ["First Chapter", "Second Chapter"])
        XCTAssertEqual(dataSource.displayedChapters[0].sections, ["First Section", "Second Section"])
        XCTAssertEqual(dataSource.displayedChapters[1].sections, ["Third Section", "Fourth Section"])
    }

    func testNotStartedFilterUsesInjectedProgress() {
        //harness:criterion=c-learn-datasource-not-started-hides-learned,c-learn-datasource-not-started-hides-reviewed,c-learn-datasource-not-started-shows-untouched,c-learn-datasource-injectable-user-progress
        let originalUser: User? = User.current
        let learned = "Learned Section"
        let reviewed = "Reviewed Section"
        let untouched = "Untouched Section"
        let progress = StubProgress(
            learned: [learned.bundleName],
            reviewed: [reviewed.bundleName]
        )
        let dataSource = LearnDataSource(
            chapters: [Chapter(name: "Mixed Chapter", sections: [learned, reviewed, untouched])],
            userProgress: progress
        )

        dataSource.filter = .notStarted

        XCTAssertEqual(sectionTitles(in: dataSource), [untouched])
        let currentUserAfterFiltering: User? = User.current
        XCTAssertTrue(currentUserAfterFiltering === originalUser)
    }

    func testCompletedFilterShowsOnlySectionsWithLearnedAndReviewedProgress() {
        //harness:criterion=c-learn-datasource-completed-shows-both-true,c-learn-datasource-completed-hides-partial
        let completed = "Completed Section"
        let learnedOnly = "Learned Only Section"
        let reviewedOnly = "Reviewed Only Section"
        let untouched = "Untouched Section"
        let progress = StubProgress(
            learned: [completed.bundleName, learnedOnly.bundleName],
            reviewed: [completed.bundleName, reviewedOnly.bundleName]
        )
        let dataSource = LearnDataSource(
            chapters: [Chapter(name: "Mixed Chapter", sections: [learnedOnly, completed, reviewedOnly, untouched])],
            userProgress: progress
        )

        dataSource.filter = .completed

        XCTAssertEqual(sectionTitles(in: dataSource), [completed])
    }

    func testFiltersHideEmptyResultsAndEmptyChapters() {
        //harness:criterion=c-learn-datasource-empty-chapters-hidden,c-learn-filter-not-started-empty-result,c-learn-filter-completed-empty-result
        let learned = "Learned Section"
        let reviewed = "Reviewed Section"
        let untouched = "Untouched Section"
        let progress = StubProgress(
            learned: [learned.bundleName],
            reviewed: [reviewed.bundleName]
        )
        let dataSource = LearnDataSource(
            chapters: [
                Chapter(name: "Hidden Chapter", sections: [learned, reviewed]),
                Chapter(name: "Visible Chapter", sections: [untouched])
            ],
            userProgress: progress
        )

        dataSource.filter = .notStarted

        XCTAssertEqual(dataSource.displayedChapters.count, 1)
        XCTAssertEqual(dataSource.displayedChapters.first?.name, "Visible Chapter")

        progress.learned.insert(untouched.bundleName)

        XCTAssertTrue(dataSource.displayedChapters.isEmpty)

        progress.learned.removeAll()
        progress.reviewed.removeAll()
        dataSource.filter = .completed

        XCTAssertTrue(dataSource.displayedChapters.isEmpty)
    }

    func testTableDataSourceMethodsUseDisplayedChapters() {
        //harness:criterion=c-learn-datasource-number-of-sections,c-learn-datasource-number-of-rows,c-learn-datasource-cell-for-row,c-learn-datasource-title-for-section,c-learn-datasource-title-after-filter,c-learn-datasource-did-select-row,c-learn-datasource-did-select-after-filter,c-learn-datasource-header-view
        let filteredOut = "Filtered Out Section"
        let survivorOne = "Survivor One"
        let survivorTwo = "Survivor Two"
        let progress = StubProgress(learned: [filteredOut.bundleName])
        let dataSource = LearnDataSource(
            chapters: [
                Chapter(name: "Hidden Chapter", sections: [filteredOut]),
                Chapter(name: "Displayed Chapter", sections: [survivorOne, survivorTwo])
            ],
            userProgress: progress
        )
        let tableView = makeTableView()
        let delegate = LearnDataSourceDelegateSpy()

        dataSource.delegate = delegate
        dataSource.filter = .notStarted

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), dataSource.displayedChapters.count)
        XCTAssertEqual(dataSource.numberOfSections(in: tableView), 1)
        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: 0), 2)

        let cell = dataSource.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(cell.textLabel?.text, survivorOne)

        XCTAssertEqual(dataSource.title(for: IndexPath(row: 0, section: 0)), survivorOne)
        XCTAssertNotEqual(dataSource.title(for: IndexPath(row: 0, section: 0)), filteredOut)

        dataSource.tableView(tableView, didSelectRowAt: IndexPath(row: 1, section: 0))
        XCTAssertEqual(delegate.startedTitle, survivorTwo)

        guard let headerView = dataSource.tableView(tableView, viewForHeaderInSection: 0) as? DynamicHeightHeaderView else {
            XCTFail("Expected a DynamicHeightHeaderView")
            return
        }

        XCTAssertEqual(headerView.headerLabel.text, "Displayed Chapter")
    }

    func testLearnViewControllerCreatesSegmentedFilterControl() {
        //harness:criterion=c-learn-segmented-control-exists,c-learn-segmented-control-default-all,c-learn-segmented-control-placement
        let viewController = makeLoadedLearnViewController()
        let filterControl = viewController.filterControl

        XCTAssertEqual(filterControl.numberOfSegments, 3)
        XCTAssertEqual(filterControl.titleForSegment(at: 0), "All")
        XCTAssertEqual(filterControl.titleForSegment(at: 1), "Not Started")
        XCTAssertEqual(filterControl.titleForSegment(at: 2), "Completed")
        XCTAssertEqual(filterControl.selectedSegmentIndex, 0)
        XCTAssertEqual(filterControl.accessibilityLabel, "Learn filter")
        XCTAssertEqual(filterControl.accessibilityValue, "All")
        XCTAssertTrue(viewController.tableView.tableHeaderView?.subviews.contains { $0 === filterControl } == true)
    }

    func testLearnViewControllerSegmentChangesUpdateFilterAndReload() {
        //harness:criterion=c-learn-segmented-control-updates-filter,c-learn-segmented-control-triggers-reload
        let viewController = makeLoadedLearnViewController()
        let tableView = ReloadTrackingTableView(frame: .zero, style: .plain)
        let filterControl = viewController.filterControl

        viewController.tableView = tableView

        filterControl.selectedSegmentIndex = 1
        viewController.learnFilterChanged(filterControl)

        XCTAssertEqual(viewController.dataSource.filter, .notStarted)
        XCTAssertEqual(filterControl.accessibilityValue, "Not Started")
        XCTAssertEqual(tableView.reloadDataCallCount, 1)

        filterControl.selectedSegmentIndex = 2
        viewController.learnFilterChanged(filterControl)

        XCTAssertEqual(viewController.dataSource.filter, .completed)
        XCTAssertEqual(filterControl.accessibilityValue, "Completed")
        XCTAssertEqual(tableView.reloadDataCallCount, 2)

        filterControl.selectedSegmentIndex = 0
        viewController.learnFilterChanged(filterControl)

        XCTAssertEqual(viewController.dataSource.filter, .all)
        XCTAssertEqual(filterControl.accessibilityValue, "All")
        XCTAssertEqual(tableView.reloadDataCallCount, 3)
    }

    func testUserDataChangedPerformsFullReloadWhileFilteredDataRecomputes() {
        //harness:criterion=c-learn-user-data-changed-full-reload,c-learn-user-data-changed-filter-active
        let viewController = makeLoadedLearnViewController()
        let tableView = ReloadTrackingTableView(frame: .zero, style: .plain)

        viewController.tableView = tableView
        viewController.userDataChanged()

        XCTAssertEqual(tableView.reloadDataCallCount, 1)

        let changingSection = "Changing Progress Section"
        let progress = StubProgress()
        let dataSource = LearnDataSource(
            chapters: [Chapter(name: "Changing Chapter", sections: [changingSection])],
            userProgress: progress
        )

        dataSource.filter = .notStarted
        XCTAssertEqual(sectionTitles(in: dataSource), [changingSection])

        progress.learned.insert(changingSection.bundleName)
        tableView.dataSource = dataSource
        tableView.reloadData()

        XCTAssertTrue(dataSource.displayedChapters.isEmpty)
        XCTAssertEqual(tableView.reloadDataCallCount, 2)
    }

    func testContextMenuUsesDataSourceTitleForSelectedIndexPath() throws {
        //harness:criterion=c-learn-context-menu-correct-section
        let coordinator = LearnCoordinatorSpy()
        let viewController = LearnViewController(style: .plain)
        let tableView = FixedIndexPathTableView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), style: .plain)
        let interaction = UIContextMenuInteraction(delegate: viewController)
        let originalUser: User? = User.current
        let chapter = try XCTUnwrap(Unwrap.chapters.first { $0.sections.count > 1 })
        let filteredOut = chapter.sections[0]
        let expectedTitle = chapter.sections[1]

        User.current = try makeUser(learned: [filteredOut.bundleName])
        defer {
            User.current = originalUser
        }

        viewController.coordinator = coordinator
        viewController.loadViewIfNeeded()
        viewController.dataSource.filter = .notStarted
        viewController.tableView = tableView
        tableView.fixedIndexPath = IndexPath(row: 0, section: 0)

        let configuration = viewController.contextMenuInteraction(interaction, configurationForMenuAtLocation: CGPoint(x: 10, y: 10))

        XCTAssertNotNil(configuration)
        XCTAssertEqual(coordinator.requestedStudyTitle, expectedTitle)
        XCTAssertNotEqual(coordinator.requestedStudyTitle, filteredOut)
    }

    private func sectionTitles(in dataSource: LearnDataSource) -> [String] {
        return dataSource.displayedChapters.flatMap { $0.sections }
    }

    private func makeTableView() -> UITableView {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
        return tableView
    }

    private func makeLoadedLearnViewController() -> LearnViewController {
        let viewController = LearnViewController(style: .plain)
        viewController.coordinator = LearnCoordinatorSpy()
        viewController.loadViewIfNeeded()
        return viewController
    }

    private func makeUser(learned: Set<String> = [], reviewed: Set<String> = []) throws -> User {
        let payload: [String: Any] = [
            "streakDays": 1,
            "bestStreak": 1,
            "lastStreakEntry": 0.0,
            "learnedSections": Array(learned),
            "reviewedSections": Array(reviewed),
            "practiceSessions": ["storage": [String: Int]()],
            "practicePoints": 0,
            "dailyChallenges": [] as [Any],
            "scoreShareCount": 0,
            "latestNewsArticle": 0,
            "articlesRead": [] as [Any],
            "theme": "Light"
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)

        return try JSONDecoder().decode(User.self, from: data)
    }
}

private final class StubProgress: LearnProgressProviding {
    var learned: Set<String>
    var reviewed: Set<String>

    init(learned: Set<String> = [], reviewed: Set<String> = []) {
        self.learned = learned
        self.reviewed = reviewed
    }

    func ratingForSection(_ section: String) -> Int {
        var score = 0

        if hasLearned(section) {
            score += User.pointsForLearning
        }

        if hasReviewed(section) {
            score += User.pointsForReviewing
        }

        return score
    }

    func hasLearned(_ section: String) -> Bool {
        return learned.contains(section)
    }

    func hasReviewed(_ section: String) -> Bool {
        return reviewed.contains(section)
    }
}

private final class LearnDataSourceDelegateSpy: LearnDataSourceDelegate {
    var startedTitle: String?

    func startStudying(title: String) {
        startedTitle = title
    }
}

private final class ReloadTrackingTableView: UITableView {
    var reloadDataCallCount = 0

    override func reloadData() {
        reloadDataCallCount += 1
        super.reloadData()
    }
}

private final class FixedIndexPathTableView: UITableView {
    var fixedIndexPath: IndexPath?

    override func indexPathForRow(at point: CGPoint) -> IndexPath? {
        return fixedIndexPath
    }
}

private final class LearnCoordinatorSpy: LearnCoordinator {
    var requestedStudyTitle: String?

    override func studyViewController(for title: String) -> StudyViewController {
        requestedStudyTitle = title
        let viewController = StudyViewController()
        viewController.title = title
        return viewController
    }
}
