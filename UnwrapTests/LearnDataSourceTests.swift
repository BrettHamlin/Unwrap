//
//  LearnDataSourceTests.swift
//  UnwrapTests
//
//  Created by Code Generator on 30/05/2026.
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
        User.current = nil
        super.tearDown()
    }

    //harness:criterion=c-learn-progress-filter-enum-cases,c-learn-progress-filter-labels-all,c-learn-progress-filter-labels-not-started,c-learn-progress-filter-labels-completed
    func testProgressFilterCasesAndLabels() {
        XCTAssertEqual(LearnProgressFilter.allCases.count, 3)
        XCTAssertTrue(LearnProgressFilter.allCases.contains(.all))
        XCTAssertTrue(LearnProgressFilter.allCases.contains(.notStarted))
        XCTAssertTrue(LearnProgressFilter.allCases.contains(.completed))
        XCTAssertEqual(LearnProgressFilter.all.label, "All")
        XCTAssertEqual(LearnProgressFilter.notStarted.label, "Not Started")
        XCTAssertEqual(LearnProgressFilter.completed.label, "Completed")
    }

    //harness:criterion=c-learn-datasource-default-filter-all,c-learn-datasource-all-shows-all-chapters,c-learn-datasource-all-shows-all-sections
    func testDefaultAllFilterShowsAllChaptersAndSections() {
        let dataSource = LearnDataSource()
        let tableView = makeTableView()

        XCTAssertEqual(dataSource.activeFilter, .all)
        XCTAssertEqual(dataSource.numberOfSections(in: tableView), Unwrap.chapters.count)

        for chapterIndex in Unwrap.chapters.indices {
            XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: chapterIndex), Unwrap.chapters[chapterIndex].sections.count)
        }
    }

    //harness:criterion=c-learn-datasource-not-started-hides-learned-sections,c-learn-datasource-not-started-hides-reviewed-sections
    func testNotStartedFilterHidesLearnedAndReviewedSections() {
        let learnedSection = Unwrap.chapters[0].sections[0]
        let reviewedSection = Unwrap.chapters[0].sections[1]
        User.current.learnedSection(learnedSection.bundleName)
        User.current.reviewedSection(reviewedSection.bundleName)

        let dataSource = LearnDataSource()
        let tableView = makeTableView()
        dataSource.activeFilter = .notStarted

        for bundleName in visibleBundleNames(in: dataSource, tableView: tableView) {
            XCTAssertFalse(User.current.hasLearned(bundleName))
            XCTAssertFalse(User.current.hasReviewed(bundleName))
        }
    }

    //harness:criterion=c-learn-datasource-completed-shows-only-learned-and-reviewed
    func testCompletedFilterShowsOnlyLearnedAndReviewedSections() {
        let completedSections = [
            Unwrap.chapters[0].sections[0],
            Unwrap.chapters[1].sections[0]
        ]
        let learnedOnlySection = Unwrap.chapters[0].sections[1]

        completedSections.forEach { User.current.reviewedSection($0.bundleName) }
        User.current.learnedSection(learnedOnlySection.bundleName)

        let dataSource = LearnDataSource()
        let tableView = makeTableView()
        dataSource.activeFilter = .completed
        let visibleBundleNames = visibleBundleNames(in: dataSource, tableView: tableView)

        XCTAssertEqual(Set(visibleBundleNames), Set(completedSections.map { $0.bundleName }))

        for bundleName in visibleBundleNames {
            XCTAssertTrue(User.current.hasLearned(bundleName))
            XCTAssertTrue(User.current.hasReviewed(bundleName))
        }
    }

    //harness:criterion=c-learn-datasource-empty-chapter-hidden,c-learn-datasource-view-for-header-uses-filtered-mapping
    func testNotStartedFilterHidesEmptyChaptersAndUsesFilteredHeaderOrder() {
        let excludedChapter = Unwrap.chapters[0]
        excludedChapter.sections.forEach { User.current.learnedSection($0.bundleName) }

        let dataSource = LearnDataSource()
        let tableView = makeTableView()
        dataSource.activeFilter = .notStarted

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), Unwrap.chapters.count - 1)

        let headerView = dataSource.tableView(tableView, viewForHeaderInSection: 0) as? DynamicHeightHeaderView
        XCTAssertEqual(headerView?.headerLabel.text, Unwrap.chapters[1].name)

        for sectionIndex in 0..<dataSource.numberOfSections(in: tableView) {
            let headerView = dataSource.tableView(tableView, viewForHeaderInSection: sectionIndex) as? DynamicHeightHeaderView
            XCTAssertNotEqual(headerView?.headerLabel.text, excludedChapter.name)
        }
    }

    //harness:criterion=c-learn-datasource-title-resolves-correct-section,c-learn-datasource-number-of-rows-uses-filtered-mapping,c-learn-datasource-cell-for-row-uses-filtered-mapping
    func testFilteredIndexPathsResolveTitlesRowsAndCellsFromFilteredMapping() {
        let excludedSection = Unwrap.chapters[0].sections[0]
        let firstVisibleSection = Unwrap.chapters[0].sections[1]
        User.current.learnedSection(excludedSection.bundleName)

        let dataSource = LearnDataSource()
        let tableView = makeTableView()
        dataSource.activeFilter = .notStarted
        let firstFilteredIndexPath = IndexPath(row: 0, section: 0)

        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: 0), Unwrap.chapters[0].sections.count - 1)
        XCTAssertLessThan(dataSource.tableView(tableView, numberOfRowsInSection: 0), Unwrap.chapters[0].sections.count)
        XCTAssertEqual(dataSource.title(for: firstFilteredIndexPath), firstVisibleSection)
        XCTAssertNotEqual(dataSource.title(for: firstFilteredIndexPath), excludedSection)

        let cell = dataSource.tableView(tableView, cellForRowAt: firstFilteredIndexPath)
        XCTAssertEqual(cell.textLabel?.text, firstVisibleSection)
        XCTAssertNotEqual(cell.textLabel?.text, excludedSection)
    }

    //harness:criterion=c-learn-datasource-did-select-resolves-correct-section
    func testDidSelectUsesFilteredSectionForStudyLaunch() {
        let excludedSection = Unwrap.chapters[0].sections[0]
        let firstVisibleSection = Unwrap.chapters[0].sections[1]
        User.current.learnedSection(excludedSection.bundleName)

        let dataSource = LearnDataSource()
        let tableView = makeTableView()
        let delegate = CapturingLearnViewController(style: .plain)
        dataSource.delegate = delegate
        dataSource.activeFilter = .notStarted

        dataSource.tableView(tableView, didSelectRowAt: IndexPath(row: 0, section: 0))

        XCTAssertEqual(delegate.startedStudyingTitle, firstVisibleSection)
        XCTAssertEqual(delegate.startedStudyingTitle?.bundleName, firstVisibleSection.bundleName)
        XCTAssertNotEqual(delegate.startedStudyingTitle?.bundleName, excludedSection.bundleName)
    }

    //harness:criterion=c-learn-datasource-original-order-preserved
    func testFilteredMappingPreservesOriginalChapterAndSectionOrder() {
        let allSectionTitles = Unwrap.chapters.flatMap { $0.sections }

        for (index, section) in allSectionTitles.enumerated() where index % 2 == 0 {
            User.current.learnedSection(section.bundleName)
        }

        let expectedTitles = allSectionTitles.enumerated().compactMap { index, title in
            index % 2 == 0 ? nil : title
        }

        let dataSource = LearnDataSource()
        let tableView = makeTableView()
        dataSource.activeFilter = .notStarted

        XCTAssertEqual(visibleTitles(in: dataSource, tableView: tableView), expectedTitles)
    }

    //harness:criterion=c-learn-filter-not-started-completed-are-disjoint
    func testNotStartedAndCompletedFiltersAreDisjointForSameUserState() {
        User.current.reviewedSection(Unwrap.chapters[0].sections[0].bundleName)
        User.current.learnedSection(Unwrap.chapters[0].sections[1].bundleName)

        let dataSource = LearnDataSource()
        let tableView = makeTableView()

        dataSource.activeFilter = .notStarted
        let notStarted = Set(visibleBundleNames(in: dataSource, tableView: tableView))

        dataSource.activeFilter = .completed
        let completed = Set(visibleBundleNames(in: dataSource, tableView: tableView))

        XCTAssertTrue(notStarted.intersection(completed).isEmpty)
    }

    //harness:criterion=c-learn-filter-switching-to-all-restores-full-list
    func testSwitchingBackToAllRestoresTheFullList() {
        User.current.learnedSection(Unwrap.chapters[0].sections[0].bundleName)

        let dataSource = LearnDataSource()
        let tableView = makeTableView()
        dataSource.activeFilter = .notStarted
        dataSource.activeFilter = .all

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), Unwrap.chapters.count)

        for chapterIndex in Unwrap.chapters.indices {
            XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: chapterIndex), Unwrap.chapters[chapterIndex].sections.count)
        }
    }

    //harness:criterion=c-learn-filter-completed-empty-when-none-reviewed
    func testCompletedFilterIsEmptyWhenNoSectionsAreReviewed() {
        let dataSource = LearnDataSource()
        let tableView = makeTableView()
        dataSource.activeFilter = .completed

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), 0)
    }

    //harness:criterion=c-learn-vc-segmented-control-present,c-learn-vc-segmented-control-default-all
    func testLearnViewControllerCreatesDefaultAllSegmentedControlHeader() {
        let viewController = makeLoadedLearnViewController()
        let segmentedControl = findSegmentedControl(in: viewController.tableView.tableHeaderView)

        XCTAssertNotNil(segmentedControl)
        XCTAssertEqual(segmentedControl?.numberOfSegments, 3)
        XCTAssertEqual(segmentTitles(in: segmentedControl), ["All", "Not Started", "Completed"])
        XCTAssertEqual(segmentedControl?.selectedSegmentIndex, 0)
        XCTAssertEqual(segmentedControl?.accessibilityLabel, "Learn filter")
        XCTAssertEqual(segmentedControl?.accessibilityValue, "All")
    }

    //harness:criterion=c-learn-vc-segmented-control-updates-filter,c-learn-vc-segmented-control-reloads-table
    func testSegmentedControlSelectionUpdatesEveryFilterModeAndReloadsTable() {
        let viewController = makeLoadedLearnViewController()
        let segmentedControl = findSegmentedControl(in: viewController.tableView.tableHeaderView)!
        let tableView = ReloadTrackingTableView(frame: .zero, style: .plain)
        viewController.tableView = tableView

        let expectations: [(Int, LearnProgressFilter)] = [
            (1, .notStarted),
            (2, .completed),
            (0, .all)
        ]

        for (index, expectedFilter) in expectations {
            tableView.resetReloadDataCallCount()
            segmentedControl.selectedSegmentIndex = index
            viewController.progressFilterChanged(segmentedControl)

            XCTAssertEqual(viewController.dataSource.activeFilter, expectedFilter)
            XCTAssertEqual(segmentedControl.accessibilityValue, expectedFilter.label)
            XCTAssertGreaterThan(tableView.reloadDataCallCount, 0)
        }
    }

    //harness:criterion=c-learn-vc-glossary-button-preserved
    func testGlossaryButtonIsPreserved() {
        let viewController = makeLoadedLearnViewController()
        let button = viewController.navigationItem.rightBarButtonItem

        XCTAssertEqual(button?.title, "Glossary")
        XCTAssertTrue(button?.target === viewController)
        XCTAssertEqual(button?.action, #selector(LearnViewController.showGlossary))
    }

    //harness:criterion=c-learn-vc-user-data-changed-full-reload
    func testUserDataChangedReloadsTableAndRefreshesFilteredMembership() {
        let viewController = makeLoadedLearnViewController()
        NotificationCenter.default.removeObserver(viewController)

        let segmentedControl = findSegmentedControl(in: viewController.tableView.tableHeaderView)!
        segmentedControl.selectedSegmentIndex = 1
        viewController.progressFilterChanged(segmentedControl)

        let firstSection = Unwrap.chapters[0].sections[0]
        XCTAssertEqual(viewController.dataSource.title(for: IndexPath(row: 0, section: 0)), firstSection)

        let tableView = ReloadTrackingTableView(frame: .zero, style: .plain)
        viewController.tableView = tableView
        User.current.learnedSection(firstSection.bundleName)

        viewController.userDataChanged()

        XCTAssertGreaterThan(tableView.reloadDataCallCount, 0)
        XCTAssertNotEqual(viewController.dataSource.title(for: IndexPath(row: 0, section: 0)), firstSection)
        XCTAssertEqual(viewController.dataSource.activeFilter, .notStarted)
        XCTAssertEqual(segmentedControl.selectedSegmentIndex, 1)
        XCTAssertEqual(segmentedControl.accessibilityValue, "Not Started")
    }

    //harness:criterion=c-learn-vc-context-menu-preserved
    func testContextMenuConfigurationIsPreservedForValidRows() {
        let viewController = makeLoadedLearnViewController()
        let tableView = IndexPathResolvingTableView(frame: .zero, style: .plain)
        tableView.indexPathForPoint = IndexPath(row: 0, section: 0)
        viewController.tableView = tableView

        let interaction = UIContextMenuInteraction(delegate: viewController)
        let configuration = viewController.contextMenuInteraction(interaction, configurationForMenuAtLocation: .zero)

        XCTAssertNotNil(configuration)
    }

    //harness:criterion=c-learn-vc-user-status-changed-refresh-preserved
    func testUserStatusChangedNotificationReloadsTable() {
        let viewController = makeLoadedLearnViewController()
        let tableView = ReloadTrackingTableView(frame: .zero, style: .plain)
        viewController.tableView = tableView

        NotificationCenter.default.post(name: .userStatusChanged, object: nil)

        XCTAssertGreaterThan(tableView.reloadDataCallCount, 0)
    }

    private func makeTableView() -> UITableView {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
        return tableView
    }

    private func makeLoadedLearnViewController() -> LearnViewController {
        let viewController = LearnViewController(style: .plain)
        viewController.coordinator = LearnCoordinator()
        viewController.loadViewIfNeeded()

        addTeardownBlock {
            NotificationCenter.default.removeObserver(viewController)
        }

        return viewController
    }

    private func visibleTitles(in dataSource: LearnDataSource, tableView: UITableView) -> [String] {
        var titles = [String]()

        for sectionIndex in 0..<dataSource.numberOfSections(in: tableView) {
            for rowIndex in 0..<dataSource.tableView(tableView, numberOfRowsInSection: sectionIndex) {
                titles.append(dataSource.title(for: IndexPath(row: rowIndex, section: sectionIndex)))
            }
        }

        return titles
    }

    private func visibleBundleNames(in dataSource: LearnDataSource, tableView: UITableView) -> [String] {
        return visibleTitles(in: dataSource, tableView: tableView).map { $0.bundleName }
    }

    private func findSegmentedControl(in view: UIView?) -> UISegmentedControl? {
        guard let view = view else { return nil }

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

    private func segmentTitles(in segmentedControl: UISegmentedControl?) -> [String] {
        guard let segmentedControl = segmentedControl else { return [] }
        return (0..<segmentedControl.numberOfSegments).map { segmentedControl.titleForSegment(at: $0) ?? "" }
    }
}

private final class CapturingLearnViewController: LearnViewController {
    var startedStudyingTitle: String?

    override func startStudying(title: String) {
        startedStudyingTitle = title
    }
}

private final class ReloadTrackingTableView: UITableView {
    private(set) var reloadDataCallCount = 0

    override func reloadData() {
        reloadDataCallCount += 1
        super.reloadData()
    }

    func resetReloadDataCallCount() {
        reloadDataCallCount = 0
    }
}

private final class IndexPathResolvingTableView: UITableView {
    var indexPathForPoint: IndexPath?

    override func indexPathForRow(at point: CGPoint) -> IndexPath? {
        return indexPathForPoint
    }
}
