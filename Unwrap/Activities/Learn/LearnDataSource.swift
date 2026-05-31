//
//  LearnDataSource.swift
//  Unwrap
//
//  Created by Paul Hudson on 09/08/2018.
//  Copyright © 2019 Hacking with Swift.
//

import UIKit

enum LearnFilterMode: String, CaseIterable {
    case all = "All"
    case notStarted = "Not Started"
    case completed = "Completed"
}

/// Manages all the rows in the Learn table view.
class LearnDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    typealias ProgressPredicate = (String) -> (hasLearned: Bool, hasReviewed: Bool)

    weak var delegate: LearnViewController?

    private let chapters: [Chapter]
    private let progressPredicate: ProgressPredicate
    private(set) var filteredChapters: [Chapter]

    var filterMode = LearnFilterMode.all {
        didSet {
            rebuildFilteredChapters()
        }
    }

    init(chapters: [Chapter] = Unwrap.chapters, progressPredicate: @escaping ProgressPredicate = { section in
        let bundleName = section.bundleName
        return (User.current.hasLearned(bundleName), User.current.hasReviewed(bundleName))
    }) {
        self.chapters = chapters
        self.progressPredicate = progressPredicate
        filteredChapters = []
        super.init()
        rebuildFilteredChapters()
    }

    func rebuildFilteredChapters() {
        guard filterMode != .all else {
            filteredChapters = chapters
            return
        }

        filteredChapters = chapters.compactMap { chapter in
            let sections = chapter.sections.filter { section in
                let progress = progressPredicate(section)

                switch filterMode {
                case .notStarted:
                    return progress.hasLearned == false && progress.hasReviewed == false
                case .completed:
                    return progress.hasLearned && progress.hasReviewed
                case .all:
                    return true
                }
            }

            guard sections.isEmpty == false else { return nil }
            return Chapter(name: chapter.name, sections: sections)
        }
    }

    func title(for indexPath: IndexPath) -> String {
        return filteredChapters[indexPath.section].sections[indexPath.row]
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return filteredChapters.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as? DynamicHeightHeaderView {
            headerView.headerLabel.text = filteredChapters[section].name
            return headerView
        } else {
            return nil
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredChapters[section].sections.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.accessoryType = .disclosureIndicator

        let chapter = filteredChapters[indexPath.section]
        let section = chapter.sections[indexPath.row]

        cell.textLabel?.text = section
        cell.textLabel?.numberOfLines = 0

        // Decide how to show the checkmark for this section.

        let progress = progressPredicate(section)

        if progress.hasLearned == false && progress.hasReviewed == false {
            // Always show a check image, but make it invisible
            // for uncompleted sections – this helps keep text
            // alignment uniform across the table.
            cell.imageView?.image = UIImage(bundleName: "Check")
            cell.imageView?.alpha = 0
            cell.textLabel?.accessibilityLabel = "\(section). Section not started"
        } else if progress.hasLearned && progress.hasReviewed {
            // They read and reviewed this chapter.
            cell.imageView?.image = UIImage(bundleName: "Check")
            cell.imageView?.tintColor = UIColor(bundleName: "CourseFull")
            cell.imageView?.alpha = 1
            cell.textLabel?.accessibilityLabel = "\(section). Section completed"
        } else {
            // They read this chapter but didn't review it.
            cell.imageView?.image = UIImage(bundleName: "Check")
            cell.imageView?.tintColor = UIColor(bundleName: "CoursePartial")
            cell.imageView?.alpha = 1
            cell.textLabel?.accessibilityLabel = "\(section). Section in progress"
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedChapter = filteredChapters[indexPath.section]
        let selectedSection = selectedChapter.sections[indexPath.row]
        delegate?.startStudying(title: selectedSection)
    }
}
