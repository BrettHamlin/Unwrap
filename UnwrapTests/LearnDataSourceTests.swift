//
//  LearnDataSourceTests.swift
//  UnwrapTests
//
//  Created by OpenAI on 30/05/2026.
//  Copyright (c) 2026 Hacking with Swift. All rights reserved.
//

import UIKit
import XCTest
@testable import Unwrap

class LearnDataSourceTests: XCTestCase {
    private var previousUser: User?

    override func setUp() {
        super.setUp()
        previousUser = User.current
        User.current = User()
    }

    override func tearDown() {
        User.current = previousUser
        previousUser = nil
        super.tearDown()
    }

    //harness:criterion=c-learn-filter-enum-cases,c-learn-datasource-tests-file-exists,c-learn-datasource-tests-user-setup-teardown
    func testLearnFilterContainsOnlyExpectedCases() {
        XCTAssertEqual(LearnFilter.allCases.count, 3)
        XCTAssertEqual(LearnFilter.allCases, [.all, .notStarted, .completed])

        let titles = LearnFilter.allCases.map { filter -> String in
            switch filter {
            case .all:
                return "All"
            case .notStarted:
                return "Not Started"
            case .completed:
                return "Completed"
            }
        }

        XCTAssertEqual(titles, ["All", "Not Started", "Completed"])
    }

    //harness:criterion=c-learn-filter-default-all
    func testDefaultFilterIsAll() {
        let dataSource = LearnDataSource()

        XCTAssertEqual(dataSource.currentFilter, .all)
    }

    //harness:criterion=c-learn-filter-all-shows-every-chapter
    func testAllFilterShowsEveryChapter() {
        let dataSource = LearnDataSource()
        dataSource.currentFilter = .all

        XCTAssertEqual(dataSource.numberOfSections(in: UITableView()), nonEmptyChapters.count)
    }

    //harness:criterion=c-learn-filter-all-shows-every-section
    func testAllFilterShowsEverySectionInOrder() {
        let dataSource = LearnDataSource()
        dataSource.currentFilter = .all
        let tableView = UITableView()

        for (index, chapter) in nonEmptyChapters.enumerated() {
            XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: index), chapter.sections.count)
            XCTAssertEqual(dataSource.visibleChapters[index].sections, chapter.sections)
        }
    }

    //harness:criterion=c-learn-filter-not-started-hides-learned-sections
    func testNotStartedHidesLearnedSections() {
        let learnedSection = firstSection()
        User.current.learnedSection(learnedSection.bundleName)

        let dataSource = LearnDataSource()
        dataSource.currentFilter = .notStarted

        XCTAssertFalse(visibleSectionBundleNames(in: dataSource).contains(learnedSection.bundleName))
    }

    //harness:criterion=c-learn-filter-not-started-hides-reviewed-sections
    func testNotStartedHidesReviewedSections() {
        let reviewedSection = firstSection()
        User.current.reviewedSection(reviewedSection.bundleName)

        let dataSource = LearnDataSource()
        dataSource.currentFilter = .notStarted

        XCTAssertFalse(visibleSectionBundleNames(in: dataSource).contains(reviewedSection.bundleName))
    }

    //harness:criterion=c-learn-filter-not-started-shows-unstarted-sections,c-learn-filter-no-networking-or-persistence
    func testNotStartedShowsOnlyUnstartedSections() {
        let sections = firstSections(count: 3)
        User.current.learnedSection(sections[0].bundleName)
        User.current.reviewedSection(sections[1].bundleName)

        let dataSource = LearnDataSource()
        dataSource.currentFilter = .notStarted

        for section in visibleSections(in: dataSource) {
            XCTAssertFalse(User.current.hasLearned(section.bundleName))
            XCTAssertFalse(User.current.hasReviewed(section.bundleName))
        }

        XCTAssertFalse(visibleSectionBundleNames(in: dataSource).contains(sections[0].bundleName))
        XCTAssertFalse(visibleSectionBundleNames(in: dataSource).contains(sections[1].bundleName))
        XCTAssertTrue(visibleSectionBundleNames(in: dataSource).contains(sections[2].bundleName))
    }

    //harness:criterion=c-learn-filter-completed-shows-fully-done-sections
    func testCompletedShowsFullyDoneSections() {
        let completedSection = firstSection()
        User.current.reviewedSection(completedSection.bundleName)

        let dataSource = LearnDataSource()
        dataSource.currentFilter = .completed

        XCTAssertTrue(visibleSectionBundleNames(in: dataSource).contains(completedSection.bundleName))

        for section in visibleSections(in: dataSource) {
            XCTAssertTrue(User.current.hasLearned(section.bundleName))
            XCTAssertTrue(User.current.hasReviewed(section.bundleName))
        }
    }

    //harness:criterion=c-learn-filter-completed-hides-partial-sections
    func testCompletedHidesPartialSections() throws {
        let sections = firstSections(count: 2)
        let learnedOnlySection = sections[0]
        let reviewedOnlySection = sections[1]
        User.current.learnedSection(learnedOnlySection.bundleName)

        let learnedOnlyDataSource = LearnDataSource()
        learnedOnlyDataSource.currentFilter = .completed

        XCTAssertTrue(User.current.hasLearned(learnedOnlySection.bundleName))
        XCTAssertFalse(User.current.hasReviewed(learnedOnlySection.bundleName))
        XCTAssertFalse(visibleSectionBundleNames(in: learnedOnlyDataSource).contains(learnedOnlySection.bundleName))

        User.current = try user(learned: [], reviewed: [reviewedOnlySection.bundleName])
        let reviewedOnlyDataSource = LearnDataSource()
        reviewedOnlyDataSource.currentFilter = .completed

        XCTAssertFalse(User.current.hasLearned(reviewedOnlySection.bundleName))
        XCTAssertTrue(User.current.hasReviewed(reviewedOnlySection.bundleName))
        XCTAssertFalse(visibleSectionBundleNames(in: reviewedOnlyDataSource).contains(reviewedOnlySection.bundleName))
    }

    //harness:criterion=c-learn-filter-hides-empty-chapters
    func testEmptyChaptersAreHidden() {
        let hiddenChapter = nonEmptyChapters[0]
        hiddenChapter.sections.forEach { User.current.reviewedSection($0.bundleName) }

        let dataSource = LearnDataSource()
        dataSource.currentFilter = .notStarted

        let expectedVisibleChapters = nonEmptyChapters.filter { chapter in
            chapter.sections.contains {
                User.current.hasLearned($0.bundleName) == false && User.current.hasReviewed($0.bundleName) == false
            }
        }

        XCTAssertFalse(dataSource.visibleChapters.map(\.name).contains(hiddenChapter.name))
        XCTAssertEqual(dataSource.visibleChapters.count, expectedVisibleChapters.count)
        XCTAssertEqual(dataSource.numberOfSections(in: UITableView()), expectedVisibleChapters.count)
    }

    //harness:criterion=c-learn-filter-preserves-original-order
    func testFilterPreservesOriginalOrder() {
        for (index, section) in allSections.enumerated() where index.isMultiple(of: 2) {
            User.current.learnedSection(section.bundleName)
        }

        let dataSource = LearnDataSource()
        dataSource.currentFilter = .notStarted

        let expectedChapters = nonEmptyChapters.compactMap { chapter -> VisibleChapter? in
            let sections = chapter.sections.filter {
                User.current.hasLearned($0.bundleName) == false && User.current.hasReviewed($0.bundleName) == false
            }

            return sections.isEmpty ? nil : VisibleChapter(name: chapter.name, sections: sections)
        }

        XCTAssertEqual(dataSource.visibleChapters.map(\.name), expectedChapters.map(\.name))

        for (visibleChapter, expectedChapter) in zip(dataSource.visibleChapters, expectedChapters) {
            XCTAssertEqual(visibleChapter.sections.map(\.bundleName), expectedChapter.sections.map(\.bundleName))
        }
    }

    //harness:criterion=c-learn-title-for-resolves-filtered-index-path
    func testTitleForResolvesFilteredIndexPath() {
        User.current.reviewedSection(firstSection().bundleName)

        let dataSource = LearnDataSource()
        dataSource.currentFilter = .notStarted
        let expectedTitle = dataSource.visibleChapters[0].sections[0]

        XCTAssertEqual(dataSource.title(for: IndexPath(row: 0, section: 0)), expectedTitle)
    }

    //harness:criterion=c-learn-header-uses-filtered-chapter
    func testHeaderUsesFilteredChapter() {
        let hiddenChapter = nonEmptyChapters[0]
        hiddenChapter.sections.forEach { User.current.reviewedSection($0.bundleName) }

        let dataSource = LearnDataSource()
        dataSource.currentFilter = .notStarted
        let tableView = UITableView()
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")

        let header = dataSource.tableView(tableView, viewForHeaderInSection: 0) as? DynamicHeightHeaderView

        XCTAssertEqual(header?.headerLabel.text, dataSource.visibleChapters[0].name)
        XCTAssertNotEqual(header?.headerLabel.text, hiddenChapter.name)
    }

    //harness:criterion=c-learn-did-select-uses-filtered-mapping
    func testDidSelectUsesFilteredMapping() {
        User.current.learnedSection(firstSection().bundleName)
        let dataSource = LearnDataSource()
        dataSource.currentFilter = .notStarted
        let viewController = StudyCaptureLearnViewController(style: .plain)
        dataSource.delegate = viewController
        let indexPath = IndexPath(row: 0, section: 0)

        dataSource.tableView(UITableView(), didSelectRowAt: indexPath)

        XCTAssertEqual(viewController.startedTitle, dataSource.title(for: indexPath))
    }

    //harness:criterion=c-learn-segmented-control-three-segments
    func testSegmentedControlHasThreeSegments() {
        let viewController = makeLoadedLearnViewController()
        let segmentedControl = findSegmentedControl(in: viewController.view)

        XCTAssertEqual(segmentedControl?.numberOfSegments, 3)
        XCTAssertEqual(segmentedControl?.titleForSegment(at: 0), "All")
        XCTAssertEqual(segmentedControl?.titleForSegment(at: 1), "Not Started")
        XCTAssertEqual(segmentedControl?.titleForSegment(at: 2), "Completed")
        XCTAssertEqual(segmentedControl?.accessibilityLabel, "Learn filter")
    }

    //harness:criterion=c-learn-segmented-control-default-segment
    func testSegmentedControlDefaultsToAll() {
        let viewController = makeLoadedLearnViewController()
        let segmentedControl = findSegmentedControl(in: viewController.view)

        XCTAssertEqual(segmentedControl?.selectedSegmentIndex, 0)
        XCTAssertEqual(segmentedControl?.accessibilityValue, "All")
        XCTAssertEqual(viewController.dataSource.currentFilter, .all)
    }

    //harness:criterion=c-learn-segmented-control-updates-filter
    func testSegmentedControlUpdatesFilter() {
        let viewController = makeLoadedLearnViewController()

        let expectations: [(Int, LearnFilter, String)] = [
            (0, .all, "All"),
            (1, .notStarted, "Not Started"),
            (2, .completed, "Completed")
        ]

        for (index, expectedFilter, expectedAccessibilityValue) in expectations {
            viewController.filterControl.selectedSegmentIndex = index
            viewController.filterChanged()

            XCTAssertEqual(viewController.dataSource.currentFilter, expectedFilter)
            XCTAssertEqual(viewController.filterControl.accessibilityValue, expectedAccessibilityValue)
        }
    }

    //harness:criterion=c-learn-segmented-control-triggers-reload
    func testSegmentedControlTriggersReload() {
        User.current.learnedSection(firstSection().bundleName)
        let viewController = makeLoadedLearnViewController()
        let tableView = installSpyTableView(on: viewController)

        viewController.filterControl.selectedSegmentIndex = LearnFilter.notStarted.rawValue
        viewController.filterChanged()

        XCTAssertEqual(viewController.dataSource.currentFilter, .notStarted)
        XCTAssertEqual(tableView.reloadDataCallCount, 1)
        XCTAssertEqual(tableView.numberOfSections, viewController.dataSource.numberOfSections(in: tableView))
    }

    //harness:criterion=c-learn-user-data-changed-full-reload
    func testUserDataChangedPerformsFullReload() {
        let viewController = makeLoadedLearnViewController()
        let tableView = installSpyTableView(on: viewController)
        viewController.filterControl.selectedSegmentIndex = LearnFilter.notStarted.rawValue
        viewController.filterChanged()
        let reloadCountAfterSelection = tableView.reloadDataCallCount

        let chapterToHide = viewController.dataSource.visibleChapters[0]
        chapterToHide.sections.forEach { User.current.reviewedSection($0.bundleName) }
        viewController.userDataChanged()

        XCTAssertEqual(tableView.reloadDataCallCount, reloadCountAfterSelection + 1)
        XCTAssertEqual(viewController.dataSource.currentFilter, .notStarted)
        XCTAssertEqual(viewController.filterControl.selectedSegmentIndex, LearnFilter.notStarted.rawValue)
        XCTAssertEqual(viewController.filterControl.accessibilityValue, "Not Started")
        XCTAssertFalse(viewController.dataSource.visibleChapters.map(\.name).contains(chapterToHide.name))
        XCTAssertEqual(tableView.numberOfSections, viewController.dataSource.numberOfSections(in: tableView))
    }

    //harness:criterion=c-learn-context-menu-uses-title-for
    func testContextMenuUsesFilteredTitleForPreview() {
        User.current.learnedSection(firstSection().bundleName)
        let coordinator = StudyPreviewCaptureLearnCoordinator()
        let viewController = LearnViewController(style: .plain)
        viewController.coordinator = coordinator
        viewController.loadViewIfNeeded()
        viewController.dataSource.currentFilter = .notStarted
        let tableView = IndexPathTableView(frame: .zero, style: .plain)
        tableView.fixedIndexPath = IndexPath(row: 0, section: 0)
        viewController.tableView = tableView

        let configuration = viewController.contextMenuInteraction(
            UIContextMenuInteraction(delegate: viewController),
            configurationForMenuAtLocation: .zero
        )

        XCTAssertNotNil(configuration)
        XCTAssertEqual(coordinator.previewedTitle, viewController.dataSource.title(for: IndexPath(row: 0, section: 0)))
    }
}

private extension LearnDataSourceTests {
    var nonEmptyChapters: [Chapter] {
        Unwrap.chapters.filter { $0.sections.isEmpty == false }
    }

    var allSections: [String] {
        nonEmptyChapters.flatMap(\.sections)
    }

    func firstSection() -> String {
        allSections[0]
    }

    func firstSections(count: Int) -> [String] {
        Array(allSections.prefix(count))
    }

    func visibleSections(in dataSource: LearnDataSource) -> [String] {
        dataSource.visibleChapters.flatMap(\.sections)
    }

    func visibleSectionBundleNames(in dataSource: LearnDataSource) -> [String] {
        visibleSections(in: dataSource).map(\.bundleName)
    }

    func user(learned: [String], reviewed: [String]) throws -> User {
        let data = try JSONEncoder().encode(User())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["learnedSections"] = learned
        json["reviewedSections"] = reviewed
        let modifiedData = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(User.self, from: modifiedData)
    }

    func makeLoadedLearnViewController() -> LearnViewController {
        let viewController = LearnViewController(style: .plain)
        viewController.coordinator = LearnCoordinator()
        viewController.loadViewIfNeeded()
        return viewController
    }

    func installSpyTableView(on viewController: LearnViewController) -> ReloadTrackingTableView {
        let tableView = ReloadTrackingTableView(frame: .zero, style: .plain)
        tableView.dataSource = viewController.dataSource
        tableView.delegate = viewController.dataSource
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
        viewController.tableView = tableView
        return tableView
    }

    func findSegmentedControl(in view: UIView) -> UISegmentedControl? {
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

private final class ReloadTrackingTableView: UITableView {
    private(set) var reloadDataCallCount = 0

    override func reloadData() {
        reloadDataCallCount += 1
        super.reloadData()
    }
}

private final class IndexPathTableView: UITableView {
    var fixedIndexPath: IndexPath?

    override func indexPathForRow(at point: CGPoint) -> IndexPath? {
        fixedIndexPath
    }
}

private final class StudyCaptureLearnViewController: LearnViewController {
    var startedTitle: String?

    override func startStudying(title: String) {
        startedTitle = title
    }
}

private final class StudyPreviewCaptureLearnCoordinator: LearnCoordinator {
    var previewedTitle: String?

    override func studyViewController(for title: String) -> StudyViewController {
        previewedTitle = title
        return StudyViewController()
    }
}
