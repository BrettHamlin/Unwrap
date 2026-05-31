//
//  LearnDataSource.swift
//  Unwrap
//
//  Created by Paul Hudson on 09/08/2018.
//  Copyright © 2019 Hacking with Swift.
//

import UIKit

enum LearnProgressFilter: CaseIterable {
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
    var activeFilter = LearnProgressFilter.all {
        didSet {
            updateFilteredChapters()
        }
    }

    private(set) var filteredChapters = [(chapter: Chapter, sections: [String])]()

    override init() {
        super.init()
        updateFilteredChapters()
    }

    func title(for indexPath: IndexPath) -> String {
        return filteredChapters[indexPath.section].sections[indexPath.row]
    }

    func updateFilteredChapters() {
        filteredChapters = Unwrap.chapters.compactMap { chapter in
            let sections = chapter.sections.filter { sectionIsVisible($0) }

            if activeFilter == .all || sections.isEmpty == false {
                return (chapter: chapter, sections: sections)
            } else {
                return nil
            }
        }
    }

    private func sectionIsVisible(_ section: String) -> Bool {
        switch activeFilter {
        case .all:
            return true
        case .notStarted:
            guard let user = User.current else { return true }
            return !user.hasLearned(section.bundleName) && !user.hasReviewed(section.bundleName)
        case .completed:
            guard let user = User.current else { return false }
            return user.hasLearned(section.bundleName) && user.hasReviewed(section.bundleName)
        }
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

        let section = filteredChapters[indexPath.section].sections[indexPath.row]

        cell.textLabel?.text = section
        cell.textLabel?.numberOfLines = 0

        // Decide how to show the checkmark for this section.

        let score = User.current?.ratingForSection(section.bundleName) ?? 0

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
        let selectedSection = filteredChapters[indexPath.section].sections[indexPath.row]
        delegate?.startStudying(title: selectedSection)
    }
}
