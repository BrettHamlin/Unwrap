//
//  LearnDataSourceTests.swift
//  UnwrapTests
//
//  Created by OpenAI on 30/05/2026.
//  Copyright © 2026 Hacking with Swift. All rights reserved.
//

import XCTest
@testable import Unwrap

class LearnDataSourceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        User.current = User()
    }

    override func tearDown() {
        User.current = User()
        super.tearDown()
    }

    //harness:criterion=c-filter-enum-three-modes,c-filter-default-all
    func testFilterModeHasThreeCasesAndDefaultsToAll() {
        XCTAssertEqual(LearnDataSource.FilterMode.allCases.count, 3)
        XCTAssertTrue(LearnDataSource.FilterMode.allCases.contains(.all))
        XCTAssertTrue(LearnDataSource.FilterMode.allCases.contains(.notStarted))
        XCTAssertTrue(LearnDataSource.FilterMode.allCases.contains(.completed))

        let dataSource = LearnDataSource()
        XCTAssertEqual(dataSource.filterMode, .all)
    }

    //harness:criterion=c-segmented-control-three-segments,c-segmented-control-default-selected
    func testProgressFilterControlLoadsWithExpectedSegmentsAndAllSelected() {
        let viewController = makeLearnViewController()

        viewController.loadViewIfNeeded()

        let control = viewController.progressFilter
        XCTAssertEqual(control.numberOfSegments, 3)
        XCTAssertEqual(control.titleForSegment(at: 0), "All")
        XCTAssertEqual(control.titleForSegment(at: 1), "Not Started")
        XCTAssertEqual(control.titleForSegment(at: 2), "Completed")
        XCTAssertEqual(control.selectedSegmentIndex, 0)
        XCTAssertEqual(control.accessibilityLabel, "Learn filter")
        XCTAssertEqual(control.accessibilityValue, "All")
    }

    //harness:criterion=c-all-mode-shows-all-sections,c-empty-chapter-not-hidden-all,c-all-mode-section-count-matches-chapters
    func testAllModeShowsEveryChapterAndSection() {
        let dataSource = LearnDataSource()
        let tableView = makeTableView()
        let expectedRows = Unwrap.chapters.reduce(0) { $0 + $1.sections.count }

        dataSource.filterMode = .all

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), Unwrap.chapters.count)
        XCTAssertEqual(visibleSectionBundleNames(in: dataSource).count, expectedRows)

        let tableRows = (0..<dataSource.numberOfSections(in: tableView)).reduce(0) {
            $0 + dataSource.tableView(tableView, numberOfRowsInSection: $1)
        }

        XCTAssertEqual(tableRows, expectedRows)
    }

    //harness:criterion=c-not-started-hides-learned-sections,c-not-started-hides-reviewed-sections,c-not-started-shows-unstarted-sections
    func testNotStartedModeContainsOnlySectionsWithNoProgress() throws {
        let sections = firstSections(count: 3)
        User.current = try userWithProgress(learned: [sections[0].bundleName], reviewed: [sections[1].bundleName])

        let dataSource = LearnDataSource()
        dataSource.filterMode = .notStarted

        let visible = Set(visibleSectionBundleNames(in: dataSource))
        let expected = Set(allSectionBundleNames().filter {
            User.current.hasLearned($0) == false && User.current.hasReviewed($0) == false
        })

        XCTAssertFalse(visible.contains(sections[0].bundleName))
        XCTAssertFalse(visible.contains(sections[1].bundleName))
        XCTAssertTrue(visible.contains(sections[2].bundleName))
        XCTAssertTrue(User.current.hasReviewed(sections[1].bundleName))
        XCTAssertFalse(User.current.hasLearned(sections[1].bundleName))
        XCTAssertEqual(visible, expected)
        XCTAssertTrue(visible.allSatisfy { User.current.hasLearned($0) == false })
        XCTAssertTrue(visible.allSatisfy { User.current.hasReviewed($0) == false })
    }

    //harness:criterion=c-completed-shows-fully-done-sections,c-completed-hides-unstarted-sections,c-completed-hides-partial-sections
    func testCompletedModeContainsOnlyFullyCompletedSections() throws {
        let sections = firstSections(count: 3)
        User.current = try userWithProgress(
            learned: [sections[0].bundleName, sections[1].bundleName],
            reviewed: [sections[0].bundleName, sections[2].bundleName]
        )

        let dataSource = LearnDataSource()
        dataSource.filterMode = .completed

        let visible = Set(visibleSectionBundleNames(in: dataSource))

        XCTAssertTrue(visible.contains(sections[0].bundleName))
        XCTAssertFalse(visible.contains(sections[1].bundleName))
        XCTAssertFalse(visible.contains(sections[2].bundleName))
        XCTAssertTrue(User.current.hasReviewed(sections[2].bundleName))
        XCTAssertFalse(User.current.hasLearned(sections[2].bundleName))
        XCTAssertTrue(visible.allSatisfy {
            User.current.hasLearned($0) && User.current.hasReviewed($0)
        })
    }

    //harness:criterion=c-empty-chapter-hidden-not-started,c-number-of-sections-uses-visible-mapping
    func testNotStartedModeHidesChaptersWithNoVisibleRows() {
        let chapterIndex = firstChapterIndexWithAtLeastTwoSections()
        let chapter = Unwrap.chapters[chapterIndex]
        chapter.sections.forEach { User.current.reviewedSection($0.bundleName) }

        let dataSource = LearnDataSource()
        let tableView = makeTableView()
        dataSource.filterMode = .notStarted

        let visibleChapterNames = visibleChapterTitles(in: dataSource)
        let expectedVisibleChapters = Unwrap.chapters.filter { chapter in
            chapter.sections.contains {
                User.current.hasLearned($0.bundleName) == false && User.current.hasReviewed($0.bundleName) == false
            }
        }.count

        XCTAssertFalse(visibleChapterNames.contains(chapter.name))
        XCTAssertEqual(dataSource.numberOfSections(in: tableView), expectedVisibleChapters)
        XCTAssertLessThan(dataSource.numberOfSections(in: tableView), Unwrap.chapters.count)
    }

    //harness:criterion=c-empty-chapter-hidden-completed
    func testCompletedModeHidesChaptersWithNoFullyCompletedRows() {
        let dataSource = LearnDataSource()
        dataSource.filterMode = .completed

        XCTAssertEqual(dataSource.numberOfSections(in: makeTableView()), 0)
        XCTAssertTrue(visibleChapterTitles(in: dataSource).isEmpty)
    }

    //harness:criterion=c-number-of-rows-uses-visible-mapping,c-partial-chapter-visible-not-started
    func testNotStartedModeKeepsPartialChapterWithOnlyUnstartedRows() {
        let chapterIndex = firstChapterIndexWithAtLeastTwoSections()
        let chapter = Unwrap.chapters[chapterIndex]
        let onlyUnstartedSectionIndex = 1

        for (index, section) in chapter.sections.enumerated() where index != onlyUnstartedSectionIndex {
            User.current.reviewedSection(section.bundleName)
        }

        let dataSource = LearnDataSource()
        let tableView = makeTableView()
        dataSource.filterMode = .notStarted

        let visibleIndex = visibleIndexOfChapter(chapterIndex, in: dataSource)
        XCTAssertNotNil(visibleIndex)
        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: visibleIndex!), 1)
        XCTAssertEqual(dataSource.title(for: IndexPath(row: 0, section: visibleIndex!)).bundleName, chapter.sections[onlyUnstartedSectionIndex].bundleName)
    }

    //harness:criterion=c-partial-chapter-visible-completed
    func testCompletedModeKeepsPartialChapterWithOnlyCompletedRows() {
        let chapterIndex = firstChapterIndexWithAtLeastTwoSections()
        let chapter = Unwrap.chapters[chapterIndex]
        let completedSectionIndex = 1
        User.current.reviewedSection(chapter.sections[completedSectionIndex].bundleName)

        let dataSource = LearnDataSource()
        let tableView = makeTableView()
        dataSource.filterMode = .completed

        let visibleIndex = visibleIndexOfChapter(chapterIndex, in: dataSource)
        XCTAssertNotNil(visibleIndex)
        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: visibleIndex!), 1)
        XCTAssertEqual(dataSource.title(for: IndexPath(row: 0, section: visibleIndex!)).bundleName, chapter.sections[completedSectionIndex].bundleName)
    }

    //harness:criterion=c-visible-mapping-rebuilt-on-mode-change
    func testVisibleMappingRebuildsImmediatelyWhenFilterModeChanges() {
        let section = firstSections(count: 1)[0]
        User.current.learnedSection(section.bundleName)
        let dataSource = LearnDataSource()
        dataSource.filterMode = .all
        let allCount = visibleSectionBundleNames(in: dataSource).count

        dataSource.filterMode = .notStarted

        XCTAssertLessThan(visibleSectionBundleNames(in: dataSource).count, allCount)
    }

    //harness:criterion=c-tap-resolves-correct-section-title,c-filtered-row-selection-not-started
    func testNotStartedRowSelectionUsesUnderlyingSectionTitle() {
        let chapterIndex = firstChapterIndexWithAtLeastTwoSections()
        let chapter = Unwrap.chapters[chapterIndex]
        User.current.reviewedSection(chapter.sections[0].bundleName)
        let expectedSection = chapter.sections[1]
        let dataSource = LearnDataSource()
        let delegate = StudyingSpyLearnViewController(style: .plain)

        dataSource.delegate = delegate
        dataSource.filterMode = .notStarted
        dataSource.tableView(makeTableView(), didSelectRowAt: IndexPath(row: 0, section: 0))

        XCTAssertEqual(delegate.startedTitle?.bundleName, expectedSection.bundleName)
        XCTAssertNotEqual(delegate.startedTitle?.bundleName, chapter.sections[0].bundleName)
    }

    //harness:criterion=c-filtered-row-selection-completed
    func testCompletedRowSelectionUsesUnderlyingSectionTitle() {
        let chapterIndex = firstChapterIndexWithAtLeastTwoSections()
        let chapter = Unwrap.chapters[chapterIndex]
        User.current.reviewedSection(chapter.sections[1].bundleName)
        let dataSource = LearnDataSource()
        let delegate = StudyingSpyLearnViewController(style: .plain)

        dataSource.delegate = delegate
        dataSource.filterMode = .completed
        dataSource.tableView(makeTableView(), didSelectRowAt: IndexPath(row: 0, section: 0))

        XCTAssertEqual(delegate.startedTitle?.bundleName, chapter.sections[1].bundleName)
        XCTAssertNotEqual(delegate.startedTitle?.bundleName, chapter.sections[0].bundleName)
    }

    //harness:criterion=c-context-menu-resolves-correct-section-title
    func testContextMenuUsesUnderlyingFilteredSectionTitle() {
        let chapterIndex = firstChapterIndexWithAtLeastTwoSections()
        let chapter = Unwrap.chapters[chapterIndex]
        User.current.reviewedSection(chapter.sections[1].bundleName)
        let coordinator = PreviewSpyLearnCoordinator()
        let viewController = LearnViewController(style: .plain)
        viewController.coordinator = coordinator
        viewController.loadViewIfNeeded()
        viewController.tableView.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        viewController.dataSource.filterMode = .completed
        viewController.tableView.reloadData()
        viewController.tableView.layoutIfNeeded()

        let rect = viewController.tableView.rectForRow(at: IndexPath(row: 0, section: 0))
        let point = CGPoint(x: rect.midX, y: rect.midY)
        let interaction = UIContextMenuInteraction(delegate: viewController)
        let configuration = viewController.contextMenuInteraction(interaction, configurationForMenuAtLocation: point)

        XCTAssertNotNil(configuration)
        XCTAssertEqual(coordinator.previewedTitle?.bundleName, chapter.sections[1].bundleName)
    }

    //harness:criterion=c-segment-change-triggers-reload
    func testProgressFilterChangeUpdatesModeAndReloadsTable() {
        let viewController = makeLearnViewController()
        viewController.loadViewIfNeeded()
        let tableView = ReloadTrackingTableView()
        viewController.tableView = tableView

        viewController.progressFilter.selectedSegmentIndex = 1
        viewController.progressFilterChanged()

        XCTAssertEqual(viewController.dataSource.filterMode, .notStarted)
        XCTAssertEqual(viewController.progressFilter.accessibilityValue, "Not Started")
        XCTAssertGreaterThanOrEqual(tableView.reloadDataCallCount, 1)
    }

    //harness:criterion=c-user-data-changed-full-reload
    func testUserDataChangedUsesFullTableReload() {
        let viewController = makeLearnViewController()
        viewController.loadViewIfNeeded()
        let tableView = ReloadTrackingTableView()
        viewController.tableView = tableView

        viewController.userDataChanged()

        XCTAssertEqual(tableView.reloadDataCallCount, 1)
        XCTAssertEqual(tableView.reloadRowsCallCount, 0)
        XCTAssertEqual(tableView.reloadSectionsCallCount, 0)
    }

    //harness:criterion=c-visible-mapping-rebuilt-on-user-data-change
    func testUserDataChangedRebuildsVisibleMappingForCurrentProgress() {
        let viewController = makeLearnViewController()
        viewController.loadViewIfNeeded()
        viewController.dataSource.filterMode = .notStarted
        let visibleBeforeProgress = visibleSectionBundleNames(in: viewController.dataSource).count
        let section = viewController.dataSource.title(for: IndexPath(row: 0, section: 0))

        User.current.learnedSection(section.bundleName)
        viewController.userDataChanged()

        XCTAssertEqual(visibleSectionBundleNames(in: viewController.dataSource).count, visibleBeforeProgress - 1)
    }

    //harness:criterion=c-view-for-header-uses-visible-mapping
    func testHeaderUsesVisibleChapterMapping() {
        let chapterIndex = firstChapterIndexWithAtLeastTwoSections()
        let chapter = Unwrap.chapters[chapterIndex]
        chapter.sections.forEach { User.current.reviewedSection($0.bundleName) }
        let expectedVisibleChapter = Unwrap.chapters[(chapterIndex + 1)...].first {
            $0.sections.isEmpty == false
        }
        let dataSource = LearnDataSource()
        let tableView = makeTableView()
        dataSource.filterMode = .notStarted

        let header = dataSource.tableView(tableView, viewForHeaderInSection: 0) as? DynamicHeightHeaderView

        XCTAssertNotNil(expectedVisibleChapter)
        XCTAssertEqual(header?.headerLabel.text, expectedVisibleChapter?.name)
        XCTAssertNotEqual(header?.headerLabel.text, chapter.name)
    }

    //harness:criterion=c-cell-for-row-uses-visible-mapping
    func testCellUsesVisibleRowMapping() {
        let chapterIndex = firstChapterIndexWithAtLeastTwoSections()
        let chapter = Unwrap.chapters[chapterIndex]
        User.current.reviewedSection(chapter.sections[0].bundleName)
        let expectedSection = chapter.sections[1]
        let dataSource = LearnDataSource()
        let tableView = makeTableView()
        dataSource.filterMode = .notStarted

        let cell = dataSource.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: 0))

        XCTAssertEqual(cell.textLabel?.text?.bundleName, expectedSection.bundleName)
        XCTAssertNotEqual(cell.textLabel?.text?.bundleName, chapter.sections[0].bundleName)
    }

    private func makeLearnViewController() -> LearnViewController {
        let viewController = LearnViewController(style: .plain)
        viewController.coordinator = LearnCoordinator()
        return viewController
    }

    private func makeTableView() -> UITableView {
        let tableView = UITableView()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
        return tableView
    }

    private func allSectionBundleNames() -> [String] {
        return Unwrap.chapters.flatMap { $0.sections.map(\.bundleName) }
    }

    private func firstSections(count: Int) -> [String] {
        let sections = Unwrap.chapters.flatMap(\.sections)
        XCTAssertGreaterThanOrEqual(sections.count, count)
        return Array(sections.prefix(count))
    }

    private func firstChapterIndexWithAtLeastTwoSections() -> Int {
        let index = Unwrap.chapters.firstIndex { $0.sections.count >= 2 }
        XCTAssertNotNil(index)
        return index!
    }

    private func visibleSectionBundleNames(in dataSource: LearnDataSource) -> [String] {
        return dataSource.visibleChapters.flatMap { visibleChapter in
            visibleChapter.sectionIndices.map {
                Unwrap.chapters[visibleChapter.chapterIndex].sections[$0].bundleName
            }
        }
    }

    private func visibleChapterTitles(in dataSource: LearnDataSource) -> [String] {
        return dataSource.visibleChapters.map {
            Unwrap.chapters[$0.chapterIndex].name
        }
    }

    private func visibleIndexOfChapter(_ chapterIndex: Int, in dataSource: LearnDataSource) -> Int? {
        return dataSource.visibleChapters.firstIndex {
            $0.chapterIndex == chapterIndex
        }
    }

    private func userWithProgress(learned: [String], reviewed: [String]) throws -> User {
        let encodedUser = try JSONEncoder().encode(User())
        var userData = try XCTUnwrap(JSONSerialization.jsonObject(with: encodedUser) as? [String: Any])
        userData["learnedSections"] = learned
        userData["reviewedSections"] = reviewed

        let rewrittenUser = try JSONSerialization.data(withJSONObject: userData)
        return try JSONDecoder().decode(User.self, from: rewrittenUser)
    }
}

private final class StudyingSpyLearnViewController: LearnViewController {
    var startedTitle: String?

    override func startStudying(title: String) {
        startedTitle = title
    }
}

private final class PreviewSpyLearnCoordinator: LearnCoordinator {
    var previewedTitle: String?

    override func studyViewController(for title: String) -> StudyViewController {
        previewedTitle = title
        return StudyViewController()
    }
}

private final class ReloadTrackingTableView: UITableView {
    var reloadDataCallCount = 0
    var reloadRowsCallCount = 0
    var reloadSectionsCallCount = 0

    override func reloadData() {
        reloadDataCallCount += 1
        super.reloadData()
    }

    override func reloadRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation) {
        reloadRowsCallCount += 1
        super.reloadRows(at: indexPaths, with: animation)
    }

    override func reloadSections(_ sections: IndexSet, with animation: UITableView.RowAnimation) {
        reloadSectionsCallCount += 1
        super.reloadSections(sections, with: animation)
    }
}
