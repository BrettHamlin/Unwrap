//
//  LearnDataSource.swift
//  Unwrap
//
//  Created by Paul Hudson on 09/08/2018.
//  Copyright © 2019 Hacking with Swift.
//

import UIKit

enum LearnProgressFilter: CaseIterable, Equatable {
    case all
    case notStarted
    case completed

    var displayTitle: String {
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

struct VisibleChapter {
    var chapter: Chapter
    var sections: [String]
}

/// Manages all the rows in the Learn table view.
class LearnDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    weak var delegate: LearnViewController?

    var visibleChapters = [VisibleChapter]()

    var filter = LearnProgressFilter.all {
        didSet {
            refreshVisibleChapters()
            delegate?.tableView.reloadData()
        }
    }

    override init() {
        super.init()
        refreshVisibleChapters()
    }

    func title(for indexPath: IndexPath) -> String {
        return visibleChapters[indexPath.section].sections[indexPath.row]
    }

    func refreshVisibleChapters() {
        visibleChapters = Unwrap.chapters.compactMap { chapter in
            let sections = chapter.sections.filter { shouldShowSection($0) }

            if sections.isEmpty {
                return nil
            } else {
                return VisibleChapter(chapter: chapter, sections: sections)
            }
        }
    }

    private func shouldShowSection(_ section: String) -> Bool {
        let bundleName = section.bundleName

        switch filter {
        case .all:
            return true

        case .notStarted:
            return User.current.ratingForSection(bundleName) == 0 && User.current.hasLearned(bundleName) == false && User.current.hasReviewed(bundleName) == false

        case .completed:
            return User.current.hasLearned(bundleName) && User.current.hasReviewed(bundleName)
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return visibleChapters.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as? DynamicHeightHeaderView {
            headerView.headerLabel.text = visibleChapters[section].chapter.name
            return headerView
        } else {
            return nil
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return visibleChapters[section].sections.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.accessoryType = .disclosureIndicator

        let section = visibleChapters[indexPath.section].sections[indexPath.row]

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
        let selectedSection = visibleChapters[indexPath.section].sections[indexPath.row]
        delegate?.startStudying(title: selectedSection)
    }
}
