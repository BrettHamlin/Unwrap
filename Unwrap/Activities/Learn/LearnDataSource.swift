//
//  LearnDataSource.swift
//  Unwrap
//
//  Created by Paul Hudson on 09/08/2018.
//  Copyright © 2019 Hacking with Swift.
//

import UIKit

/// Manages all the rows in the Learn table view.
class LearnDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    enum FilterMode: CaseIterable, Equatable {
        case all
        case notStarted
        case completed
    }

    weak var delegate: LearnViewController?
    private let userProvider: () -> User
    var user: User { userProvider() }
    private(set) var visibleChapters = [Chapter]()

    var activeFilter = FilterMode.all {
        didSet {
            updateVisibleChapters()
        }
    }

    init(user: User? = nil) {
        if let user = user {
            userProvider = { user }
        } else {
            userProvider = { User.current ?? User() }
        }

        super.init()
        updateVisibleChapters()
    }

    func title(for indexPath: IndexPath) -> String {
        return visibleChapters[indexPath.section].sections[indexPath.row]
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return visibleChapters.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as? DynamicHeightHeaderView {
            headerView.headerLabel.text = visibleChapters[section].name
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

        let chapter = visibleChapters[indexPath.section]
        let section = chapter.sections[indexPath.row]

        cell.textLabel?.text = section
        cell.textLabel?.numberOfLines = 0

        // Decide how to show the checkmark for this section.

        let score = user.ratingForSection(section.bundleName)

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
        delegate?.startStudying(title: title(for: indexPath))
    }

    func updateVisibleChapters() {
        if activeFilter == .all {
            visibleChapters = Unwrap.chapters
            return
        }

        visibleChapters = Unwrap.chapters.compactMap { chapter in
            let sections = chapter.sections.filter { section in
                let bundleName = section.bundleName

                switch activeFilter {
                case .notStarted:
                    return user.hasLearned(bundleName) == false && user.hasReviewed(bundleName) == false
                case .completed:
                    return user.hasLearned(bundleName) && user.hasReviewed(bundleName)
                case .all:
                    return true
                }
            }

            guard sections.isEmpty == false else { return nil }
            return Chapter(name: chapter.name, sections: sections)
        }
    }
}
