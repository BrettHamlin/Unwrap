//
//  LearnDataSourceTests.swift
//  UnwrapTests
//

import XCTest
@testable import Unwrap

class LearnDataSourceTests: XCTestCase {
    private var tableView: UITableView!

    override func setUp() {
        super.setUp()
        User.current = User()
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
    }

    override func tearDown() {
        tableView = nil
        User.current = User()
        super.tearDown()
    }

    //harness:criterion=c-learn-filter-enum-cases
    func testLearnFilterCasesAreExhaustive() {
        XCTAssertEqual(describe(.all), "all")
        XCTAssertEqual(describe(.notStarted), "notStarted")
        XCTAssertEqual(describe(.completed), "completed")
    }

    //harness:criterion=c-learn-filter-default-all
    func testDefaultFilterIsAll() {
        let dataSource = LearnDataSource()

        XCTAssertEqual(dataSource.filter, .all)
        XCTAssertEqual(dataSource.filteredChapters.count, Unwrap.chapters.count)
        XCTAssertEqual(dataSource.filteredChapters.map(\.name), Unwrap.chapters.map(\.name))
    }

    //harness:criterion=c-learn-filter-all-section-count,c-learn-filter-all-row-count
    func testAllFilterShowsEveryChapterAndSection() {
        let dataSource = makeDataSource(filter: .all)
        let totalRows = (0..<dataSource.numberOfSections(in: tableView)).reduce(0) { result, section in
            result + dataSource.tableView(tableView, numberOfRowsInSection: section)
        }

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), Unwrap.chapters.count)
        XCTAssertEqual(totalRows, Unwrap.chapters.flatMap(\.sections).count)
    }

    //harness:criterion=c-learn-filter-not-started-excludes-learned,c-learn-filter-not-started-section-count,c-learn-filter-not-started-row-count,c-learn-filter-hides-empty-chapters,c-learn-filter-not-started-excludes-reviewed-and-learned
    func testNotStartedFilterCountsRowsAndHidesFullyLearnedChapters() throws {
        let excludedChapter = try XCTUnwrap(Unwrap.chapters.first)
        markLearned(excludedChapter.sections)

        let mixedChapter = try XCTUnwrap(Unwrap.chapters.dropFirst().first { $0.sections.count > 1 })
        markLearned([mixedChapter.sections[0]])
        markReviewed([mixedChapter.sections[1]])

        let dataSource = makeDataSource(filter: .notStarted)
        let expected = expectedChapters(for: .notStarted)

        XCTAssertLessThan(dataSource.numberOfSections(in: tableView), Unwrap.chapters.count)
        XCTAssertEqual(dataSource.numberOfSections(in: tableView), expected.count)
        XCTAssertFalse((0..<dataSource.numberOfSections(in: tableView)).contains { dataSource.title(for: $0) == excludedChapter.name })

        for (index, chapter) in expected.enumerated() {
            XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: index), chapter.sections.count)
        }

        for section in dataSource.filteredChapters.flatMap(\.sections) {
            XCTAssertFalse(User.current.hasLearned(section.bundleName))
        }
    }

    //harness:criterion=c-learn-filter-completed-requires-both-flags,c-learn-filter-completed-section-count,c-learn-filter-completed-row-count,c-learn-filter-completed-excludes-learned-only
    func testCompletedFilterRequiresLearnedAndReviewedSections() throws {
        let completedChapter = try XCTUnwrap(Unwrap.chapters.first { $0.sections.count > 1 })
        markLearned([completedChapter.sections[0]])
        markReviewed([completedChapter.sections[1]])

        let otherChapter = try XCTUnwrap(Unwrap.chapters.first { $0.name != completedChapter.name && !$0.sections.isEmpty })
        markReviewed([otherChapter.sections[0]])

        let dataSource = makeDataSource(filter: .completed)
        let expected = expectedChapters(for: .completed)

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), expected.count)

        for (index, chapter) in expected.enumerated() {
            XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: index), chapter.sections.count)
        }

        for section in dataSource.filteredChapters.flatMap(\.sections) {
            XCTAssertTrue(User.current.hasLearned(section.bundleName))
            XCTAssertTrue(User.current.hasReviewed(section.bundleName))
        }
    }

    //harness:criterion=c-learn-filter-preserves-order
    func testFilterPreservesOriginalChapterAndSectionOrder() throws {
        let firstMultiSectionChapter = try XCTUnwrap(Unwrap.chapters.first { $0.sections.count > 2 })
        markLearned([firstMultiSectionChapter.sections[0]])
        markReviewed([firstMultiSectionChapter.sections[1]])

        for filter in [LearnFilter.all, .notStarted, .completed] {
            let dataSource = makeDataSource(filter: filter)
            let expected = expectedChapters(for: filter)

            XCTAssertEqual(dataSource.filteredChapters.map(\.name), expected.map(\.name))
            XCTAssertEqual(dataSource.filteredChapters.map(\.sections), expected.map(\.sections))
        }
    }

    //harness:criterion=c-learn-filter-did-select-resolves-correct-section
    func testDidSelectResolvesCorrectOriginalSectionAfterFiltering() throws {
        let fixture = try makeShiftedFirstVisibleSectionFixture()
        let dataSource = makeDataSource(filter: .notStarted)
        let delegate = CapturingLearnViewController(style: .plain)
        dataSource.delegate = delegate

        dataSource.tableView(tableView, didSelectRowAt: IndexPath(row: 0, section: 0))

        XCTAssertEqual(delegate.startedTitle, fixture.expectedFirstVisibleSection)
    }

    //harness:criterion=c-learn-datasource-title-uses-filtered-list,c-learn-datasource-header-uses-filtered-list,c-learn-datasource-cell-uses-filtered-list
    func testTitleHeaderAndCellUseFilteredList() throws {
        let fixture = try makeShiftedFirstVisibleSectionFixture()
        let dataSource = makeDataSource(filter: .notStarted)

        XCTAssertEqual(dataSource.title(for: 0), fixture.expectedFirstVisibleChapter)
        XCTAssertNotEqual(dataSource.title(for: 0), Unwrap.chapters[0].name)

        let header = try XCTUnwrap(dataSource.tableView(tableView, viewForHeaderInSection: 0) as? DynamicHeightHeaderView)
        XCTAssertEqual(header.headerLabel.text, fixture.expectedFirstVisibleChapter)

        let cell = dataSource.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(cell.textLabel?.text, fixture.expectedFirstVisibleSection)
        XCTAssertNotEqual(cell.textLabel?.text, Unwrap.chapters[0].sections[0])
    }

    //harness:criterion=c-learn-user-status-changed-recomputes-filter
    func testUserStatusChangedRecomputesActiveFilter() throws {
        let viewController = makeLoadedViewController()
        viewController.dataSource.filter = .notStarted
        let chapterToRemove = try XCTUnwrap(Unwrap.chapters.first)

        markLearned(chapterToRemove.sections)
        NotificationCenter.default.post(name: .userStatusChanged, object: nil)

        let expectedCount = expectedChapters(for: .notStarted).count
        XCTAssertEqual(viewController.dataSource.numberOfSections(in: tableView), expectedCount)
        XCTAssertFalse(viewController.dataSource.filteredChapters.contains { $0.name == chapterToRemove.name })
    }

    //harness:criterion=c-learn-segmented-control-three-segments,c-learn-segmented-control-default-selection,c-learn-segmented-control-glossary-preserved
    func testSegmentedControlConfigurationAndGlossaryButton() throws {
        let viewController = makeLoadedViewController()
        let control = try XCTUnwrap(viewController.view.firstSubview(ofType: UISegmentedControl.self))

        XCTAssertEqual(control.numberOfSegments, 3)
        XCTAssertEqual(control.titleForSegment(at: 0), "All")
        XCTAssertEqual(control.titleForSegment(at: 1), "Not Started")
        XCTAssertEqual(control.titleForSegment(at: 2), "Completed")
        XCTAssertEqual(control.selectedSegmentIndex, 0)
        XCTAssertEqual(control.accessibilityLabel, "Learn filter")
        XCTAssertEqual(control.accessibilityValue, "All")
        XCTAssertEqual(viewController.navigationItem.rightBarButtonItem?.title, "Glossary")
    }

    //harness:criterion=c-learn-segmented-control-updates-filter
    func testSegmentedControlUpdatesFilter() {
        let viewController = LearnViewController(style: .plain)

        viewController.filterControl.selectedSegmentIndex = 1
        viewController.filterChanged()
        XCTAssertEqual(viewController.dataSource.filter, .notStarted)
        XCTAssertEqual(viewController.filterControl.accessibilityValue, "Not Started")

        viewController.filterControl.selectedSegmentIndex = 2
        viewController.filterChanged()
        XCTAssertEqual(viewController.dataSource.filter, .completed)
        XCTAssertEqual(viewController.filterControl.accessibilityValue, "Completed")

        viewController.filterControl.selectedSegmentIndex = 0
        viewController.filterChanged()
        XCTAssertEqual(viewController.dataSource.filter, .all)
        XCTAssertEqual(viewController.filterControl.accessibilityValue, "All")
    }

    //harness:criterion=c-learn-segmented-control-triggers-reload
    func testSegmentedControlChangeTriggersTableReload() {
        let viewController = LearnViewController(style: .plain)
        let tableView = ReloadTrackingTableView(frame: .zero, style: .plain)
        viewController.tableView = tableView

        viewController.filterControl.selectedSegmentIndex = 1
        viewController.filterChanged()

        XCTAssertEqual(tableView.reloadDataCallCount, 1)
    }

    //harness:criterion=c-learn-user-data-changed-full-reload
    func testUserDataChangedPerformsFullTableReload() {
        let viewController = LearnViewController(style: .plain)
        let tableView = ReloadTrackingTableView(frame: .zero, style: .plain)
        viewController.tableView = tableView

        viewController.userDataChanged()

        XCTAssertEqual(tableView.reloadDataCallCount, 1)
        XCTAssertEqual(tableView.reloadRowsCallCount, 0)
        XCTAssertEqual(tableView.reloadSectionsCallCount, 0)
    }

    //harness:criterion=c-learn-filter-context-menu-resolves-correct-section
    func testContextMenuUsesFilteredSectionTitle() throws {
        let fixture = try makeShiftedFirstVisibleSectionFixture()
        let viewController = LearnViewController(style: .plain)
        let tableView = FixedIndexPathTableView(frame: .zero, style: .plain)
        let coordinator = RecordingLearnCoordinator()
        tableView.fixedIndexPath = IndexPath(row: 0, section: 0)
        viewController.tableView = tableView
        viewController.coordinator = coordinator
        viewController.dataSource.filter = .notStarted

        _ = viewController.contextMenuInteraction(UIContextMenuInteraction(delegate: viewController), configurationForMenuAtLocation: .zero)

        XCTAssertEqual(coordinator.requestedStudyTitle, fixture.expectedFirstVisibleSection)
    }

    private func describe(_ filter: LearnFilter) -> String {
        switch filter {
        case .all:
            return "all"
        case .notStarted:
            return "notStarted"
        case .completed:
            return "completed"
        }
    }

    private func makeDataSource(filter: LearnFilter) -> LearnDataSource {
        let dataSource = LearnDataSource()
        dataSource.filter = filter
        return dataSource
    }

    private func markLearned(_ sections: [String]) {
        sections.forEach { User.current.learnedSection($0.bundleName) }
    }

    private func markReviewed(_ sections: [String]) {
        sections.forEach { User.current.reviewedSection($0.bundleName) }
    }

    private func expectedChapters(for filter: LearnFilter) -> [Chapter] {
        switch filter {
        case .all:
            return Unwrap.chapters
        case .notStarted:
            return filteredChapters { !User.current.hasLearned($0.bundleName) }
        case .completed:
            return filteredChapters { User.current.hasLearned($0.bundleName) && User.current.hasReviewed($0.bundleName) }
        }
    }

    private func filteredChapters(_ isIncluded: (String) -> Bool) -> [Chapter] {
        return Unwrap.chapters.compactMap { chapter in
            let sections = chapter.sections.filter(isIncluded)
            return sections.isEmpty ? nil : Chapter(name: chapter.name, sections: sections)
        }
    }

    private func makeShiftedFirstVisibleSectionFixture() throws -> (expectedFirstVisibleChapter: String, expectedFirstVisibleSection: String) {
        let targetChapterIndex = try XCTUnwrap(Unwrap.chapters.firstIndex { $0.sections.count > 1 })

        for chapter in Unwrap.chapters[..<targetChapterIndex] {
            markLearned(chapter.sections)
        }

        let targetChapter = Unwrap.chapters[targetChapterIndex]
        markLearned([targetChapter.sections[0]])

        return (targetChapter.name, targetChapter.sections[1])
    }

    private func makeLoadedViewController() -> LearnViewController {
        let viewController = LearnViewController(style: .plain)
        viewController.coordinator = LearnCoordinator()
        viewController.loadViewIfNeeded()
        return viewController
    }
}

private final class CapturingLearnViewController: LearnViewController {
    var startedTitle: String?

    override func startStudying(title: String) {
        startedTitle = title
    }
}

private final class RecordingLearnCoordinator: LearnCoordinator {
    var requestedStudyTitle: String?

    override func studyViewController(for title: String) -> StudyViewController {
        requestedStudyTitle = title
        return StudyViewController()
    }
}

private final class ReloadTrackingTableView: UITableView {
    var reloadDataCallCount = 0
    var reloadRowsCallCount = 0
    var reloadSectionsCallCount = 0

    override func reloadData() {
        reloadDataCallCount += 1
    }

    override func reloadRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation) {
        reloadRowsCallCount += 1
    }

    override func reloadSections(_ sections: IndexSet, with animation: UITableView.RowAnimation) {
        reloadSectionsCallCount += 1
    }
}

private final class FixedIndexPathTableView: UITableView {
    var fixedIndexPath: IndexPath?

    override func indexPathForRow(at point: CGPoint) -> IndexPath? {
        return fixedIndexPath
    }
}

private extension UIView {
    func firstSubview<T: UIView>(ofType type: T.Type) -> T? {
        if let view = self as? T {
            return view
        }

        for subview in subviews {
            if let match = subview.firstSubview(ofType: type) {
                return match
            }
        }

        return nil
    }
}
