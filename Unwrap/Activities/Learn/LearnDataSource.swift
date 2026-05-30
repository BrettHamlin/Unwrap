//
//  LearnDataSource.swift
//  Unwrap
//
//  Created by Paul Hudson on 09/08/2018.
//  Copyright © 2019 Hacking with Swift.
//

import UIKit

enum LearnFilter: Equatable {
    case all
    case notStarted
    case completed
}

/// Manages all the rows in the Learn table view.
class LearnDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    private struct FilteredChapter {
        let chapter: Chapter
        let sections: [String]
    }

    weak var delegate: LearnViewController?

    var filter: LearnFilter = .all {
        didSet {
            rebuildFilteredChapters()
        }
    }

    private var filteredChapters = [FilteredChapter]()

    override init() {
        super.init()
        rebuildFilteredChapters()
    }

    func refresh() {
        rebuildFilteredChapters()
    }

    func title(for indexPath: IndexPath) -> String {
        return filteredChapters[indexPath.section].sections[indexPath.row]
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return filteredChapters.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as? DynamicHeightHeaderView {
            headerView.headerLabel.text = filteredChapters[section].chapter.name
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

        let section = title(for: indexPath)

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

    private func rebuildFilteredChapters() {
        if filter == .all {
            filteredChapters = Unwrap.chapters.map {
                FilteredChapter(chapter: $0, sections: $0.sections)
            }

            return
        }

        filteredChapters = Unwrap.chapters.compactMap { chapter in
            let sections = chapter.sections.filter(sectionIsVisible)

            guard sections.isEmpty == false else {
                return nil
            }

            return FilteredChapter(chapter: chapter, sections: sections)
        }
    }

    private func sectionIsVisible(_ section: String) -> Bool {
        switch filter {
        case .all:
            return true
        case .notStarted:
            return User.current.hasLearned(section.bundleName) == false && User.current.hasReviewed(section.bundleName) == false
        case .completed:
            return User.current.hasLearned(section.bundleName) && User.current.hasReviewed(section.bundleName)
        }
    }
}
