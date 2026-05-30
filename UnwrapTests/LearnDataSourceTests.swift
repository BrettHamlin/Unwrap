//
//  LearnDataSourceTests.swift
//  UnwrapTests
//
//  Created by OpenAI on 30/05/2026.
//  Copyright © 2026 Hacking with Swift. All rights reserved.
//

import XCTest
import UIKit
@testable import Unwrap

class LearnDataSourceTests: XCTestCase {
    private struct ProgressFixture {
        let hiddenChapter: Chapter
        let partialChapter: Chapter
        let completedSection: String
        let learnedOnlySection: String
        let reviewOnlySection: String
        let notStartedSection: String
        let learned: Set<String>
        let reviewed: Set<String>
    }

    override func setUp() {
        super.setUp()
        User.current = User()
    }

    override func tearDown() {
        User.current = User()
        super.tearDown()
    }

    //harness:criterion=c-filter-enum-defaults-all,c-all-filter-shows-all-chapters,c-all-filter-preserves-order
    func testDefaultAllFilterShowsEveryChapterAndSectionInOriginalOrder() {
        let dataSource = LearnDataSource()

        XCTAssertEqual(dataSource.currentFilter, .all)
        assertVisibleChaptersMatchAllChapters(dataSource.visibleChapters)
    }

    //harness:criterion=c-not-started-hides-learned-sections,c-not-started-hides-reviewed-sections,c-not-started-shows-unstarted-sections,c-empty-chapter-hidden,c-partial-chapter-visible,c-filter-not-started-partial-progress-excluded
    func testNotStartedFilterExcludesAnyProgressAndHidesEmptyChapters() throws {
        let fixture = try makeProgressFixture()
        User.current = try makeUser(learned: fixture.learned, reviewed: fixture.reviewed)
        let dataSource = LearnDataSource()

        dataSource.applyFilter(.notStarted)

        let visibleBundleNames = bundleNames(in: dataSource.visibleChapters)
        XCTAssertFalse(visibleBundleNames.contains(fixture.completedSection))
        XCTAssertFalse(visibleBundleNames.contains(fixture.learnedOnlySection))
        XCTAssertFalse(visibleBundleNames.contains(fixture.reviewOnlySection))
        XCTAssertTrue(visibleBundleNames.contains(fixture.notStartedSection))
        XCTAssertFalse(dataSource.visibleChapters.contains { $0.name == fixture.hiddenChapter.name })

        let visiblePartialChapter = try XCTUnwrap(dataSource.visibleChapters.first { $0.name == fixture.partialChapter.name })
        XCTAssertEqual(visiblePartialChapter.sections.map(\.bundleName), [fixture.notStartedSection])
    }

    //harness:criterion=c-completed-shows-fully-done-sections,c-completed-hides-learn-only-sections,c-completed-hides-review-only-sections
    func testCompletedFilterIncludesOnlyFullyLearnedAndReviewedSections() throws {
        let fixture = try makeProgressFixture()
        User.current = try makeUser(learned: fixture.learned, reviewed: fixture.reviewed)
        let dataSource = LearnDataSource()

        dataSource.applyFilter(.completed)

        let visibleBundleNames = bundleNames(in: dataSource.visibleChapters)
        let expectedBundleNames = Unwrap.chapters.flatMap(\.sections).map(\.bundleName).filter {
            fixture.learned.contains($0) && fixture.reviewed.contains($0)
        }

        XCTAssertEqual(visibleBundleNames, expectedBundleNames)
        XCTAssertTrue(visibleBundleNames.contains(fixture.completedSection))
        XCTAssertFalse(visibleBundleNames.contains(fixture.learnedOnlySection))
        XCTAssertFalse(visibleBundleNames.contains(fixture.reviewOnlySection))
    }

    //harness:criterion=c-number-of-sections-uses-visible-chapters
    func testNumberOfSectionsUsesVisibleChapters() throws {
        User.current = try makeUser()
        let dataSource = LearnDataSource()

        dataSource.applyFilter(.completed)

        XCTAssertEqual(dataSource.visibleChapters.count, 0)
        XCTAssertEqual(dataSource.numberOfSections(in: UITableView()), dataSource.visibleChapters.count)
        XCTAssertLessThan(dataSource.numberOfSections(in: UITableView()), Unwrap.chapters.count)
    }

    //harness:criterion=c-number-of-rows-uses-visible-sections,c-header-view-uses-visible-chapters,c-title-for-uses-visible-chapters,c-did-select-resolves-correct-section
    func testTableDataAndSelectionUseFilteredVisibleChapters() throws {
        let fixture = try makeProgressFixture()
        User.current = try makeUser(learned: fixture.learned, reviewed: fixture.reviewed)
        let dataSource = LearnDataSource()
        dataSource.applyFilter(.notStarted)

        let indexPath = IndexPath(row: 0, section: 0)
        let visibleChapter = dataSource.visibleChapters[indexPath.section]
        let visibleSection = visibleChapter.sections[indexPath.row]

        XCTAssertEqual(dataSource.tableView(UITableView(), numberOfRowsInSection: indexPath.section), visibleChapter.sections.count)

        let tableView = UITableView()
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
        let headerView = try XCTUnwrap(dataSource.tableView(tableView, viewForHeaderInSection: indexPath.section) as? DynamicHeightHeaderView)
        XCTAssertEqual(headerView.headerLabel.text, visibleChapter.name)
        XCTAssertNotEqual(headerView.headerLabel.text, Unwrap.chapters[indexPath.section].name)

        XCTAssertEqual(dataSource.title(for: indexPath), visibleSection)
        XCTAssertNotEqual(dataSource.title(for: indexPath), Unwrap.chapters[indexPath.section].sections[indexPath.row])

        let delegate = SelectionSpyLearnViewController(style: .plain)
        dataSource.delegate = delegate
        dataSource.tableView(UITableView(), didSelectRowAt: indexPath)

        XCTAssertEqual(delegate.startedTitle, visibleSection)
        XCTAssertNotEqual(delegate.startedTitle, Unwrap.chapters[indexPath.section].sections[indexPath.row])
    }

    //harness:criterion=c-apply-filter-recomputes-visible-chapters,c-apply-filter-triggers-reload
    func testApplyFilterRecomputesVisibleChaptersBeforeReloadingTableView() throws {
        let fixture = try makeProgressFixture()
        User.current = try makeUser(learned: fixture.learned, reviewed: fixture.reviewed)

        let dataSource = LearnDataSource()
        let viewController = loadedLearnViewController(dataSource: dataSource)
        let tableView = ReloadSpyTableView()
        viewController.tableView = tableView

        tableView.onReloadData = {
            XCTAssertEqual(dataSource.currentFilter, .notStarted)
            XCTAssertFalse(self.bundleNames(in: dataSource.visibleChapters).contains(fixture.learnedOnlySection))
            XCTAssertTrue(self.bundleNames(in: dataSource.visibleChapters).contains(fixture.notStartedSection))
        }

        dataSource.applyFilter(.notStarted)

        XCTAssertEqual(tableView.reloadDataCallCount, 1)
    }

    //harness:criterion=c-source-data-immutable,c-all-filter-after-switch-back
    func testFilteringKeepsSourceChaptersImmutableAndAllRestoresOriginalData() throws {
        let fixture = try makeProgressFixture()
        User.current = try makeUser(learned: fixture.learned, reviewed: fixture.reviewed)
        let dataSource = LearnDataSource()
        let originalChapterNames = Unwrap.chapters.map(\.name)
        let originalSectionNames = Unwrap.chapters.map(\.sections)

        dataSource.applyFilter(.notStarted)
        XCTAssertEqual(Unwrap.chapters.map(\.name), originalChapterNames)
        XCTAssertEqual(Unwrap.chapters.map(\.sections), originalSectionNames)

        dataSource.applyFilter(.all)
        assertVisibleChaptersMatchAllChapters(dataSource.visibleChapters)

        dataSource.applyFilter(.completed)
        XCTAssertEqual(Unwrap.chapters.map(\.name), originalChapterNames)
        XCTAssertEqual(Unwrap.chapters.map(\.sections), originalSectionNames)

        dataSource.applyFilter(.all)
        assertVisibleChaptersMatchAllChapters(dataSource.visibleChapters)
    }

    //harness:criterion=c-segmented-control-three-segments,c-segmented-control-default-selection
    func testLearnViewControllerDisplaysProgressFilterControlWithAllSelectedByDefault() {
        let viewController = loadedLearnViewController()
        let control = viewController.progressFilterControl

        XCTAssertEqual(control.numberOfSegments, 3)
        XCTAssertEqual(control.titleForSegment(at: 0), "All")
        XCTAssertEqual(control.titleForSegment(at: 1), "Not Started")
        XCTAssertEqual(control.titleForSegment(at: 2), "Completed")
        XCTAssertEqual(control.selectedSegmentIndex, 0)
    }

    //harness:criterion=c-segmented-control-wired-to-apply-filter
    func testProgressFilterControlActionAppliesMatchingFilterMode() {
        let dataSource = ApplyFilterSpyLearnDataSource()
        let viewController = loadedLearnViewController(dataSource: dataSource)
        let control = viewController.progressFilterControl

        XCTAssertEqual(control.actions(forTarget: viewController, forControlEvent: .valueChanged), ["progressFilterChanged:"])

        control.selectedSegmentIndex = 0
        viewController.progressFilterChanged(control)
        control.selectedSegmentIndex = 1
        viewController.progressFilterChanged(control)
        control.selectedSegmentIndex = 2
        viewController.progressFilterChanged(control)

        XCTAssertEqual(dataSource.appliedFilters, [.all, .notStarted, .completed])
    }

    //harness:criterion=c-user-data-changed-recomputes-filter,c-user-data-changed-no-visible-rows-only-reload
    func testUserDataChangedReappliesCurrentFilterWithFullTableReloadOnly() throws {
        User.current = try makeUser()
        let dataSource = LearnDataSource()
        let viewController = loadedLearnViewController(dataSource: dataSource)
        let tableView = ReloadSpyTableView()
        viewController.tableView = tableView

        dataSource.applyFilter(.notStarted)
        XCTAssertFalse(dataSource.visibleChapters.isEmpty)

        User.current = try makeUser(learned: Set(allBundleNames()), reviewed: [])
        tableView.resetCounts()

        viewController.userDataChanged()

        XCTAssertEqual(dataSource.currentFilter, .notStarted)
        XCTAssertTrue(dataSource.visibleChapters.isEmpty)
        XCTAssertGreaterThanOrEqual(tableView.reloadDataCallCount, 1)
        XCTAssertEqual(tableView.reloadRowsCallCount, 0)
        XCTAssertEqual(tableView.reloadSectionsCallCount, 0)
    }

    //harness:criterion=c-context-menu-resolves-correct-section
    func testContextMenuUsesFilteredVisibleSectionAtTappedLocation() throws {
        let fixture = try makeProgressFixture()
        User.current = try makeUser(learned: fixture.learned, reviewed: fixture.reviewed)
        let dataSource = LearnDataSource()
        let coordinator = StudyPreviewSpyLearnCoordinator()
        let viewController = loadedLearnViewController(dataSource: dataSource, coordinator: coordinator)
        let tableView = IndexPathSpyTableView()
        tableView.indexPathForRowResult = IndexPath(row: 0, section: 0)
        viewController.tableView = tableView

        dataSource.applyFilter(.notStarted)
        let expectedTitle = dataSource.visibleChapters[0].sections[0]

        let configuration = viewController.contextMenuInteraction(UIContextMenuInteraction(delegate: viewController), configurationForMenuAtLocation: .zero)

        XCTAssertNotNil(configuration)
        XCTAssertEqual(coordinator.studyPreviewTitle, expectedTitle)
        XCTAssertNotEqual(coordinator.studyPreviewTitle, Unwrap.chapters[0].sections[0])
    }

    private func assertVisibleChaptersMatchAllChapters(_ visibleChapters: [Chapter], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(visibleChapters.count, Unwrap.chapters.count, file: file, line: line)

        for (chapterIndex, chapter) in Unwrap.chapters.enumerated() {
            XCTAssertEqual(visibleChapters[chapterIndex].name, chapter.name, file: file, line: line)
            XCTAssertEqual(visibleChapters[chapterIndex].sections.count, chapter.sections.count, file: file, line: line)

            for (sectionIndex, section) in chapter.sections.enumerated() {
                XCTAssertEqual(visibleChapters[chapterIndex].sections[sectionIndex].bundleName, section.bundleName, file: file, line: line)
            }
        }
    }

    private func makeProgressFixture() throws -> ProgressFixture {
        XCTAssertGreaterThanOrEqual(Unwrap.chapters.count, 2)
        let hiddenChapter = Unwrap.chapters[0]
        let partialChapter = Unwrap.chapters[1]
        XCTAssertGreaterThanOrEqual(partialChapter.sections.count, 4)

        let completedSection = partialChapter.sections[0].bundleName
        let learnedOnlySection = partialChapter.sections[1].bundleName
        let reviewOnlySection = partialChapter.sections[2].bundleName
        let notStartedSection = partialChapter.sections[3].bundleName

        var learned = Set(hiddenChapter.sections.map(\.bundleName))
        var reviewed = Set(hiddenChapter.sections.map(\.bundleName))

        for (index, section) in partialChapter.sections.enumerated() where index != 3 {
            if index != 2 {
                learned.insert(section.bundleName)
            }
        }

        reviewed.insert(completedSection)
        reviewed.insert(reviewOnlySection)

        return ProgressFixture(
            hiddenChapter: hiddenChapter,
            partialChapter: partialChapter,
            completedSection: completedSection,
            learnedOnlySection: learnedOnlySection,
            reviewOnlySection: reviewOnlySection,
            notStartedSection: notStartedSection,
            learned: learned,
            reviewed: reviewed
        )
    }

    private func makeUser(learned: Set<String> = [], reviewed: Set<String> = []) throws -> User {
        let object: [String: Any] = [
            "streakDays": 1,
            "bestStreak": 1,
            "lastStreakEntry": "2026-05-30T00:00:00Z",
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

        let data = try JSONSerialization.data(withJSONObject: object)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(User.self, from: data)
    }

    private func allBundleNames() -> [String] {
        return Unwrap.chapters.flatMap(\.sections).map(\.bundleName)
    }

    private func bundleNames(in chapters: [Chapter]) -> [String] {
        return chapters.flatMap(\.sections).map(\.bundleName)
    }

    private func loadedLearnViewController(dataSource: LearnDataSource = LearnDataSource(), coordinator: LearnCoordinator = LearnCoordinator()) -> LearnViewController {
        let viewController = LearnViewController(style: .plain)
        viewController.coordinator = coordinator
        viewController.dataSource = dataSource
        viewController.loadViewIfNeeded()
        return viewController
    }
}

private final class SelectionSpyLearnViewController: LearnViewController {
    var startedTitle: String?

    override func startStudying(title: String) {
        startedTitle = title
    }
}

private final class ApplyFilterSpyLearnDataSource: LearnDataSource {
    var appliedFilters = [LearnDataSource.ProgressFilter]()

    override func applyFilter(_ filter: LearnDataSource.ProgressFilter) {
        appliedFilters.append(filter)
        super.applyFilter(filter)
    }
}

private class ReloadSpyTableView: UITableView {
    var reloadDataCallCount = 0
    var reloadRowsCallCount = 0
    var reloadSectionsCallCount = 0
    var onReloadData: (() -> Void)?

    override func reloadData() {
        onReloadData?()
        reloadDataCallCount += 1
    }

    override func reloadRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation) {
        reloadRowsCallCount += 1
    }

    override func reloadSections(_ sections: IndexSet, with animation: UITableView.RowAnimation) {
        reloadSectionsCallCount += 1
    }

    func resetCounts() {
        reloadDataCallCount = 0
        reloadRowsCallCount = 0
        reloadSectionsCallCount = 0
    }
}

private final class IndexPathSpyTableView: ReloadSpyTableView {
    var indexPathForRowResult: IndexPath?

    override func indexPathForRow(at point: CGPoint) -> IndexPath? {
        return indexPathForRowResult
    }
}

private final class StudyPreviewSpyLearnCoordinator: LearnCoordinator {
    var studyPreviewTitle: String?

    override func studyViewController(for title: String) -> StudyViewController {
        studyPreviewTitle = title
        let viewController = StudyViewController()
        viewController.title = title
        viewController.chapter = title.bundleName
        viewController.coordinator = self
        return viewController
    }
}
