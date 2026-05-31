//
//  LearnDataSourceTests.swift
//  UnwrapTests
//

import UIKit
import XCTest
@testable import Unwrap

final class LearnDataSourceTests: XCTestCase {
    private var tableView: UITableView!

    override func setUp() {
        super.setUp()

        if User.current == nil {
            User.current = User()
        }

        tableView = UITableView()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
    }

    override func tearDown() {
        tableView = nil
        super.tearDown()
    }

    //harness:criterion=c-learn-filter-mode-enum-cases,c-learn-filter-default-all,c-learn-tests-file-registered-in-project
    func testFilterModeRawValuesAndDefaultSelection() {
        XCTAssertEqual(LearnFilterMode.all.rawValue, "All")
        XCTAssertEqual(LearnFilterMode.notStarted.rawValue, "Not Started")
        XCTAssertEqual(LearnFilterMode.completed.rawValue, "Completed")
        XCTAssertEqual(LearnFilterMode.allCases, [.all, .notStarted, .completed])

        let dataSource = LearnDataSource(chapters: [], progressPredicate: { _ in (hasLearned: false, hasReviewed: false) })
        XCTAssertEqual(dataSource.filterMode, .all)
    }

    //harness:criterion=c-learn-datasource-injectable-chapters
    func testUsesInjectedChaptersAndProgressPredicate() {
        let dataSource = makeDataSource(
            chapters: [
                chapter("Basics", "Variables", "Constants")
            ],
            progress: [
                "Variables": (hasLearned: false, hasReviewed: false),
                "Constants": (hasLearned: false, hasReviewed: false)
            ]
        )

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), 1)
        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: 0), 2)
    }

    //harness:criterion=c-learn-filter-all-shows-all-chapters
    func testAllFilterShowsEveryInjectedChapterAndSection() {
        let dataSource = makeDataSource(chapters: [
            chapter("Basics", "Variables", "Constants"),
            chapter("Types", "Strings", "Integers")
        ])

        XCTAssertEqual(dataSource.filterMode, .all)
        XCTAssertEqual(dataSource.numberOfSections(in: tableView), 2)
        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: 0), 2)
        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: 1), 2)
        XCTAssertEqual(visibleTitles(in: dataSource), ["Variables", "Constants", "Strings", "Integers"])
    }

    //harness:criterion=c-learn-filter-not-started-hides-completed-sections,c-learn-filter-not-started-shows-unstarted-sections,c-learn-filter-title-for-resolves-correctly
    func testNotStartedFilterShowsOnlyUnstartedSectionsAtFilteredIndexPaths() {
        let dataSource = makeDataSource(
            chapters: [
                chapter("Basics", "Completed Section", "Unstarted Section", "Learned Only Section")
            ],
            progress: [
                "Completed Section": (hasLearned: true, hasReviewed: true),
                "Unstarted Section": (hasLearned: false, hasReviewed: false),
                "Learned Only Section": (hasLearned: true, hasReviewed: false)
            ]
        )

        dataSource.filterMode = .notStarted

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), 1)
        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: 0), 1)
        XCTAssertEqual(dataSource.title(for: IndexPath(row: 0, section: 0)), "Unstarted Section")
        XCTAssertEqual(visibleTitles(in: dataSource), ["Unstarted Section"])
    }

    //harness:criterion=c-learn-filter-completed-shows-only-learned-reviewed,c-learn-filter-completed-hides-unstarted-sections,c-learn-number-of-rows-uses-filtered-model
    func testCompletedFilterShowsOnlyLearnedAndReviewedSections() {
        let dataSource = makeDataSource(
            chapters: [
                chapter("Basics", "Completed Section", "Learned Only Section", "Unstarted Section", "Reviewed Only Section")
            ],
            progress: [
                "Completed Section": (hasLearned: true, hasReviewed: true),
                "Learned Only Section": (hasLearned: true, hasReviewed: false),
                "Unstarted Section": (hasLearned: false, hasReviewed: false),
                "Reviewed Only Section": (hasLearned: false, hasReviewed: true)
            ]
        )

        dataSource.filterMode = .completed

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), 1)
        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: 0), 1)
        XCTAssertEqual(dataSource.title(for: IndexPath(row: 0, section: 0)), "Completed Section")
        XCTAssertEqual(visibleTitles(in: dataSource), ["Completed Section"])
    }

    //harness:criterion=c-learn-filter-empty-chapter-hidden,c-learn-number-of-sections-uses-filtered-model
    func testFilterHidesChaptersWithNoVisibleSections() {
        let dataSource = makeDataSource(
            chapters: [
                chapter("Finished Chapter", "Completed Section"),
                chapter("Fresh Chapter", "Unstarted Section")
            ],
            progress: [
                "Completed Section": (hasLearned: true, hasReviewed: true),
                "Unstarted Section": (hasLearned: false, hasReviewed: false)
            ]
        )

        dataSource.filterMode = .notStarted

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), 1)
        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: 0), 1)
        XCTAssertEqual(dataSource.title(for: IndexPath(row: 0, section: 0)), "Unstarted Section")
    }

    //harness:criterion=c-learn-cell-for-row-uses-filtered-model
    func testCellForRowUsesFilteredSectionAtIndexPath() {
        let dataSource = makeDataSource(
            chapters: [
                chapter("Basics", "Unstarted Section", "Completed Section")
            ],
            progress: [
                "Unstarted Section": (hasLearned: false, hasReviewed: false),
                "Completed Section": (hasLearned: true, hasReviewed: true)
            ]
        )
        dataSource.filterMode = .completed

        let cell = dataSource.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: 0))

        XCTAssertEqual(cell.textLabel?.text, "Completed Section")
        XCTAssertEqual(cell.textLabel?.accessibilityLabel, "Completed Section. Section completed")
    }

    //harness:criterion=c-learn-header-for-section-uses-filtered-model
    func testHeaderForSectionUsesFilteredChapterName() throws {
        let dataSource = makeDataSource(
            chapters: [
                chapter("Finished Chapter", "Completed Section"),
                chapter("Fresh Chapter", "Unstarted Section")
            ],
            progress: [
                "Completed Section": (hasLearned: true, hasReviewed: true),
                "Unstarted Section": (hasLearned: false, hasReviewed: false)
            ]
        )
        dataSource.filterMode = .notStarted

        let header = try XCTUnwrap(dataSource.tableView(tableView, viewForHeaderInSection: 0) as? DynamicHeightHeaderView)

        XCTAssertEqual(header.headerLabel.text, "Fresh Chapter")
    }

    //harness:criterion=c-learn-filter-did-select-resolves-title
    func testDidSelectSendsFilteredSectionTitleToDelegate() {
        let dataSource = makeDataSource(
            chapters: [
                chapter("Basics", "Completed Section", "Unstarted Section")
            ],
            progress: [
                "Completed Section": (hasLearned: true, hasReviewed: true),
                "Unstarted Section": (hasLearned: false, hasReviewed: false)
            ]
        )
        let viewController = CapturingLearnViewController(style: .plain)
        dataSource.delegate = viewController
        dataSource.filterMode = .notStarted

        dataSource.tableView(tableView, didSelectRowAt: IndexPath(row: 0, section: 0))

        XCTAssertEqual(viewController.startedTitle, "Unstarted Section")
    }

    //harness:criterion=c-learn-segmented-control-three-segments,c-learn-segmented-control-default-selection
    func testLearnViewControllerCreatesThreeSegmentFilterDefaultedToAll() throws {
        let viewController = makeLoadedLearnViewController()

        let control = try XCTUnwrap(viewController.tableView.tableHeaderView?.firstSubview(ofType: UISegmentedControl.self))

        XCTAssertEqual(control.numberOfSegments, 3)
        XCTAssertEqual(control.titleForSegment(at: 0), "All")
        XCTAssertEqual(control.titleForSegment(at: 1), "Not Started")
        XCTAssertEqual(control.titleForSegment(at: 2), "Completed")
        XCTAssertEqual(control.selectedSegmentIndex, 0)
        XCTAssertEqual(control.accessibilityLabel, "Learn filter")
        XCTAssertEqual(control.accessibilityValue, "All")
        XCTAssertGreaterThanOrEqual(viewController.tableView.tableHeaderView?.frame.height ?? 0, 44)
    }

    //harness:criterion=c-learn-segmented-control-updates-filter-mode
    func testFilterControlActionUpdatesDataSourceFilterAndReloadsTable() throws {
        let viewController = makeLoadedLearnViewController()
        let control = try XCTUnwrap(viewController.tableView.tableHeaderView?.firstSubview(ofType: UISegmentedControl.self))
        let actionName = try XCTUnwrap(control.actions(forTarget: viewController, forControlEvent: .valueChanged)?.first)
        let reloadCountingTableView = ReloadCountingTableView()
        viewController.tableView = reloadCountingTableView

        control.selectedSegmentIndex = 1
        _ = viewController.perform(Selector(actionName), with: control)

        XCTAssertEqual(viewController.dataSource.filterMode, .notStarted)
        XCTAssertEqual(control.accessibilityValue, "Not Started")
        XCTAssertEqual(reloadCountingTableView.reloadDataCallCount, 1)

        control.selectedSegmentIndex = 2
        _ = viewController.perform(Selector(actionName), with: control)

        XCTAssertEqual(viewController.dataSource.filterMode, .completed)
        XCTAssertEqual(control.accessibilityValue, "Completed")
        XCTAssertEqual(reloadCountingTableView.reloadDataCallCount, 2)
    }

    //harness:criterion=c-learn-user-data-changed-reloads-filtered
    func testUserDataChangedRebuildsCurrentFilterAndReloadsTable() throws {
        let originalUser = User.current
        User.current = User()
        defer { User.current = originalUser }

        let viewController = makeLoadedLearnViewController()
        let reloadCountingTableView = ReloadCountingTableView()
        viewController.tableView = reloadCountingTableView

        let firstSectionTitle = try XCTUnwrap(Unwrap.chapters.first?.sections.first)
        viewController.dataSource.filterMode = .completed
        XCTAssertEqual(visibleTitles(in: viewController.dataSource), [])

        User.current.reviewedSection(firstSectionTitle.bundleName)
        viewController.userDataChanged()

        XCTAssertEqual(viewController.dataSource.filterMode, .completed)
        XCTAssertEqual(visibleTitles(in: viewController.dataSource), [firstSectionTitle])
        XCTAssertEqual(reloadCountingTableView.reloadDataCallCount, 1)
    }

    //harness:criterion=c-learn-context-menu-resolves-title
    func testContextMenuUsesFilteredSectionTitle() throws {
        let originalUser = User.current
        User.current = User()
        defer { User.current = originalUser }

        let firstChapter = try XCTUnwrap(Unwrap.chapters.first)
        XCTAssertGreaterThanOrEqual(firstChapter.sections.count, 2)

        let secondSectionTitle = firstChapter.sections[1]
        User.current.reviewedSection(secondSectionTitle.bundleName)

        let coordinator = CapturingLearnCoordinator()
        let viewController = LearnViewController(style: .plain)
        viewController.coordinator = coordinator
        viewController.loadViewIfNeeded()
        viewController.dataSource.filterMode = .completed
        viewController.tableView = FixedIndexPathTableView(indexPath: IndexPath(row: 0, section: 0))

        _ = viewController.contextMenuInteraction(UIContextMenuInteraction(delegate: viewController), configurationForMenuAtLocation: .zero)

        XCTAssertEqual(coordinator.requestedStudyTitle, secondSectionTitle)
    }

    //harness:criterion=c-learn-no-global-state-mutation
    func testChangingFilterModeDoesNotMutateGlobalChaptersOrUser() {
        let originalUser = User.current
        if User.current == nil {
            User.current = User()
        }
        defer { User.current = originalUser }

        let originalChapterCount = Unwrap.chapters.count
        let originalPoints = User.current.totalPoints
        let dataSource = makeDataSource(
            chapters: [
                chapter("Basics", "Completed Section", "Unstarted Section")
            ],
            progress: [
                "Completed Section": (hasLearned: true, hasReviewed: true),
                "Unstarted Section": (hasLearned: false, hasReviewed: false)
            ]
        )

        dataSource.filterMode = .notStarted
        dataSource.filterMode = .completed
        dataSource.filterMode = .all

        XCTAssertEqual(Unwrap.chapters.count, originalChapterCount)
        XCTAssertEqual(User.current.totalPoints, originalPoints)
    }

    private func makeDataSource(chapters: [Chapter], progress: [String: (hasLearned: Bool, hasReviewed: Bool)] = [:]) -> LearnDataSource {
        return LearnDataSource(chapters: chapters) { section in
            progress[section] ?? (hasLearned: false, hasReviewed: false)
        }
    }

    private func chapter(_ name: String, _ sections: String...) -> Chapter {
        return Chapter(name: name, sections: sections)
    }

    private func visibleTitles(in dataSource: LearnDataSource) -> [String] {
        return (0..<dataSource.numberOfSections(in: tableView)).flatMap { section in
            (0..<dataSource.tableView(tableView, numberOfRowsInSection: section)).map { row in
                dataSource.title(for: IndexPath(row: row, section: section))
            }
        }
    }

    private func makeLoadedLearnViewController() -> LearnViewController {
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

private final class CapturingLearnCoordinator: LearnCoordinator {
    var requestedStudyTitle: String?

    override func studyViewController(for title: String) -> StudyViewController {
        requestedStudyTitle = title
        let viewController = StudyViewController()
        viewController.title = title
        return viewController
    }
}

private final class ReloadCountingTableView: UITableView {
    private(set) var reloadDataCallCount = 0

    override func reloadData() {
        reloadDataCallCount += 1
        super.reloadData()
    }
}

private final class FixedIndexPathTableView: UITableView {
    private let fixedIndexPath: IndexPath

    init(indexPath: IndexPath) {
        fixedIndexPath = indexPath
        super.init(frame: .zero, style: .plain)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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
            if let matchingView = subview.firstSubview(ofType: type) {
                return matchingView
            }
        }

        return nil
    }
}
