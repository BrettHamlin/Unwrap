//
//  LearnDataSourceTests.swift
//  UnwrapTests
//
//  Created by Codex on 30/05/2026.
//  Copyright (c) 2026 Hacking with Swift. All rights reserved.
//

import UIKit
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

    func testFilterCasesCompileAndDefaultToAll() {
        //harness:criterion=c-filter-enum-all-not-started-completed,c-filter-default-all
        let dataSource = LearnDataSource(chapters: makeMixedChapters(), user: User())

        dataSource.filter = .all
        XCTAssertEqual(name(for: dataSource.filter), "all")

        dataSource.filter = .notStarted
        XCTAssertEqual(name(for: dataSource.filter), "notStarted")

        dataSource.filter = .completed
        XCTAssertEqual(name(for: dataSource.filter), "completed")

        XCTAssertEqual(Set([name(for: .all), name(for: .notStarted), name(for: .completed)]).count, 3)
        XCTAssertEqual(name(for: LearnDataSource(chapters: makeMixedChapters(), user: User()).filter), "all")
    }

    func testAllFilterReturnsInjectedChaptersInOrder() {
        //harness:criterion=c-visible-chapters-all-returns-all,c-injectable-chapters-param,c-all-filter-preserves-chapter-order
        let chapters = makeMixedChapters()
        let dataSource = LearnDataSource(chapters: chapters, user: User())
        dataSource.filter = .all

        XCTAssertEqual(dataSource.visibleChapters.count, chapters.count)

        for index in chapters.indices {
            XCTAssertEqual(dataSource.visibleChapters[index].chapter, chapters[index])
            XCTAssertEqual(dataSource.visibleChapters[index].sections, chapters[index].sections)
        }
    }

    func testNotStartedFilterHidesProgressAndKeepsUntouchedSections() {
        //harness:criterion=c-visible-chapters-not-started-hides-learned,c-visible-chapters-not-started-hides-reviewed,c-visible-chapters-not-started-keeps-untouched
        let learnedSection = "Learned Syntax"
        let reviewedSection = "Reviewed Syntax"
        let untouchedSection = "Untouched Syntax"
        let chapters = [Chapter(name: "Filtering", sections: [learnedSection, reviewedSection, untouchedSection])]
        let user = User()
        markLearned(learnedSection, on: user)
        markReviewed(reviewedSection, on: user)

        let dataSource = LearnDataSource(chapters: chapters, user: user)
        dataSource.filter = .notStarted

        XCTAssertTrue(user.hasLearned(learnedSection.bundleName))
        XCTAssertTrue(user.hasReviewed(reviewedSection.bundleName))
        XCTAssertFalse(visibleTitles(in: dataSource).contains(learnedSection))
        XCTAssertFalse(visibleTitles(in: dataSource).contains(reviewedSection))
        XCTAssertTrue(visibleTitles(in: dataSource).contains(untouchedSection))
    }

    func testCompletedFilterRequiresLearnedAndReviewedProgress() {
        //harness:criterion=c-visible-chapters-completed-requires-both,c-visible-chapters-completed-excludes-partial
        let completedSection = "Completed Generics"
        let learnedOnlySection = "Learned Generics"
        let untouchedSection = "Untouched Generics"
        let chapters = [Chapter(name: "Generics", sections: [completedSection, learnedOnlySection, untouchedSection])]
        let user = User()
        markReviewed(completedSection, on: user)
        markLearned(learnedOnlySection, on: user)

        let dataSource = LearnDataSource(chapters: chapters, user: user)
        dataSource.filter = .completed

        XCTAssertEqual(visibleTitles(in: dataSource), [completedSection])
        XCTAssertFalse(visibleTitles(in: dataSource).contains(learnedOnlySection))
    }

    func testEmptyChaptersAreHiddenForActiveFilters() {
        //harness:criterion=c-empty-chapter-hidden
        let completedSection = "Completed Protocols"
        let untouchedSection = "Untouched Protocols"
        let chapters = [
            Chapter(name: "Finished Chapter", sections: [completedSection]),
            Chapter(name: "Fresh Chapter", sections: [untouchedSection])
        ]
        let user = User()
        markReviewed(completedSection, on: user)

        let dataSource = LearnDataSource(chapters: chapters, user: user)

        dataSource.filter = .notStarted
        XCTAssertEqual(dataSource.visibleChapters.map { $0.chapter.name }, ["Fresh Chapter"])

        dataSource.filter = .completed
        XCTAssertEqual(dataSource.visibleChapters.map { $0.chapter.name }, ["Finished Chapter"])
    }

    func testTableSectionAndRowCountsMatchVisibleMapping() {
        //harness:criterion=c-number-of-sections-matches-visible,c-number-of-rows-matches-visible-sections
        let chapters = makeMixedChapters()
        let user = User()
        markReviewed("Completed Closures", on: user)
        markLearned("Learned Closures", on: user)
        let dataSource = LearnDataSource(chapters: chapters, user: user)
        let tableView = UITableView()

        for filter in [LearnDataSource.Filter.all, .notStarted, .completed] {
            dataSource.filter = filter
            XCTAssertEqual(dataSource.numberOfSections(in: tableView), dataSource.visibleChapters.count)

            for section in 0..<dataSource.visibleChapters.count {
                XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: section), dataSource.visibleChapters[section].sections.count)
            }
        }
    }

    func testVisibleMappingIsUsedForTitlesHeadersAndCells() {
        //harness:criterion=c-title-for-resolves-correct-section,c-view-for-header-uses-visible-chapter,c-cell-for-row-uses-visible-section
        let hiddenSection = "Learned Dictionaries"
        let visibleSection = "Untouched Dictionaries"
        let chapters = [
            Chapter(name: "Hidden Chapter", sections: ["Hidden Chapter Section"]),
            Chapter(name: "Visible Chapter", sections: [hiddenSection, visibleSection])
        ]
        let user = User()
        markLearned("Hidden Chapter Section", on: user)
        markLearned(hiddenSection, on: user)
        let dataSource = LearnDataSource(chapters: chapters, user: user)
        dataSource.filter = .notStarted

        let tableView = UITableView()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")

        XCTAssertEqual(dataSource.title(for: IndexPath(row: 0, section: 0)), visibleSection)
        XCTAssertNotEqual(chapters[0].sections[0], visibleSection)

        let header = dataSource.tableView(tableView, viewForHeaderInSection: 0) as? DynamicHeightHeaderView
        XCTAssertEqual(header?.headerLabel.text, "Visible Chapter")

        let cell = dataSource.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(cell.textLabel?.text, visibleSection)
    }

    func testDidSelectUsesVisibleMapping() {
        //harness:criterion=c-did-select-resolves-correct-section
        let hiddenSection = "Variables"
        let visibleSection = "Constants"
        let chapters = [Chapter(name: "Functions", sections: [hiddenSection, visibleSection])]
        let user = User()
        markLearned(hiddenSection, on: user)
        let dataSource = LearnDataSource(chapters: chapters, user: user)
        dataSource.filter = .notStarted
        let coordinator = LearnCoordinator()
        let viewController = LearnViewController(style: .plain)
        viewController.coordinator = coordinator
        dataSource.delegate = viewController

        dataSource.tableView(UITableView(), didSelectRowAt: IndexPath(row: 0, section: 0))

        XCTAssertEqual(coordinator.activeStudyReview.title, visibleSection)
        XCTAssertNotEqual(chapters[0].sections[0], visibleSection)
    }

    func testInjectedUserControlsProgressFiltering() {
        //harness:criterion=c-injectable-user-param
        let section = "Injected User Section"
        let chapters = [Chapter(name: "Injected", sections: [section])]
        let freshUser = User()
        let progressedUser = User()
        markLearned(section, on: progressedUser)

        let freshDataSource = LearnDataSource(chapters: chapters, user: freshUser)
        freshDataSource.filter = .notStarted

        let progressedDataSource = LearnDataSource(chapters: chapters, user: progressedUser)
        progressedDataSource.filter = .notStarted

        XCTAssertEqual(visibleTitles(in: freshDataSource), [section])
        XCTAssertTrue(visibleTitles(in: progressedDataSource).isEmpty)
    }

    func testSegmentedControlIsInstalledInTableHeader() {
        //harness:criterion=c-segmented-control-three-segments,c-segmented-control-default-all-selected,c-segmented-control-embedded-in-header
        let viewController = makeLoadedLearnViewController()
        let segmentedControl = findSegmentedControl(in: viewController.tableView.tableHeaderView)

        XCTAssertNotNil(viewController.tableView.tableHeaderView)
        XCTAssertNotNil(segmentedControl)
        XCTAssertEqual(segmentedControl?.numberOfSegments, 3)
        XCTAssertEqual(segmentedControl?.titleForSegment(at: 0), "All")
        XCTAssertEqual(segmentedControl?.titleForSegment(at: 1), "Not Started")
        XCTAssertEqual(segmentedControl?.titleForSegment(at: 2), "Completed")
        XCTAssertEqual(segmentedControl?.selectedSegmentIndex, 0)
        XCTAssertEqual(segmentedControl?.accessibilityLabel, "Learn filter")
        XCTAssertEqual(segmentedControl?.accessibilityValue, "All")
    }

    func testSegmentChangesUpdateFilterAndReloadTable() {
        //harness:criterion=c-segment-change-updates-filter,c-segment-change-triggers-reload
        let viewController = makeLoadedLearnViewController()
        let segmentedControl = findSegmentedControl(in: viewController.tableView.tableHeaderView)!
        let tableView = ReloadTrackingTableView(frame: .zero, style: .plain)
        viewController.tableView = tableView

        let cases: [(Int, LearnDataSource.Filter, String)] = [
            (1, .notStarted, "Not Started"),
            (2, .completed, "Completed"),
            (0, .all, "All")
        ]

        for (index, expectedFilter, expectedAccessibilityValue) in cases {
            let previousReloadCount = tableView.reloadDataCallCount
            segmentedControl.selectedSegmentIndex = index

            viewController.filterChanged(segmentedControl)

            XCTAssertEqual(name(for: viewController.dataSource.filter), name(for: expectedFilter))
            XCTAssertEqual(segmentedControl.accessibilityValue, expectedAccessibilityValue)
            XCTAssertEqual(tableView.reloadDataCallCount, previousReloadCount + 1)
        }
    }

    func testUserDataChangedReloadsTable() {
        //harness:criterion=c-user-data-changed-calls-reload
        let section = "Refreshable Section"
        let user = User()
        let dataSource = LearnDataSource(chapters: [Chapter(name: "Refresh", sections: [section])], user: user)
        let viewController = makeLoadedLearnViewController(dataSource: dataSource)
        let segmentedControl = findSegmentedControl(in: viewController.tableView.tableHeaderView)!
        let tableView = ReloadTrackingTableView(frame: .zero, style: .plain)
        viewController.tableView = tableView

        segmentedControl.selectedSegmentIndex = 1
        viewController.filterChanged(segmentedControl)
        XCTAssertEqual(visibleTitles(in: dataSource), [section])

        markLearned(section, on: user)
        let previousReloadCount = tableView.reloadDataCallCount

        viewController.userDataChanged()

        XCTAssertEqual(tableView.reloadDataCallCount, previousReloadCount + 1)
        XCTAssertEqual(name(for: dataSource.filter), name(for: .notStarted))
        XCTAssertEqual(segmentedControl.accessibilityValue, "Not Started")
        XCTAssertTrue(visibleTitles(in: dataSource).isEmpty)
    }

    func testContextMenuUsesVisibleMapping() {
        //harness:criterion=c-context-menu-resolves-correct-section
        let hiddenSection = "Variables"
        let visibleSection = "Constants"
        let chapters = [Chapter(name: "Arrays", sections: [hiddenSection, visibleSection])]
        let user = User()
        markLearned(hiddenSection, on: user)
        let dataSource = LearnDataSource(chapters: chapters, user: user)
        dataSource.filter = .notStarted

        let coordinator = LearnCoordinator()
        let viewController = makeLoadedLearnViewController(dataSource: dataSource, coordinator: coordinator)
        let tableView = ReloadTrackingTableView(frame: .zero, style: .plain)
        tableView.indexPathForRowAtPoint = IndexPath(row: 0, section: 0)
        viewController.tableView = tableView

        let configuration = viewController.contextMenuInteraction(UIContextMenuInteraction(delegate: viewController), configurationForMenuAtLocation: .zero)
        let previewController = configuration?.previewProvider?()

        XCTAssertNotNil(configuration)
        XCTAssertEqual(previewController?.title, visibleSection)
        XCTAssertNotEqual(hiddenSection, visibleSection)
    }

    private func makeMixedChapters() -> [Chapter] {
        return [
            Chapter(name: "Closures", sections: ["Completed Closures", "Learned Closures", "Untouched Closures"]),
            Chapter(name: "Optionals", sections: ["Untouched Optionals", "Another Untouched Optional"])
        ]
    }

    private func visibleTitles(in dataSource: LearnDataSource) -> [String] {
        return dataSource.visibleChapters.flatMap { $0.sections }
    }

    private func markLearned(_ section: String, on user: User) {
        User.current = user
        user.learnedSection(section.bundleName)
    }

    private func markReviewed(_ section: String, on user: User) {
        User.current = user
        user.reviewedSection(section.bundleName)
    }

    private func name(for filter: LearnDataSource.Filter) -> String {
        switch filter {
        case .all:
            return "all"
        case .notStarted:
            return "notStarted"
        case .completed:
            return "completed"
        }
    }

    private func makeLoadedLearnViewController(dataSource: LearnDataSource = LearnDataSource(chapters: [Chapter(name: "Default", sections: ["Default Section"])], user: User()), coordinator: LearnCoordinator = LearnCoordinator()) -> LearnViewController {
        let viewController = LearnViewController(style: .plain)
        viewController.coordinator = coordinator
        viewController.dataSource = dataSource
        viewController.loadViewIfNeeded()
        return viewController
    }

    private func findSegmentedControl(in view: UIView?) -> UISegmentedControl? {
        if let segmentedControl = view as? UISegmentedControl {
            return segmentedControl
        }

        for subview in view?.subviews ?? [] {
            if let segmentedControl = findSegmentedControl(in: subview) {
                return segmentedControl
            }
        }

        return nil
    }
}

private final class ReloadTrackingTableView: UITableView {
    var reloadDataCallCount = 0
    var indexPathForRowAtPoint: IndexPath?

    override func reloadData() {
        reloadDataCallCount += 1
        super.reloadData()
    }

    override func indexPathForRow(at point: CGPoint) -> IndexPath? {
        return indexPathForRowAtPoint ?? super.indexPathForRow(at: point)
    }
}
