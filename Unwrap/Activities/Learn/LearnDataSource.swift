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
    enum Filter: Equatable {
        case all
        case notStarted
        case completed
    }

    weak var delegate: LearnViewController?

    let chapters: [Chapter]
    private let fallbackUser = User()
    private var injectedUser: User?
    var user: User {
        get {
            return injectedUser ?? User.current ?? fallbackUser
        }

        set {
            injectedUser = newValue
        }
    }

    var filter = Filter.all

    var visibleChapters: [(chapter: Chapter, sections: [String])] {
        switch filter {
        case .all:
            return chapters.map { (chapter: $0, sections: $0.sections) }
        case .notStarted:
            return chapters.compactMap { chapter in
                let sections = chapter.sections.filter { section in
                    let bundleName = section.bundleName
                    return user.hasLearned(bundleName) == false && user.hasReviewed(bundleName) == false
                }

                guard sections.isEmpty == false else { return nil }
                return (chapter: chapter, sections: sections)
            }
        case .completed:
            return chapters.compactMap { chapter in
                let sections = chapter.sections.filter { section in
                    let bundleName = section.bundleName
                    return user.hasLearned(bundleName) && user.hasReviewed(bundleName)
                }

                guard sections.isEmpty == false else { return nil }
                return (chapter: chapter, sections: sections)
            }
        }
    }

    init(chapters: [Chapter] = Unwrap.chapters, user: User? = nil) {
        self.chapters = chapters
        self.injectedUser = user
        super.init()
    }

    func title(for indexPath: IndexPath) -> String {
        return visibleChapters[indexPath.section].sections[indexPath.row]
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

        let section = title(for: indexPath)

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
}
