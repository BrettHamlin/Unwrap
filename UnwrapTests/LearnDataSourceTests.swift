//
//  LearnDataSourceTests.swift
//  UnwrapTests
//
//  Created by OpenAI on 30/05/2026.
//  Copyright 2026 Hacking with Swift. All rights reserved.
//

import XCTest
@testable import Unwrap

class LearnDataSourceTests: XCTestCase {

    private func makeTableView() -> UITableView {
        let tableView = ReloadTrackingTableView()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
        return tableView
    }

    private func makeChapters() -> [Chapter] {
        return [
            Chapter(name: "Basics", sections: ["Constants", "Variables"]),
            Chapter(name: "Collections", sections: ["Arrays", "Dictionaries", "Sets"]),
            Chapter(name: "Functions", sections: ["Parameters"])
        ]
    }

    private func makeDataSource(chapters: [Chapter], user: User = User()) -> LearnDataSource {
        return LearnDataSource(chapters: chapters, user: user)
    }

    //harness:criterion=c-learn-progress-filter-enum-cases
    func testLearnProgressFilterExhaustiveCases() {
        let filters: [LearnProgressFilter] = [.all, .notStarted, .completed]
        let names = filters.map { filter -> String in
            switch filter {
            case .all:
                return "all"

            case .notStarted:
                return "notStarted"

            case .completed:
                return "completed"
            }
        }

        XCTAssertEqual(filters.count, 3)
        XCTAssertEqual(names, ["all", "notStarted", "completed"])
    }

    //harness:criterion=c-learn-datasource-accepts-injected-chapters-user,c-learn-datasource-filter-property-exists,c-learn-filter-all-returns-all-chapters
    func testInjectedChaptersAndDefaultAllFilterReturnAllSections() {
        let chapters = makeChapters()
        let user = User()
        user.learnedSection("Constants".bundleName)
        user.reviewedSection("Arrays".bundleName)

        let dataSource = makeDataSource(chapters: chapters, user: user)
        let tableView = makeTableView()

        XCTAssertEqual(dataSource.filter, .all)
        XCTAssertEqual(dataSource.numberOfSections(in: tableView), chapters.count)
    }

    //harness:criterion=c-learn-filter-all-returns-all-rows
    func testAllFilterReturnsEveryRowInEachChapter() {
        let chapters = [
            Chapter(name: "Basics", sections: ["Constants", "Variables"]),
            Chapter(name: "Collections", sections: ["Arrays", "Dictionaries", "Sets"])
        ]
        let user = User()
        user.learnedSection("Constants".bundleName)
        user.reviewedSection("Arrays".bundleName)

        let dataSource = makeDataSource(chapters: chapters, user: user)
        let tableView = makeTableView()
        dataSource.filter = .all

        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: 0), 2)
        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: 1), 3)
    }

    //harness:criterion=c-learn-datasource-visible-chapters-recomputed-on-filter-set
    func testSettingFilterRecomputesVisibleChaptersBeforeNextRead() {
        let chapters = [Chapter(name: "Basics", sections: ["Constants"])]
        let user = User()
        user.learnedSection("Constants".bundleName)
        let dataSource = makeDataSource(chapters: chapters, user: user)
        let tableView = makeTableView()

        dataSource.filter = .all
        let allCount = dataSource.numberOfSections(in: tableView)
        dataSource.filter = .notStarted
        let notStartedCount = dataSource.numberOfSections(in: tableView)

        XCTAssertEqual(allCount, 1)
        XCTAssertEqual(notStartedCount, 0)
    }

    //harness:criterion=c-learn-filter-not-started-hides-learned-sections
    func testNotStartedFilterExcludesLearnedSections() {
        let chapters = [Chapter(name: "Basics", sections: ["Constants", "Variables"])]
        let user = User()
        user.learnedSection("Constants".bundleName)
        let dataSource = makeDataSource(chapters: chapters, user: user)
        let tableView = makeTableView()

        dataSource.filter = .notStarted

        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: 0), 1)
        XCTAssertEqual(dataSource.title(for: IndexPath(row: 0, section: 0)), "Variables")
    }

    //harness:criterion=c-learn-filter-not-started-hides-reviewed-sections
    func testNotStartedFilterExcludesReviewedSections() {
        let chapters = [Chapter(name: "Basics", sections: ["Constants", "Variables"])]
        let user = User()
        user.reviewedSection("Constants".bundleName)
        let dataSource = makeDataSource(chapters: chapters, user: user)
        let tableView = makeTableView()

        dataSource.filter = .notStarted

        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: 0), 1)
        XCTAssertEqual(dataSource.title(for: IndexPath(row: 0, section: 0)), "Variables")
    }

    //harness:criterion=c-learn-filter-completed-shows-only-reviewed-sections
    func testCompletedFilterIncludesOnlyReviewedSections() {
        let chapters = [Chapter(name: "Basics", sections: ["Constants", "Variables", "Operators"])]
        let user = User()
        user.learnedSection("Constants".bundleName)
        user.reviewedSection("Variables".bundleName)
        let dataSource = makeDataSource(chapters: chapters, user: user)
        let tableView = makeTableView()

        dataSource.filter = .completed

        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: 0), 1)
        XCTAssertEqual(dataSource.title(for: IndexPath(row: 0, section: 0)), "Variables")
    }

    //harness:criterion=c-learn-filter-empty-chapters-hidden
    func testFilterHidesChaptersWithNoVisibleSections() {
        let chapters = [
            Chapter(name: "Basics", sections: ["Constants"]),
            Chapter(name: "Collections", sections: ["Arrays"])
        ]
        let user = User()
        user.learnedSection("Constants".bundleName)
        let dataSource = makeDataSource(chapters: chapters, user: user)
        let tableView = makeTableView()

        dataSource.filter = .notStarted

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), 1)
        XCTAssertEqual(dataSource.title(for: IndexPath(row: 0, section: 0)), "Arrays")
    }

    //harness:criterion=c-learn-filter-row-selection-resolves-correct-section,c-learn-selection-delegate-protocol-introduced
    func testSelectionAfterFilteringUsesOriginalSectionTitleThroughProtocolDelegate() {
        let chapters = [
            Chapter(name: "Basics", sections: ["Constants", "Variables"]),
            Chapter(name: "Collections", sections: ["Arrays", "Dictionaries"])
        ]
        let user = User()
        user.learnedSection("Constants".bundleName)
        let dataSource = makeDataSource(chapters: chapters, user: user)
        let tableView = makeTableView()
        let delegate = SpyLearnSelectionDelegate()

        dataSource.delegate = delegate
        dataSource.filter = .notStarted
        dataSource.tableView(tableView, didSelectRowAt: IndexPath(row: 0, section: 0))

        XCTAssertEqual(delegate.startedTitles, ["Variables"])
    }

    //harness:criterion=c-learn-filter-header-reads-visible-chapters,c-learn-filter-title-reads-visible-chapters
    func testHeaderAndTitleUseFilteredChapterIndexes() {
        let chapters = [
            Chapter(name: "Basics", sections: ["Constants"]),
            Chapter(name: "Collections", sections: ["Arrays"])
        ]
        let user = User()
        user.learnedSection("Constants".bundleName)
        let dataSource = makeDataSource(chapters: chapters, user: user)
        let tableView = makeTableView()

        dataSource.filter = .notStarted

        let header = dataSource.tableView(tableView, viewForHeaderInSection: 0) as? DynamicHeightHeaderView
        XCTAssertEqual(header?.headerLabel.text, "Collections")
        XCTAssertEqual(dataSource.title(for: IndexPath(row: 0, section: 0)), "Arrays")
    }

    //harness:criterion=c-learn-filter-cell-reads-visible-chapters
    func testCellUsesFilteredSectionIndexes() {
        let chapters = [Chapter(name: "Basics", sections: ["Constants", "Variables"])]
        let user = User()
        user.learnedSection("Constants".bundleName)
        let dataSource = makeDataSource(chapters: chapters, user: user)
        let tableView = makeTableView()

        dataSource.filter = .notStarted
        let cell = dataSource.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: 0))

        XCTAssertEqual(cell.textLabel?.text, "Variables")
        XCTAssertEqual(cell.textLabel?.accessibilityLabel, "Variables. Section not started")
    }

    //harness:criterion=c-learn-filter-not-started-all-sections-unstarted
    func testNotStartedFilterKeepsEveryChapterWhenNoSectionsAreStarted() {
        let chapters = makeChapters()
        let dataSource = makeDataSource(chapters: chapters)
        let tableView = makeTableView()

        dataSource.filter = .all
        let allCount = dataSource.numberOfSections(in: tableView)
        dataSource.filter = .notStarted
        let notStartedCount = dataSource.numberOfSections(in: tableView)

        XCTAssertEqual(notStartedCount, allCount)
    }

    //harness:criterion=c-learn-filter-completed-no-reviewed-sections-empty
    func testCompletedFilterHasNoSectionsWhenNothingIsReviewed() {
        let dataSource = makeDataSource(chapters: makeChapters())
        let tableView = makeTableView()

        dataSource.filter = .completed

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), 0)
    }

    //harness:criterion=c-learn-segmented-control-three-segments,c-learn-segmented-control-defaults-to-all,c-learn-glossary-button-preserved
    func testLearnViewControllerConfiguresProgressFilterAndKeepsGlossaryButton() {
        let coordinator = SpyLearnCoordinator()
        let viewController = makeLearnViewController(coordinator: coordinator)

        XCTAssertEqual(viewController.progressFilterControl.numberOfSegments, 3)
        XCTAssertEqual(viewController.progressFilterControl.titleForSegment(at: 0), "All")
        XCTAssertEqual(viewController.progressFilterControl.titleForSegment(at: 1), "Not Started")
        XCTAssertEqual(viewController.progressFilterControl.titleForSegment(at: 2), "Completed")
        XCTAssertEqual(viewController.progressFilterControl.selectedSegmentIndex, 0)
        XCTAssertTrue(viewController.navigationItem.titleView === viewController.progressFilterControl)
        XCTAssertEqual(viewController.progressFilterControl.accessibilityLabel, "Learn filter")
        XCTAssertEqual(viewController.progressFilterControl.accessibilityValue, "All")
        XCTAssertNotNil(viewController.navigationItem.rightBarButtonItem)
        XCTAssertEqual(viewController.navigationItem.rightBarButtonItem?.action, #selector(LearnViewController.showGlossary))
        viewController.showGlossary()
        XCTAssertTrue(coordinator.glossaryShown)
    }

    //harness:criterion=c-learn-segmented-control-updates-filter-and-reloads
    func testChangingProgressFilterUpdatesDataSourceAndReloadsTable() {
        let tableView = ReloadTrackingTableView()
        let viewController = makeLearnViewController(tableView: tableView)

        tableView.reloadDataCallCount = 0
        viewController.progressFilterControl.selectedSegmentIndex = 1
        viewController.progressFilterChanged()

        XCTAssertEqual(viewController.dataSource.filter, .notStarted)
        XCTAssertEqual(viewController.progressFilterControl.accessibilityValue, "Not Started")
        XCTAssertEqual(tableView.reloadDataCallCount, 1)

        viewController.progressFilterControl.selectedSegmentIndex = 2
        viewController.progressFilterChanged()

        XCTAssertEqual(viewController.dataSource.filter, .completed)
        XCTAssertEqual(viewController.progressFilterControl.accessibilityValue, "Completed")
        XCTAssertEqual(tableView.reloadDataCallCount, 2)
    }

    //harness:criterion=c-learn-user-data-changed-calls-reload-data
    func testUserDataChangedReloadsTableAndPreservesSelectedFilter() {
        let chapters = [Chapter(name: "Basics", sections: ["Constants"])]
        let user = User()
        let dataSource = makeDataSource(chapters: chapters, user: user)
        let tableView = ReloadTrackingTableView()
        let viewController = makeLearnViewController(dataSource: dataSource, tableView: tableView)

        viewController.progressFilterControl.selectedSegmentIndex = 2
        viewController.progressFilterChanged()
        XCTAssertEqual(dataSource.numberOfSections(in: tableView), 0)

        user.reviewedSection("Constants".bundleName)
        tableView.reloadDataCallCount = 0
        viewController.userDataChanged()

        XCTAssertEqual(viewController.dataSource.filter, .completed)
        XCTAssertEqual(dataSource.numberOfSections(in: tableView), 1)
        XCTAssertEqual(viewController.progressFilterControl.selectedSegmentIndex, 2)
        XCTAssertEqual(viewController.progressFilterControl.accessibilityValue, "Completed")
        XCTAssertGreaterThanOrEqual(tableView.reloadDataCallCount, 1)
    }

    //harness:criterion=c-learn-context-menu-reads-visible-chapters
    func testContextMenuPreviewUsesFilteredSectionTitle() {
        let chapters = [
            Chapter(name: "Basics", sections: ["Constants"]),
            Chapter(name: "Collections", sections: ["Arrays"])
        ]
        let user = User()
        user.learnedSection("Constants".bundleName)
        let dataSource = makeDataSource(chapters: chapters, user: user)
        dataSource.filter = .notStarted

        let tableView = FixedIndexPathTableView()
        tableView.fixedIndexPath = IndexPath(row: 0, section: 0)
        let coordinator = SpyLearnCoordinator()
        let viewController = makeLearnViewController(dataSource: dataSource, tableView: tableView, coordinator: coordinator)
        let configuration = viewController.contextMenuInteraction(UIContextMenuInteraction(delegate: viewController), configurationForMenuAtLocation: .zero)

        XCTAssertNotNil(configuration)
        XCTAssertEqual(coordinator.previewedTitles, ["Arrays"])
    }

    private func makeLearnViewController(dataSource: LearnDataSource = LearnDataSource(chapters: [], user: User()), tableView: UITableView = ReloadTrackingTableView(), coordinator: LearnCoordinator = SpyLearnCoordinator()) -> LearnViewController {
        let viewController = LearnViewController(style: .plain)
        viewController.coordinator = coordinator
        viewController.dataSource = dataSource
        viewController.tableView = tableView
        _ = viewController.view
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
        return viewController
    }
}

private final class SpyLearnSelectionDelegate: LearnSelectionDelegate {
    var startedTitles = [String]()

    func startStudying(title: String) {
        startedTitles.append(title)
    }
}

private class ReloadTrackingTableView: UITableView {
    var reloadDataCallCount = 0

    override func reloadData() {
        reloadDataCallCount += 1
        super.reloadData()
    }
}

private final class FixedIndexPathTableView: ReloadTrackingTableView {
    var fixedIndexPath: IndexPath?

    override func indexPathForRow(at point: CGPoint) -> IndexPath? {
        return fixedIndexPath
    }
}

private final class SpyLearnCoordinator: LearnCoordinator {
    var previewedTitles = [String]()
    var startedTitles = [String]()
    var glossaryShown = false

    override func studyViewController(for title: String) -> StudyViewController {
        previewedTitles.append(title)
        let viewController = StudyViewController()
        viewController.title = title
        viewController.chapter = title.bundleName
        return viewController
    }

    override func startStudying(title: String) {
        startedTitles.append(title)
    }

    override func showGlossary() {
        glossaryShown = true
    }
}
