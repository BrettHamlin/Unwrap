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
    enum FilterMode: CaseIterable {
        case all
        case notStarted
        case completed
    }

    struct VisibleChapter {
        let chapterIndex: Int
        let sectionIndices: [Int]
    }

    weak var delegate: LearnViewController?
    private(set) var visibleChapters: [VisibleChapter] = []

    var filterMode = FilterMode.all {
        didSet {
            rebuildVisibleSections()
        }
    }

    override init() {
        super.init()
        rebuildVisibleSections()
    }

    func rebuildVisibleSections() {
        visibleChapters = Unwrap.chapters.enumerated().compactMap { chapterIndex, chapter in
            let sectionIndices: [Int]

            switch filterMode {
            case .all:
                sectionIndices = Array(chapter.sections.indices)
            case .notStarted:
                sectionIndices = chapter.sections.indices.filter {
                    let section = chapter.sections[$0].bundleName
                    return User.current.hasLearned(section) == false && User.current.hasReviewed(section) == false
                }
            case .completed:
                sectionIndices = chapter.sections.indices.filter {
                    let section = chapter.sections[$0].bundleName
                    return User.current.hasLearned(section) && User.current.hasReviewed(section)
                }
            }

            if filterMode != .all && sectionIndices.isEmpty {
                return nil
            } else {
                return VisibleChapter(chapterIndex: chapterIndex, sectionIndices: sectionIndices)
            }
        }
    }

    func title(for indexPath: IndexPath) -> String {
        let visibleChapter = visibleChapters[indexPath.section]
        let sectionIndex = visibleChapter.sectionIndices[indexPath.row]
        return Unwrap.chapters[visibleChapter.chapterIndex].sections[sectionIndex]
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
}
