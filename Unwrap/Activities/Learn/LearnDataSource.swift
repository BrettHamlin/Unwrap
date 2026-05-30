//
//  LearnDataSource.swift
//  Unwrap
//
//  Created by Paul Hudson on 09/08/2018.
//  Copyright © 2019 Hacking with Swift.
//

import UIKit

enum LearnFilterMode: CaseIterable {
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

/// Manages all the rows in the Learn table view.
class LearnDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    weak var delegate: LearnViewController?

    var filterMode = LearnFilterMode.all

    private struct VisibleChapter {
        let chapterIndex: Int
        let sectionIndices: [Int]
    }

    private var visibleChapters: [VisibleChapter] {
        if filterMode == .all {
            return Unwrap.chapters.enumerated().map { chapterIndex, chapter in
                VisibleChapter(chapterIndex: chapterIndex, sectionIndices: Array(chapter.sections.indices))
            }
        }

        return Unwrap.chapters.enumerated().compactMap { chapterIndex, chapter in
            let sectionIndices = chapter.sections.indices.filter { sectionIndex in
                shouldShow(section: chapter.sections[sectionIndex])
            }

            guard sectionIndices.isEmpty == false else { return nil }

            return VisibleChapter(chapterIndex: chapterIndex, sectionIndices: Array(sectionIndices))
        }
    }

    func title(for indexPath: IndexPath) -> String {
        let visibleSection = section(for: indexPath)
        return Unwrap.chapters[visibleSection.chapterIndex].sections[visibleSection.sectionIndex]
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return visibleChapters.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as? DynamicHeightHeaderView {
            let chapterIndex = visibleChapters[section].chapterIndex
            headerView.headerLabel.text = Unwrap.chapters[chapterIndex].name
            return headerView
        } else {
            return nil
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return visibleChapters[section].sectionIndices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.accessoryType = .disclosureIndicator

        let visibleSection = section(for: indexPath)
        let chapter = Unwrap.chapters[visibleSection.chapterIndex]
        let section = chapter.sections[visibleSection.sectionIndex]

        cell.textLabel?.text = section
        cell.textLabel?.numberOfLines = 0

        // Decide how to show the checkmark for this section.

        let score = User.current.ratingForSection(section.bundleName)

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
        let selectedSection = title(for: indexPath)
        delegate?.startStudying(title: selectedSection)
    }

    private func section(for indexPath: IndexPath) -> (chapterIndex: Int, sectionIndex: Int) {
        let visibleChapter = visibleChapters[indexPath.section]
        return (visibleChapter.chapterIndex, visibleChapter.sectionIndices[indexPath.row])
    }

    private func shouldShow(section: String) -> Bool {
        switch filterMode {
        case .all:
            return true

        case .notStarted:
            let sectionName = section.bundleName
            let hasLearned = User.current?.hasLearned(sectionName) ?? false
            let hasReviewed = User.current?.hasReviewed(sectionName) ?? false
            return hasLearned == false && hasReviewed == false

        case .completed:
            let sectionName = section.bundleName
            let hasLearned = User.current?.hasLearned(sectionName) ?? false
            let hasReviewed = User.current?.hasReviewed(sectionName) ?? false
            return hasLearned && hasReviewed
        }
    }
}
