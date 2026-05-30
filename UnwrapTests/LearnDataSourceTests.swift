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
    private var tableView: UITableView!

    override func setUp() {
        super.setUp()
        tableView = UITableView()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
        User.current = User()
    }

    override func tearDown() {
        User.current = nil
        tableView = nil
        super.tearDown()
    }

    //harness:criterion=c-learn-filter-enum-cases
    func testLearnFilterHasOnlyExpectedCases() {
        func label(for filter: LearnFilter) -> String {
            switch filter {
            case .all:
                return "all"
            case .notStarted:
                return "notStarted"
            case .completed:
                return "completed"
            }
        }

        let labels = [LearnFilter.all, .notStarted, .completed].map(label)

        XCTAssertEqual(labels, ["all", "notStarted", "completed"])
        XCTAssertEqual(Set(labels).count, 3)
    }

    //harness:criterion=c-learn-datasource-filter-default-all,c-learn-filter-all-shows-all-chapters,c-learn-filter-all-shows-all-sections,c-learn-filter-all-no-chapters-hidden
    func testAllFilterIsDefaultAndShowsEveryChapterAndSection() {
        let completedChapter = Unwrap.chapters[0]
        User.current = makeUser(learned: completedChapter.sections.map { $0.bundleName }, reviewed: completedChapter.sections.map { $0.bundleName })
        let dataSource = LearnDataSource()

        XCTAssertEqual(dataSource.filter, .all)
        XCTAssertEqual(dataSource.numberOfSections(in: tableView), Unwrap.chapters.count)

        for chapterIndex in Unwrap.chapters.indices {
            XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: chapterIndex), Unwrap.chapters[chapterIndex].sections.count)
        }
    }

    //harness:criterion=c-learn-filter-not-started-hides-learned-reviewed,c-learn-filter-not-started-excludes-completed-sections
    func testNotStartedFilterIncludesOnlySectionsWithNoProgress() {
        let chapter = Unwrap.chapters[0]
        let learnedOnly = chapter.sections[0]
        let reviewedOnly = chapter.sections[1]
        let completed = chapter.sections[2]
        let untouched = chapter.sections[3]
        User.current = makeUser(learned: [learnedOnly.bundleName, completed.bundleName], reviewed: [reviewedOnly.bundleName, completed.bundleName])
        let dataSource = LearnDataSource()
        dataSource.filter = .notStarted

        let visibleTitles = titles(in: dataSource)

        XCTAssertFalse(visibleTitles.contains(learnedOnly))
        XCTAssertFalse(visibleTitles.contains(reviewedOnly))
        XCTAssertFalse(visibleTitles.contains(completed))
        XCTAssertTrue(visibleTitles.contains(untouched))

        for title in visibleTitles {
            XCTAssertFalse(User.current.hasLearned(title.bundleName))
            XCTAssertFalse(User.current.hasReviewed(title.bundleName))
        }
    }

    //harness:criterion=c-learn-filter-completed-shows-learned-and-reviewed,c-learn-filter-completed-excludes-partial-sections
    func testCompletedFilterIncludesOnlyFullyCompletedSections() {
        let chapter = Unwrap.chapters[0]
        let learnedOnly = chapter.sections[0]
        let reviewedOnly = chapter.sections[1]
        let completed = chapter.sections[2]
        let untouched = chapter.sections[3]
        User.current = makeUser(learned: [learnedOnly.bundleName, completed.bundleName], reviewed: [reviewedOnly.bundleName, completed.bundleName])
        let dataSource = LearnDataSource()
        dataSource.filter = .completed

        let visibleTitles = titles(in: dataSource)

        XCTAssertFalse(visibleTitles.contains(learnedOnly))
        XCTAssertFalse(visibleTitles.contains(reviewedOnly))
        XCTAssertTrue(visibleTitles.contains(completed))
        XCTAssertFalse(visibleTitles.contains(untouched))

        for title in visibleTitles {
            XCTAssertTrue(User.current.hasLearned(title.bundleName))
            XCTAssertTrue(User.current.hasReviewed(title.bundleName))
        }
    }

    //harness:criterion=c-learn-filter-empty-chapter-hidden,c-learn-filter-view-for-header-correct-chapter,c-learn-filter-number-of-sections-matches-nonempty-chapters
    func testFilteredSectionsMatchNonemptyChaptersAndHeadersUseOriginalChapterNames() {
        let completedChapter = Unwrap.chapters[0]
        User.current = makeUser(learned: completedChapter.sections.map { $0.bundleName }, reviewed: completedChapter.sections.map { $0.bundleName })
        let dataSource = LearnDataSource()
        dataSource.filter = .notStarted

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), expectedVisibleChapterCount(for: .notStarted))
        XCTAssertEqual(headerTitle(in: dataSource, section: 0), Unwrap.chapters[1].name)

        let headerTitles = (0..<dataSource.numberOfSections(in: tableView)).compactMap { headerTitle(in: dataSource, section: $0) }
        XCTAssertFalse(headerTitles.contains(completedChapter.name))

        for filter in [LearnFilter.all, .notStarted, .completed] {
            dataSource.filter = filter
            XCTAssertEqual(dataSource.numberOfSections(in: tableView), expectedVisibleChapterCount(for: filter))
        }
    }

    //harness:criterion=c-learn-filter-map-cell-correct-section,c-learn-filter-title-for-correct-after-filter,c-learn-vc-context-menu-preserved
    func testFilteredIndexesResolveToUnderlyingSectionForCellsAndTitles() {
        let firstSection = Unwrap.chapters[0].sections[0]
        let secondSection = Unwrap.chapters[0].sections[1]
        User.current = makeUser(learned: [firstSection.bundleName], reviewed: [firstSection.bundleName])
        let dataSource = LearnDataSource()
        dataSource.filter = .notStarted

        let filteredIndexPath = IndexPath(row: 0, section: 0)
        let cell = dataSource.tableView(tableView, cellForRowAt: filteredIndexPath)

        XCTAssertEqual(dataSource.title(for: filteredIndexPath), secondSection)
        XCTAssertEqual(cell.textLabel?.text, secondSection)
        XCTAssertNotEqual(cell.textLabel?.text, firstSection)
    }

    //harness:criterion=c-learn-filter-did-select-navigates-correct-section
    func testSelectingFilteredRowStartsStudyingUnderlyingSection() {
        let firstSection = Unwrap.chapters[0].sections[0]
        let secondSection = Unwrap.chapters[0].sections[1]
        User.current = makeUser(learned: [firstSection.bundleName], reviewed: [firstSection.bundleName])
        let dataSource = LearnDataSource()
        dataSource.filter = .notStarted
        let delegate = CapturingLearnViewController(style: .plain)
        dataSource.delegate = delegate

        dataSource.tableView(tableView, didSelectRowAt: IndexPath(row: 0, section: 0))

        XCTAssertEqual(delegate.startedTitle, secondSection)
        XCTAssertNotEqual(delegate.startedTitle, firstSection)
    }

    //harness:criterion=c-learn-filter-setting-triggers-rebuild
    func testSettingFilterImmediatelyRebuildsVisibleMapping() {
        let completedChapter = Unwrap.chapters[0]
        User.current = makeUser(learned: completedChapter.sections.map { $0.bundleName }, reviewed: completedChapter.sections.map { $0.bundleName })
        let dataSource = LearnDataSource()

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), Unwrap.chapters.count)

        dataSource.filter = .completed

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), expectedVisibleChapterCount(for: .completed))
        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: 0), completedChapter.sections.count)
    }

    //harness:criterion=c-learn-vc-segmented-control-present,c-learn-vc-segmented-control-default-all,c-learn-vc-glossary-button-preserved
    func testLearnViewControllerShowsFilterControlAndKeepsGlossaryButton() throws {
        let viewController = makeLoadedLearnViewController()
        let segmentedControl = try XCTUnwrap(findSegmentedControl(in: viewController))

        XCTAssertEqual(segmentedControl.numberOfSegments, 3)
        XCTAssertEqual(segmentedControl.titleForSegment(at: 0), "All")
        XCTAssertEqual(segmentedControl.titleForSegment(at: 1), "Not Started")
        XCTAssertEqual(segmentedControl.titleForSegment(at: 2), "Completed")
        XCTAssertEqual(segmentedControl.selectedSegmentIndex, 0)
        XCTAssertEqual(viewController.navigationItem.rightBarButtonItem?.title, "Glossary")
        let glossaryAction = try XCTUnwrap(viewController.navigationItem.rightBarButtonItem?.action)
        XCTAssertEqual(NSStringFromSelector(glossaryAction), "showGlossary")
    }

    //harness:criterion=c-learn-vc-segmented-control-updates-filter
    func testChangingSegmentedControlUpdatesFilterAndReloadsTable() throws {
        let viewController = makeLoadedLearnViewController()
        let tableView = viewController.tableView as! ReloadTrackingTableView
        let segmentedControl = try XCTUnwrap(findSegmentedControl(in: viewController))
        let valueChangedAction = try XCTUnwrap(segmentedControl.actions(forTarget: viewController, forControlEvent: .valueChanged)?.first)
        let action = NSSelectorFromString(valueChangedAction)
        tableView.reloadDataCallCount = 0

        segmentedControl.selectedSegmentIndex = 1
        _ = viewController.perform(action)
        XCTAssertEqual(viewController.dataSource.filter, .notStarted)

        segmentedControl.selectedSegmentIndex = 2
        _ = viewController.perform(action)
        XCTAssertEqual(viewController.dataSource.filter, .completed)

        segmentedControl.selectedSegmentIndex = 0
        _ = viewController.perform(action)
        XCTAssertEqual(viewController.dataSource.filter, .all)
        XCTAssertEqual(tableView.reloadDataCallCount, 3)
    }

    //harness:criterion=c-learn-vc-user-data-changed-full-reload
    func testUserDataChangedRefreshesDataSourceAndPerformsFullReload() {
        let viewController = makeLoadedLearnViewController()
        let tableView = viewController.tableView as! ReloadTrackingTableView
        tableView.reloadDataCallCount = 0

        viewController.userDataChanged()

        XCTAssertEqual(tableView.reloadDataCallCount, 1)
    }

    private func titles(in dataSource: LearnDataSource) -> [String] {
        var titles = [String]()

        for section in 0..<dataSource.numberOfSections(in: tableView) {
            for row in 0..<dataSource.tableView(tableView, numberOfRowsInSection: section) {
                titles.append(dataSource.title(for: IndexPath(row: row, section: section)))
            }
        }

        return titles
    }

    private func headerTitle(in dataSource: LearnDataSource, section: Int) -> String? {
        let headerView = dataSource.tableView(tableView, viewForHeaderInSection: section) as? DynamicHeightHeaderView
        return headerView?.headerLabel.text
    }

    private func expectedVisibleChapterCount(for filter: LearnFilter) -> Int {
        return Unwrap.chapters.filter { chapter in
            chapter.sections.contains { section in
                switch filter {
                case .all:
                    return true
                case .notStarted:
                    return User.current.hasLearned(section.bundleName) == false && User.current.hasReviewed(section.bundleName) == false
                case .completed:
                    return User.current.hasLearned(section.bundleName) && User.current.hasReviewed(section.bundleName)
                }
            }
        }.count
    }

    private func makeLoadedLearnViewController() -> LearnViewController {
        User.current = User()
        let viewController = SpyLearnViewController(style: .plain)
        viewController.coordinator = LearnCoordinator()
        viewController.loadViewIfNeeded()
        return viewController
    }

    private func findSegmentedControl(in viewController: LearnViewController) -> UISegmentedControl? {
        guard let headerView = viewController.tableView.tableHeaderView else {
            return viewController.navigationItem.titleView as? UISegmentedControl
        }

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

    private func makeUser(learned: [String] = [], reviewed: [String] = []) -> User {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let templateData = try! encoder.encode(User())
        var json = try! JSONSerialization.jsonObject(with: templateData) as! [String: Any]
        json["learnedSections"] = learned
        json["reviewedSections"] = reviewed
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(User.self, from: data)
    }
}

private class CapturingLearnViewController: LearnViewController {
    var startedTitle: String?

    override func startStudying(title: String) {
        startedTitle = title
    }
}

private class SpyLearnViewController: LearnViewController {
    let reloadTrackingTableView = ReloadTrackingTableView(frame: .zero, style: .plain)

    override func loadView() {
        tableView = reloadTrackingTableView
        view = reloadTrackingTableView
    }
}

private class ReloadTrackingTableView: UITableView {
    var reloadDataCallCount = 0

    override func reloadData() {
        reloadDataCallCount += 1
        super.reloadData()
    }
}
