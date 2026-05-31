//
//  LearnDataSourceTests.swift
//  UnwrapTests
//

import XCTest
@testable import Unwrap

class LearnDataSourceTests: XCTestCase {
    private var originalUser: User?

    override func setUp() {
        super.setUp()
        originalUser = User.current
        User.current = makeUser()
    }

    override func tearDown() {
        User.current = originalUser
        super.tearDown()
    }

    //harness:criterion=c-learn-progress-filter-enum-cases
    func testProgressFilterCasesAndDisplayTitles() {
        XCTAssertEqual(LearnProgressFilter.all.displayTitle, "All")
        XCTAssertEqual(LearnProgressFilter.notStarted.displayTitle, "Not Started")
        XCTAssertEqual(LearnProgressFilter.completed.displayTitle, "Completed")
        XCTAssertEqual(LearnProgressFilter.allCases.count, 3)
    }

    //harness:criterion=c-learn-datasource-visible-chapters-structure,c-learn-filter-default-all-shows-all-sections
    func testDefaultAllFilterShowsEveryChapterAndSectionInOrder() {
        let dataSource = LearnDataSource()

        XCTAssertEqual(dataSource.visibleChapters.count, Unwrap.chapters.count)
        XCTAssertFalse(dataSource.visibleChapters.isEmpty)
        XCTAssertEqual(totalSections(in: dataSource.visibleChapters), totalSections(in: Unwrap.chapters))

        for (visibleChapter, chapter) in zip(dataSource.visibleChapters, Unwrap.chapters) {
            XCTAssertEqual(visibleChapter.chapter.name, chapter.name)
            XCTAssertEqual(visibleChapter.sections, chapter.sections)
            XCTAssertFalse(visibleChapter.sections.isEmpty)
        }
    }

    //harness:criterion=c-learn-filter-not-started-hides-learned-sections,c-learn-filter-not-started-hides-reviewed-sections,c-learn-datasource-filter-property-triggers-recompute
    func testNotStartedFilterExcludesLearnedAndReviewedSectionsImmediately() {
        let learnedOnly = Unwrap.chapters[0].sections[0]
        let reviewedOnly = Unwrap.chapters[0].sections[1]
        let completed = Unwrap.chapters[0].sections[2]
        User.current = makeUser(
            learned: [learnedOnly.bundleName, completed.bundleName],
            reviewed: [reviewedOnly.bundleName, completed.bundleName]
        )

        let dataSource = LearnDataSource()
        let allCount = totalSections(in: dataSource.visibleChapters)
        dataSource.filter = .notStarted
        let visibleBundleNames = bundleNames(in: dataSource.visibleChapters)

        XCTAssertLessThan(totalSections(in: dataSource.visibleChapters), allCount)
        XCTAssertFalse(visibleBundleNames.contains(learnedOnly.bundleName))
        XCTAssertFalse(visibleBundleNames.contains(reviewedOnly.bundleName))
        XCTAssertFalse(visibleBundleNames.contains(completed.bundleName))

        for section in dataSource.visibleChapters.flatMap({ $0.sections }) {
            XCTAssertFalse(User.current.hasLearned(section.bundleName))
            XCTAssertFalse(User.current.hasReviewed(section.bundleName))
        }
    }

    //harness:criterion=c-learn-filter-completed-shows-only-fully-done,c-learn-filter-completed-excludes-partial-progress
    func testCompletedFilterShowsOnlyFullyDoneSections() {
        let learnedOnly = Unwrap.chapters[0].sections[0]
        let reviewedOnly = Unwrap.chapters[0].sections[1]
        let completed = Unwrap.chapters[0].sections[2]
        User.current = makeUser(
            learned: [learnedOnly.bundleName, completed.bundleName],
            reviewed: [reviewedOnly.bundleName, completed.bundleName]
        )

        let dataSource = LearnDataSource()
        dataSource.filter = .completed
        let visibleBundleNames = bundleNames(in: dataSource.visibleChapters)

        XCTAssertEqual(visibleBundleNames, [completed.bundleName])
        XCTAssertFalse(visibleBundleNames.contains(learnedOnly.bundleName))
        XCTAssertFalse(visibleBundleNames.contains(reviewedOnly.bundleName))

        for section in dataSource.visibleChapters.flatMap({ $0.sections }) {
            XCTAssertTrue(User.current.hasLearned(section.bundleName))
            XCTAssertTrue(User.current.hasReviewed(section.bundleName))
        }
    }

    //harness:criterion=c-learn-filter-empty-chapters-omitted,c-learn-datasource-number-of-sections,c-learn-datasource-number-of-rows,c-learn-datasource-title-for-resolves-correctly-after-filter,c-learn-datasource-did-select-resolves-correct-section,c-learn-coordinator-unaffected-by-filter,c-learn-header-view-indexes-visible-chapters,c-learn-cell-for-row-indexes-visible-chapters
    func testFilteredIndexesResolveAgainstVisibleChapters() {
        let omittedChapter = Unwrap.chapters[0]
        let firstVisibleChapter = Unwrap.chapters[1]
        let firstVisibleSection = firstVisibleChapter.sections[1]
        let learnedSections = omittedChapter.sections + [firstVisibleChapter.sections[0]]
        User.current = makeUser(learned: learnedSections.map { $0.bundleName })

        let dataSource = LearnDataSource()
        dataSource.filter = .notStarted
        let tableView = makeTableView()

        XCTAssertFalse(dataSource.visibleChapters.contains { $0.chapter.name == omittedChapter.name })
        XCTAssertTrue(dataSource.visibleChapters.allSatisfy { $0.sections.isEmpty == false })
        XCTAssertEqual(dataSource.visibleChapters[0].chapter.name, firstVisibleChapter.name)
        XCTAssertEqual(dataSource.visibleChapters[0].sections[0], firstVisibleSection)

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), dataSource.visibleChapters.count)
        for section in dataSource.visibleChapters.indices {
            XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: section), dataSource.visibleChapters[section].sections.count)
        }

        let header = dataSource.tableView(tableView, viewForHeaderInSection: 0) as? DynamicHeightHeaderView
        XCTAssertEqual(header?.headerLabel.text, firstVisibleChapter.name)

        let indexPath = IndexPath(row: 0, section: 0)
        XCTAssertEqual(dataSource.title(for: indexPath), firstVisibleSection)

        let cell = dataSource.tableView(tableView, cellForRowAt: indexPath)
        XCTAssertEqual(cell.textLabel?.text, firstVisibleSection)

        let delegate = LearnViewControllerSpy()
        dataSource.delegate = delegate
        dataSource.tableView(tableView, didSelectRowAt: indexPath)
        XCTAssertEqual(delegate.startedTitle, firstVisibleSection)
    }

    //harness:criterion=c-learn-datasource-number-of-sections
    func testNumberOfSectionsMatchesVisibleChaptersForEveryFilter() {
        let firstChapter = Unwrap.chapters[0]
        let completedSection = firstChapter.sections[0]
        User.current = makeUser(learned: firstChapter.sections.map { $0.bundleName }, reviewed: [completedSection.bundleName])
        let dataSource = LearnDataSource()
        let tableView = makeTableView()

        for filter in LearnProgressFilter.allCases {
            dataSource.filter = filter
            XCTAssertEqual(dataSource.numberOfSections(in: tableView), dataSource.visibleChapters.count)
        }
    }

    //harness:criterion=c-learn-user-data-changed-recomputes-visible-data
    func testRefreshVisibleChaptersRecomputesAfterUserProgressChanges() {
        let newlyStartedSection = Unwrap.chapters[0].sections[0]
        let dataSource = LearnDataSource()
        dataSource.filter = .notStarted
        let initialBundleNames = bundleNames(in: dataSource.visibleChapters)
        XCTAssertTrue(initialBundleNames.contains(newlyStartedSection.bundleName))

        User.current = makeUser(learned: [newlyStartedSection.bundleName])
        dataSource.refreshVisibleChapters()
        let refreshedBundleNames = bundleNames(in: dataSource.visibleChapters)

        XCTAssertFalse(refreshedBundleNames.contains(newlyStartedSection.bundleName))
        XCTAssertLessThan(refreshedBundleNames.count, initialBundleNames.count)
    }

    private func makeTableView() -> UITableView {
        let tableView = UITableView()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
        return tableView
    }

    private func totalSections(in chapters: [Chapter]) -> Int {
        return chapters.reduce(0) { $0 + $1.sections.count }
    }

    private func totalSections(in visibleChapters: [VisibleChapter]) -> Int {
        return visibleChapters.reduce(0) { $0 + $1.sections.count }
    }

    private func bundleNames(in visibleChapters: [VisibleChapter]) -> [String] {
        return visibleChapters.flatMap { $0.sections }.map { $0.bundleName }
    }

    private func makeUser(learned: [String] = [], reviewed: [String] = []) -> User {
        let data = """
        {
            "streakDays": 1,
            "bestStreak": 1,
            "lastStreakEntry": "2024-01-01T00:00:00Z",
            "learnedSections": \(jsonArray(for: learned)),
            "reviewedSections": \(jsonArray(for: reviewed)),
            "practiceSessions": { "storage": {} },
            "practicePoints": 0,
            "dailyChallenges": [],
            "scoreShareCount": 0,
            "latestNewsArticle": 0,
            "articlesRead": [],
            "theme": "Light"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(User.self, from: data)
    }

    private func jsonArray(for values: [String]) -> String {
        let data = try! JSONSerialization.data(withJSONObject: values, options: [])
        return String(data: data, encoding: .utf8)!
    }
}

private final class LearnViewControllerSpy: LearnViewController {
    var startedTitle: String?

    override func startStudying(title: String) {
        startedTitle = title
    }
}
