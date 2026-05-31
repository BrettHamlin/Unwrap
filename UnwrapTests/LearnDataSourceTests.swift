//
//  LearnDataSourceTests.swift
//  UnwrapTests
//
//  Created by OpenAI on 30/05/2026.
//  Copyright 2026 Hacking with Swift. All rights reserved.
//

import UIKit
import XCTest
@testable import Unwrap

class LearnDataSourceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        User.current = User()
    }

    //harness:criterion=c-filter-enum-three-cases
    func testFilterModeHasOnlyAllNotStartedAndCompleted() {
        let modes: [LearnDataSource.FilterMode] = [.all, .notStarted, .completed]

        XCTAssertEqual(LearnDataSource.FilterMode.allCases.count, 3)
        XCTAssertEqual(LearnDataSource.FilterMode.allCases, modes)
    }

    //harness:criterion=c-filter-default-all,c-filter-all-section-count
    func testInitialFilterIsAllAndShowsEveryChapter() {
        let user = freshCurrentUser()
        let dataSource = LearnDataSource(user: user)

        XCTAssertEqual(dataSource.activeFilter, .all)
        XCTAssertEqual(dataSource.visibleChapters.count, Unwrap.chapters.count)
        XCTAssertEqual(dataSource.visibleChapters.map(\.name), Unwrap.chapters.map(\.name))
        XCTAssertEqual(dataSource.visibleChapters.map(\.sections), Unwrap.chapters.map(\.sections))
        XCTAssertEqual(dataSource.numberOfSections(in: UITableView()), Unwrap.chapters.count)
    }

    //harness:criterion=c-all-filter-no-chapter-dropped
    func testAllFilterKeepsEveryChapterDespiteProgress() {
        let user = freshCurrentUser()
        let progressedChapters = Array(Unwrap.chapters.prefix(2))

        for chapter in progressedChapters {
            for section in chapter.sections {
                user.reviewedSection(section.bundleName)
            }
        }

        let dataSource = LearnDataSource(user: user)
        dataSource.activeFilter = .all

        XCTAssertEqual(dataSource.visibleChapters.count, Unwrap.chapters.count)
        XCTAssertEqual(dataSource.visibleChapters.map(\.name), Unwrap.chapters.map(\.name))
    }

    //harness:criterion=c-filter-not-started-hides-learned,c-filter-not-started-hides-reviewed,c-filter-not-started-keeps-untouched
    func testNotStartedFilterExcludesLearnedAndReviewedButKeepsUntouchedSections() {
        let user = freshCurrentUser()
        let sections = firstDistinctSectionTitles(count: 3)
        let learnedSection = sections[0]
        let reviewedSection = sections[1]
        let untouchedSection = sections[2]

        user.learnedSection(learnedSection.bundleName)
        user.reviewedSection(reviewedSection.bundleName)

        let dataSource = LearnDataSource(user: user)
        dataSource.activeFilter = .notStarted

        XCTAssertFalse(visibleTitles(in: dataSource).contains(learnedSection))
        XCTAssertFalse(visibleTitles(in: dataSource).contains(reviewedSection))
        XCTAssertTrue(visibleTitles(in: dataSource).contains(untouchedSection))

        for section in visibleTitles(in: dataSource) {
            XCTAssertFalse(user.hasLearned(section.bundleName))
            XCTAssertFalse(user.hasReviewed(section.bundleName))
        }
    }

    //harness:criterion=c-filter-completed-requires-both,c-filter-completed-excludes-partial
    func testCompletedFilterIncludesOnlyFullyCompletedSectionsAndExcludesPartialProgress() {
        let user = freshCurrentUser()
        let sections = firstDistinctSectionTitles(count: 2)
        let completedSection = sections[0]
        let learnedOnlySection = sections[1]

        user.reviewedSection(completedSection.bundleName)
        user.learnedSection(learnedOnlySection.bundleName)

        let dataSource = LearnDataSource(user: user)
        dataSource.activeFilter = .completed

        XCTAssertTrue(visibleTitles(in: dataSource).contains(completedSection))
        XCTAssertFalse(visibleTitles(in: dataSource).contains(learnedOnlySection))

        for section in visibleTitles(in: dataSource) {
            XCTAssertTrue(user.hasLearned(section.bundleName))
            XCTAssertTrue(user.hasReviewed(section.bundleName))
        }
    }

    //harness:criterion=c-empty-chapter-hidden,c-number-of-sections-from-visible,c-number-of-rows-from-visible
    func testFilteredModelHidesEmptyChaptersAndSectionRowCountsUseVisibleChapters() {
        let user = freshCurrentUser()
        let hiddenChapter = Unwrap.chapters[0]

        for section in hiddenChapter.sections {
            user.learnedSection(section.bundleName)
        }

        let dataSource = LearnDataSource(user: user)
        dataSource.activeFilter = .notStarted
        let tableView = UITableView()

        XCTAssertFalse(dataSource.visibleChapters.contains { $0.name == hiddenChapter.name })
        XCTAssertFalse(dataSource.visibleChapters.contains { $0.sections.isEmpty })
        XCTAssertEqual(dataSource.numberOfSections(in: tableView), dataSource.visibleChapters.count)
        XCTAssertLessThan(dataSource.numberOfSections(in: tableView), Unwrap.chapters.count)

        for section in dataSource.visibleChapters.indices {
            XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: section), dataSource.visibleChapters[section].sections.count)
        }
    }

    //harness:criterion=c-title-resolves-after-filter,c-viewforheader-reads-visible-chapters,c-cellforrow-reads-visible-chapters
    func testTitleHeaderAndCellUseFilteredVisibleChapters() {
        let user = freshCurrentUser()
        let hiddenChapter = Unwrap.chapters[0]

        for section in hiddenChapter.sections {
            user.learnedSection(section.bundleName)
        }

        let dataSource = LearnDataSource(user: user)
        dataSource.activeFilter = .notStarted
        let indexPath = IndexPath(row: 0, section: 0)
        let firstVisibleChapter = dataSource.visibleChapters[0]
        let firstVisibleTitle = firstVisibleChapter.sections[0]

        XCTAssertNotEqual(firstVisibleChapter.name, hiddenChapter.name)
        XCTAssertEqual(dataSource.title(for: indexPath), firstVisibleTitle)
        XCTAssertNotEqual(dataSource.title(for: indexPath), hiddenChapter.sections[0])

        let tableView = UITableView()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")

        let headerView = dataSource.tableView(tableView, viewForHeaderInSection: 0) as? DynamicHeightHeaderView
        XCTAssertEqual(headerView?.headerLabel.text, firstVisibleChapter.name)

        let cell = dataSource.tableView(tableView, cellForRowAt: indexPath)
        XCTAssertEqual(cell.textLabel?.text, firstVisibleTitle)
    }

    //harness:criterion=c-row-selection-resolves-after-filter
    func testSelectionUsesFilteredTitleForNavigation() {
        let user = freshCurrentUser()
        let hiddenChapter = Unwrap.chapters[0]

        for section in hiddenChapter.sections {
            user.learnedSection(section.bundleName)
        }

        let dataSource = LearnDataSource(user: user)
        dataSource.activeFilter = .notStarted
        let delegate = CapturingLearnViewController(style: .plain)
        dataSource.delegate = delegate
        let indexPath = IndexPath(row: 0, section: 0)

        dataSource.tableView(UITableView(), didSelectRowAt: indexPath)

        XCTAssertEqual(delegate.startedTitle, dataSource.title(for: indexPath))
        XCTAssertEqual(delegate.startedTitle, dataSource.visibleChapters[0].sections[0])
    }

    //harness:criterion=c-filter-change-does-not-mutate-raw-chapters
    func testChangingFiltersDoesNotMutateRawChapters() {
        let user = freshCurrentUser()
        let originalChapterCount = Unwrap.chapters.count
        let originalSectionCounts = Unwrap.chapters.map { $0.sections.count }

        let dataSource = LearnDataSource(user: user)
        dataSource.activeFilter = .notStarted
        dataSource.activeFilter = .completed
        dataSource.activeFilter = .all

        XCTAssertEqual(Unwrap.chapters.count, originalChapterCount)
        XCTAssertEqual(Unwrap.chapters.map { $0.sections.count }, originalSectionCounts)
    }

    //harness:criterion=c-segmented-control-three-segments,c-segmented-control-default-selected
    func testProgressFilterControlHasExpectedSegmentsAndDefaultsToAll() {
        let viewController = makeLoadedLearnViewController()
        let control = viewController.progressFilterControl

        XCTAssertEqual(control.numberOfSegments, 3)
        XCTAssertEqual(control.titleForSegment(at: 0), "All")
        XCTAssertEqual(control.titleForSegment(at: 1), "Not Started")
        XCTAssertEqual(control.titleForSegment(at: 2), "Completed")
        XCTAssertEqual(control.selectedSegmentIndex, 0)
        XCTAssertEqual(control.accessibilityLabel, "Learn filter")
        XCTAssertEqual(control.accessibilityValue, "All")
    }

    //harness:criterion=c-segmented-control-wired-to-datasource
    func testProgressFilterActionUpdatesDataSourceAndReloadsTable() {
        let viewController = makeLoadedLearnViewController()
        let tableView = ReloadCountingTableView()
        viewController.tableView = tableView
        tableView.reloadDataCallCount = 0

        let actions = viewController.progressFilterControl.actions(forTarget: viewController, forControlEvent: .valueChanged) ?? []
        XCTAssertEqual(actions, ["progressFilterChanged"])

        viewController.progressFilterControl.selectedSegmentIndex = 1
        viewController.progressFilterChanged()
        XCTAssertEqual(viewController.dataSource.activeFilter, .notStarted)
        XCTAssertEqual(viewController.progressFilterControl.accessibilityValue, "Not Started")
        XCTAssertEqual(tableView.reloadDataCallCount, 1)

        viewController.progressFilterControl.selectedSegmentIndex = 2
        viewController.progressFilterChanged()
        XCTAssertEqual(viewController.dataSource.activeFilter, .completed)
        XCTAssertEqual(viewController.progressFilterControl.accessibilityValue, "Completed")
        XCTAssertEqual(tableView.reloadDataCallCount, 2)

        viewController.progressFilterControl.selectedSegmentIndex = 0
        viewController.progressFilterChanged()
        XCTAssertEqual(viewController.dataSource.activeFilter, .all)
        XCTAssertEqual(viewController.progressFilterControl.accessibilityValue, "All")
        XCTAssertEqual(tableView.reloadDataCallCount, 3)
    }

    //harness:criterion=c-user-data-changed-rebuilds-filtered-model
    func testUserDataChangedRebuildsCurrentFilterBeforeReloading() {
        let user = freshCurrentUser()
        let viewController = makeLoadedLearnViewController(user: user)

        viewController.progressFilterControl.selectedSegmentIndex = 1
        viewController.progressFilterChanged()

        let titleToHide = viewController.dataSource.visibleChapters[0].sections[0]
        XCTAssertTrue(visibleTitles(in: viewController.dataSource).contains(titleToHide))

        let tableView = ReloadCountingTableView()
        viewController.tableView = tableView
        tableView.reloadDataCallCount = 0
        user.learnedSection(titleToHide.bundleName)

        viewController.userDataChanged()

        XCTAssertFalse(visibleTitles(in: viewController.dataSource).contains(titleToHide))
        XCTAssertEqual(viewController.dataSource.activeFilter, .notStarted)
        XCTAssertEqual(viewController.progressFilterControl.selectedSegmentIndex, 1)
        XCTAssertEqual(viewController.progressFilterControl.accessibilityValue, "Not Started")
        XCTAssertEqual(tableView.reloadDataCallCount, 1)
    }

    private func freshCurrentUser() -> User {
        let user = User()
        User.current = user
        return user
    }

    private func visibleTitles(in dataSource: LearnDataSource) -> [String] {
        return dataSource.visibleChapters.flatMap(\.sections)
    }

    private func firstDistinctSectionTitles(count: Int) -> [String] {
        let titles = Unwrap.chapters.flatMap(\.sections)
        var result = [String]()

        for title in titles where result.contains(title) == false {
            result.append(title)

            if result.count == count {
                return result
            }
        }

        XCTFail("Expected at least \(count) distinct learn section titles.")
        return result
    }

    private func makeLoadedLearnViewController(user: User? = nil) -> LearnViewController {
        if let user = user {
            User.current = user
        } else {
            _ = freshCurrentUser()
        }

        let coordinator = LearnCoordinator()
        let navigationController = coordinator.primaryNavigationController
        let viewController = navigationController.viewControllers[0] as! LearnViewController
        viewController.loadViewIfNeeded()
        return viewController
    }
}

private class CapturingLearnViewController: LearnViewController {
    var startedTitle: String?

    override func startStudying(title: String) {
        startedTitle = title
    }
}

private class ReloadCountingTableView: UITableView {
    var reloadDataCallCount = 0

    override func reloadData() {
        reloadDataCallCount += 1
        super.reloadData()
    }
}
