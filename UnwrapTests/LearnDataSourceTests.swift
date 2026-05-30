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
        tableView = UITableView()
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
    }

    override func tearDown() {
        tableView = nil

        super.tearDown()
    }

    func testFilterModeCasesAndLabels() {
        //harness:criterion=c-learn-filter-mode-enum-cases
        XCTAssertEqual(LearnFilterMode.allCases.count, 3)
        XCTAssertEqual(LearnFilterMode.allCases, [.all, .notStarted, .completed])
        XCTAssertEqual(LearnFilterMode.all.label, "All")
        XCTAssertEqual(LearnFilterMode.notStarted.label, "Not Started")
        XCTAssertEqual(LearnFilterMode.completed.label, "Completed")
    }

    func testDefaultAllFilterPreservesChapterAndSectionOrderAndDoesNotMutateChapters() {
        //harness:criterion=c-learn-filter-mode-default-all,c-learn-filter-all-preserves-chapter-count,c-learn-filter-all-preserves-section-order,c-learn-filter-chapters-not-mutated
        let originalSnapshot = chapterSnapshot()
        let dataSource = LearnDataSource()

        XCTAssertEqual(dataSource.filterMode, .all)
        XCTAssertEqual(dataSource.numberOfSections(in: tableView), Unwrap.chapters.count)

        for (chapterIndex, chapter) in Unwrap.chapters.enumerated() {
            XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: chapterIndex), chapter.sections.count)

            for (sectionIndex, title) in chapter.sections.enumerated() {
                XCTAssertEqual(dataSource.title(for: IndexPath(row: sectionIndex, section: chapterIndex)), title)
            }
        }

        dataSource.filterMode = .notStarted
        _ = visibleTitles(in: dataSource)
        dataSource.filterMode = .completed
        _ = visibleTitles(in: dataSource)
        dataSource.filterMode = .all
        _ = visibleTitles(in: dataSource)

        XCTAssertEqual(chapterSnapshot(), originalSnapshot)
    }

    func testNotStartedFilterIncludesOnlyUnstartedSections() {
        //harness:criterion=c-learn-filter-not-started-excludes-learned,c-learn-filter-not-started-excludes-reviewed,c-learn-filter-not-started-includes-unstarted
        let titles = allSectionTitles()
        XCTAssertGreaterThanOrEqual(titles.count, 3)

        User.current.learnedSection(titles[0].bundleName)
        User.current.reviewedSection(titles[1].bundleName)

        let dataSource = LearnDataSource()
        dataSource.filterMode = .notStarted

        let visible = visibleTitles(in: dataSource)
        let expected = titles.filter { title in
            User.current.hasLearned(title.bundleName) == false && User.current.hasReviewed(title.bundleName) == false
        }

        XCTAssertFalse(visible.contains(titles[0]))
        XCTAssertFalse(visible.contains(titles[1]))
        XCTAssertEqual(visible, expected)
        XCTAssertTrue(visible.allSatisfy { title in
            User.current.hasLearned(title.bundleName) == false && User.current.hasReviewed(title.bundleName) == false
        })
    }

    func testCompletedFilterIncludesOnlyLearnedAndReviewedSections() {
        //harness:criterion=c-learn-filter-completed-includes-both-done,c-learn-filter-completed-excludes-in-progress,c-learn-filter-completed-excludes-not-started
        let titles = allSectionTitles()
        XCTAssertGreaterThanOrEqual(titles.count, 3)

        User.current.reviewedSection(titles[0].bundleName)
        User.current.learnedSection(titles[1].bundleName)

        let dataSource = LearnDataSource()
        dataSource.filterMode = .completed

        let visible = visibleTitles(in: dataSource)
        let expected = titles.filter { title in
            User.current.hasLearned(title.bundleName) && User.current.hasReviewed(title.bundleName)
        }

        XCTAssertEqual(visible, expected)
        XCTAssertTrue(visible.allSatisfy { title in
            User.current.hasLearned(title.bundleName) && User.current.hasReviewed(title.bundleName)
        })
        XCTAssertFalse(visible.contains(titles[1]))
        XCTAssertFalse(visible.contains(titles[2]))
    }

    func testFilteredChaptersHeadersAndRowCountsUseVisibleMapping() {
        //harness:criterion=c-learn-filter-empty-chapter-hidden,c-learn-filter-header-maps-to-original-chapter,c-learn-filter-number-of-rows-matches-filtered-count
        let hiddenChapterIndex = 0
        let rowCountChapterIndex = Unwrap.chapters.indices.first { index in
            index != hiddenChapterIndex && Unwrap.chapters[index].sections.count >= 2
        }

        XCTAssertNotNil(rowCountChapterIndex)

        for title in Unwrap.chapters[hiddenChapterIndex].sections {
            User.current.learnedSection(title.bundleName)
        }

        if let rowCountChapterIndex = rowCountChapterIndex {
            User.current.learnedSection(Unwrap.chapters[rowCountChapterIndex].sections[0].bundleName)
        }

        let dataSource = LearnDataSource()
        dataSource.filterMode = .notStarted

        let expectedVisibleChapters = Unwrap.chapters.enumerated().compactMap { chapterIndex, chapter -> (name: String, rowCount: Int)? in
            let visibleCount = chapter.sections.filter { title in
                User.current.hasLearned(title.bundleName) == false && User.current.hasReviewed(title.bundleName) == false
            }.count

            guard visibleCount > 0 else { return nil }
            return (chapter.name, visibleCount)
        }

        XCTAssertLessThan(dataSource.numberOfSections(in: tableView), Unwrap.chapters.count)
        XCTAssertEqual(dataSource.numberOfSections(in: tableView), expectedVisibleChapters.count)

        for sectionIndex in 0..<dataSource.numberOfSections(in: tableView) {
            let headerView = dataSource.tableView(tableView, viewForHeaderInSection: sectionIndex) as? DynamicHeightHeaderView

            XCTAssertEqual(headerView?.headerLabel.text, expectedVisibleChapters[sectionIndex].name)
            XCTAssertNotEqual(headerView?.headerLabel.text, Unwrap.chapters[hiddenChapterIndex].name)
            XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: sectionIndex), expectedVisibleChapters[sectionIndex].rowCount)
        }
    }

    func testFilteredIndexPathsResolveOriginalTitlesForSelectionAndContextMenus() {
        //harness:criterion=c-learn-filter-row-resolves-correct-title,c-learn-filter-did-select-navigates-correct-section,c-learn-filter-context-menu-correct-title
        let targetChapterIndex = Unwrap.chapters.indices.first { Unwrap.chapters[$0].sections.count >= 2 }
        XCTAssertNotNil(targetChapterIndex)

        guard let targetChapterIndex = targetChapterIndex else { return }

        let firstTitle = Unwrap.chapters[targetChapterIndex].sections[0]
        let expectedTitle = Unwrap.chapters[targetChapterIndex].sections[1]
        User.current.learnedSection(firstTitle.bundleName)

        let dataSource = LearnDataSource()
        dataSource.filterMode = .notStarted

        let visibleSectionIndex = visibleChapterIndices(for: dataSource)[targetChapterIndex]
        XCTAssertNotNil(visibleSectionIndex)

        guard let visibleSectionIndex = visibleSectionIndex else { return }

        let filteredIndexPath = IndexPath(row: 0, section: visibleSectionIndex)
        XCTAssertEqual(dataSource.title(for: filteredIndexPath), expectedTitle)

        let spyViewController = SpyLearnViewController(style: .plain)
        dataSource.delegate = spyViewController
        dataSource.tableView(tableView, didSelectRowAt: filteredIndexPath)
        XCTAssertEqual(spyViewController.startedTitle, expectedTitle)

        User.current = User()
        let completedTitles = Array(allSectionTitles().prefix(2))
        completedTitles.forEach { User.current.reviewedSection($0.bundleName) }

        let completedDataSource = LearnDataSource()
        completedDataSource.filterMode = .completed
        XCTAssertEqual(visibleTitles(in: completedDataSource), completedTitles)
    }

    func testLearnViewControllerAddsSegmentedFilterControl() {
        //harness:criterion=c-learn-segmented-control-three-segments,c-learn-segmented-control-default-selected
        let viewController = makeLearnViewController()
        let segmentedControl = findSegmentedControl(in: viewController.view)

        XCTAssertNotNil(segmentedControl)
        XCTAssertEqual(segmentedControl?.numberOfSegments, 3)
        XCTAssertEqual(segmentedControl?.titleForSegment(at: 0), "All")
        XCTAssertEqual(segmentedControl?.titleForSegment(at: 1), "Not Started")
        XCTAssertEqual(segmentedControl?.titleForSegment(at: 2), "Completed")
        XCTAssertEqual(segmentedControl?.selectedSegmentIndex, 0)
        XCTAssertEqual(segmentedControl?.accessibilityLabel, "Learn filter")
        XCTAssertEqual(segmentedControl?.accessibilityValue, "All")
    }

    func testChangingSegmentedControlUpdatesFilterAndReloadsTable() {
        //harness:criterion=c-learn-segmented-control-value-change-updates-filter
        let viewController = makeLearnViewController()
        let segmentedControl = findSegmentedControl(in: viewController.view)
        let reloadTrackingTableView = ReloadTrackingTableView()

        XCTAssertNotNil(segmentedControl)
        viewController.tableView = reloadTrackingTableView
        reloadTrackingTableView.reloadDataCallCount = 0

        segmentedControl?.selectedSegmentIndex = 1
        viewController.filterChanged(segmentedControl!)
        XCTAssertEqual(viewController.dataSource.filterMode, .notStarted)
        XCTAssertEqual(segmentedControl?.accessibilityValue, "Not Started")
        XCTAssertEqual(reloadTrackingTableView.reloadDataCallCount, 1)

        segmentedControl?.selectedSegmentIndex = 2
        viewController.filterChanged(segmentedControl!)
        XCTAssertEqual(viewController.dataSource.filterMode, .completed)
        XCTAssertEqual(segmentedControl?.accessibilityValue, "Completed")
        XCTAssertEqual(reloadTrackingTableView.reloadDataCallCount, 2)

        segmentedControl?.selectedSegmentIndex = 0
        viewController.filterChanged(segmentedControl!)
        XCTAssertEqual(viewController.dataSource.filterMode, .all)
        XCTAssertEqual(segmentedControl?.accessibilityValue, "All")
        XCTAssertEqual(reloadTrackingTableView.reloadDataCallCount, 3)
    }

    func testUserDataChangedReloadsAndReflectsProgressChanges() {
        //harness:criterion=c-learn-user-data-changed-reloads-data
        let viewController = makeLearnViewController()
        let reloadTrackingTableView = ReloadTrackingTableView()
        let title = allSectionTitles()[0]

        viewController.tableView = reloadTrackingTableView
        viewController.dataSource.filterMode = .notStarted
        XCTAssertTrue(visibleTitles(in: viewController.dataSource).contains(title))

        reloadTrackingTableView.reloadDataCallCount = 0
        User.current.learnedSection(title.bundleName)
        viewController.userDataChanged()

        XCTAssertEqual(reloadTrackingTableView.reloadDataCallCount, 1)
        XCTAssertFalse(visibleTitles(in: viewController.dataSource).contains(title))
    }

    private func allSectionTitles() -> [String] {
        return Unwrap.chapters.flatMap { $0.sections }
    }

    private func visibleTitles(in dataSource: LearnDataSource) -> [String] {
        var titles = [String]()

        for section in 0..<dataSource.numberOfSections(in: tableView) {
            for row in 0..<dataSource.tableView(tableView, numberOfRowsInSection: section) {
                titles.append(dataSource.title(for: IndexPath(row: row, section: section)))
            }
        }

        return titles
    }

    private func visibleChapterIndices(for dataSource: LearnDataSource) -> [Int: Int] {
        var result = [Int: Int]()

        for visibleSection in 0..<dataSource.numberOfSections(in: tableView) {
            guard let headerView = dataSource.tableView(tableView, viewForHeaderInSection: visibleSection) as? DynamicHeightHeaderView else {
                continue
            }

            if let chapterIndex = Unwrap.chapters.firstIndex(where: { $0.name == headerView.headerLabel.text }) {
                result[chapterIndex] = visibleSection
            }
        }

        return result
    }

    private func chapterSnapshot() -> [String] {
        return Unwrap.chapters.flatMap { chapter in
            [chapter.name] + chapter.sections
        }
    }

    private func makeLearnViewController() -> LearnViewController {
        let viewController = LearnViewController(style: .plain)
        viewController.coordinator = LearnCoordinator()
        viewController.loadViewIfNeeded()
        return viewController
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
}

private final class SpyLearnViewController: LearnViewController {
    var startedTitle: String?

    override func startStudying(title: String) {
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
