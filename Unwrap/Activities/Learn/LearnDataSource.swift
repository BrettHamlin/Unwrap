//
//  LearnDataSource.swift
//  Unwrap
//
//  Created by Paul Hudson on 09/08/2018.
//  Copyright © 2019 Hacking with Swift.
//

import UIKit

enum LearnFilter: CaseIterable {
    case all
    case notStarted
    case completed
}

protocol LearnProgressProviding {
    func ratingForSection(_ section: String) -> Int
    func hasLearned(_ section: String) -> Bool
    func hasReviewed(_ section: String) -> Bool
}

extension User: LearnProgressProviding { }

protocol LearnDataSourceDelegate: AnyObject {
    func startStudying(title: String)
}

/// Manages all the rows in the Learn table view.
class LearnDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    weak var delegate: LearnDataSourceDelegate?
    var filter = LearnFilter.all

    private let chapters: [Chapter]
    private let userProgress: () -> LearnProgressProviding

    var displayedChapters: [Chapter] {
        switch filter {
        case .all:
            return chapters
        case .notStarted:
            let progress = userProgress()
            return filteredChapters { section in
                let bundleName = section.bundleName
                return progress.hasLearned(bundleName) == false && progress.hasReviewed(bundleName) == false
            }
        case .completed:
            let progress = userProgress()
            return filteredChapters { section in
                let bundleName = section.bundleName
                return progress.hasLearned(bundleName) && progress.hasReviewed(bundleName)
            }
        }
    }

    init(chapters: [Chapter] = Unwrap.chapters, userProgress: @escaping () -> LearnProgressProviding = { User.current }) {
        self.chapters = chapters
        self.userProgress = userProgress
        super.init()
    }

    convenience init(chapters: [Chapter] = Unwrap.chapters, userProgress: LearnProgressProviding) {
        self.init(chapters: chapters, userProgress: { userProgress })
    }

    func title(for indexPath: IndexPath) -> String {
        return displayedChapters[indexPath.section].sections[indexPath.row]
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return displayedChapters.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as? DynamicHeightHeaderView {
            headerView.headerLabel.text = displayedChapters[section].name
            return headerView
        } else {
            return nil
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayedChapters[section].sections.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.accessoryType = .disclosureIndicator

        let chapter = displayedChapters[indexPath.section]
        let section = chapter.sections[indexPath.row]

        cell.textLabel?.text = section
        cell.textLabel?.numberOfLines = 0

        // Decide how to show the checkmark for this section.

        let score = userProgress().ratingForSection(section.bundleName)

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
        let selectedChapter = displayedChapters[indexPath.section]
        let selectedSection = selectedChapter.sections[indexPath.row]
        delegate?.startStudying(title: selectedSection)
    }

    private func filteredChapters(includeSection: (String) -> Bool) -> [Chapter] {
        return chapters.compactMap { chapter in
            let sections = chapter.sections.filter(includeSection)

            if sections.isEmpty {
                return nil
            } else {
                return Chapter(name: chapter.name, sections: sections)
            }
        }
    }
}
