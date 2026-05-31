//
//  LearnDataSource.swift
//  Unwrap
//
//  Created by Paul Hudson on 09/08/2018.
//  Copyright © 2019 Hacking with Swift.
//

import UIKit

enum LearnFilterMode: Int, CaseIterable {
    case all
    case notStarted
    case completed

    var label: String {
        switch self {
        case .all:
            return "All"
        case .notStarted:
            return "Not Started"
        case .completed:
            return "Completed"
        }
    }
}

typealias FilterMode = LearnFilterMode

/// Manages all the rows in the Learn table view.
class LearnDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    weak var delegate: LearnViewController?

    typealias FilterMode = LearnFilterMode

    private struct VisibleChapter {
        let chapter: Chapter
        let sections: [String]
    }

    var filterMode = LearnFilterMode.all

    private let chapters: [Chapter]
    private let user: User?
    private lazy var fallbackUser = User()

    init(chapters: [Chapter] = Unwrap.chapters, user: User? = nil) {
        self.chapters = chapters
        self.user = user
        super.init()
    }

    private var currentUser: User {
        return user ?? User.current ?? fallbackUser
    }

    private var visibleChapters: [VisibleChapter] {
        let user = currentUser

        return chapters.compactMap { chapter in
            let visibleSections: [String]

            switch filterMode {
            case .all:
                visibleSections = chapter.sections
            case .notStarted:
                visibleSections = chapter.sections.filter {
                    user.hasLearned($0.bundleName) == false && user.hasReviewed($0.bundleName) == false
                }
            case .completed:
                visibleSections = chapter.sections.filter {
                    user.hasLearned($0.bundleName) && user.hasReviewed($0.bundleName)
                }
            }

            if filterMode != .all && visibleSections.isEmpty {
                return nil
            } else {
                return VisibleChapter(chapter: chapter, sections: visibleSections)
            }
        }
    }

    private func visibleChapter(at section: Int) -> VisibleChapter? {
        let chapters = visibleChapters
        guard chapters.indices.contains(section) else { return nil }
        return chapters[section]
    }

    private func visibleSection(at indexPath: IndexPath) -> String? {
        guard let chapter = visibleChapter(at: indexPath.section), chapter.sections.indices.contains(indexPath.row) else {
            return nil
        }

        return chapter.sections[indexPath.row]
    }

    func title(for indexPath: IndexPath) -> String {
        return visibleSection(at: indexPath) ?? ""
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return visibleChapters.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as? DynamicHeightHeaderView, let chapter = visibleChapter(at: section) {
            headerView.headerLabel.text = chapter.chapter.name
            return headerView
        } else {
            return nil
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return visibleChapter(at: section)?.sections.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.accessoryType = .disclosureIndicator

        guard let section = visibleSection(at: indexPath) else { return cell }

        cell.textLabel?.text = section
        cell.textLabel?.numberOfLines = 0

        // Decide how to show the checkmark for this section.

        let score = currentUser.ratingForSection(section.bundleName)

        if score == 0 {
            // Always show a check image, but make it invisible
            // for uncompleted sections – this helps keep text
            // alignment uniform across the table.
            cell.imageView?.image = UIImage(bundleName: "Check")
            cell.imageView?.alpha = 0
            cell.textLabel?.accessibilityLabel = "\(section). Section not started"
        } else if score == 100 {
            // They read this chapter but didn't review it.
            cell.imageView?.image = UIImage(bundleName: "Check")
            cell.imageView?.tintColor = UIColor(bundleName: "CoursePartial")
            cell.imageView?.alpha = 1
            cell.textLabel?.accessibilityLabel = "\(section). Section in progress"
        } else if score == 200 {
            // They read and reviewed this chapter.
            cell.imageView?.image = UIImage(bundleName: "Check")
            cell.imageView?.tintColor = UIColor(bundleName: "CourseFull")
            cell.imageView?.alpha = 1
            cell.textLabel?.accessibilityLabel = "\(section). Section completed"
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let selectedSection = visibleSection(at: indexPath) {
            delegate?.startStudying(title: selectedSection)
        }
    }
}
