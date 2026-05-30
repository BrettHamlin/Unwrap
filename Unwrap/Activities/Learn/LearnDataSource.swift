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
}

protocol LearnProgressProviding {
    func ratingForSection(_ section: String) -> Int
}

extension User: LearnProgressProviding { }

protocol LearnDataSourceDelegate: AnyObject {
    func startStudying(title: String)
}

/// Manages all the rows in the Learn table view.
class LearnDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    private struct VisibleChapter {
        var name: String
        var sections: [String]
    }

    weak var delegate: LearnDataSourceDelegate?

    private let chapters: [Chapter]
    private let progressProvider: LearnProgressProviding
    private var visibleChapters = [VisibleChapter]()

    var currentFilter = LearnProgressFilter.all {
        didSet {
            rebuildVisibleChapters()
        }
    }

    init(chapters: [Chapter] = Unwrap.chapters, progressProvider: LearnProgressProviding = User.current) {
        self.chapters = chapters
        self.progressProvider = progressProvider
        super.init()
        rebuildVisibleChapters()
    }

    func reloadVisibleChapters() {
        rebuildVisibleChapters()
    }

    func title(for indexPath: IndexPath) -> String {
        return sectionTitle(at: indexPath)
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

        let section = sectionTitle(at: indexPath)

        cell.textLabel?.text = section
        cell.textLabel?.numberOfLines = 0

        // Decide how to show the checkmark for this section.

        let score = progressProvider.ratingForSection(section.bundleName)

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
        delegate?.startStudying(title: sectionTitle(at: indexPath))
    }

    private func sectionTitle(at indexPath: IndexPath) -> String {
        return visibleChapters[indexPath.section].sections[indexPath.row]
    }

    private func rebuildVisibleChapters() {
        visibleChapters = chapters.compactMap { chapter in
            let sections: [String]

            switch currentFilter {
            case .all:
                sections = chapter.sections
            case .notStarted:
                sections = chapter.sections.filter { progressProvider.ratingForSection($0.bundleName) == 0 }
            case .completed:
                sections = chapter.sections.filter { progressProvider.ratingForSection($0.bundleName) == 200 }
            }

            if currentFilter != .all && sections.isEmpty {
                return nil
            } else {
                return VisibleChapter(name: chapter.name, sections: sections)
            }
        }
    }
}
