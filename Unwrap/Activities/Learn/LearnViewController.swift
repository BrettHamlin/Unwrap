//
//  LearnViewController.swift
//  Unwrap
//
//  Created by Paul Hudson on 09/08/2018.
//  Copyright © 2019 Hacking with Swift.
//

import UIKit

/// The main view controller you see in  the Home tab in the app.
class LearnViewController: UITableViewController, UserTracking, UIContextMenuInteractionDelegate {
    var coordinator: LearnCoordinator?

    /// This handles all the rows in our table view.
    let dataSource = LearnDataSource()

    let progressFilter = UISegmentedControl(items: ["All", "Not Started", "Completed"])

    override func viewDidLoad() {
        super.viewDidLoad()

        assert(coordinator != nil, "You must set a coordinator before presenting this view controller.")

        title = "Learn"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Glossary", style: .plain, target: self, action: #selector(showGlossary))
        registerForUserChanges()
        extendedLayoutIncludesOpaqueBars = true

        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        tableView.addInteraction(UIContextMenuInteraction(delegate: self))
        dataSource.delegate = self

        configureProgressFilter()

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
    }

    func configureProgressFilter() {
        progressFilter.selectedSegmentIndex = 0
        progressFilter.accessibilityLabel = "Learn filter"
        progressFilter.accessibilityValue = progressFilter.titleForSegment(at: progressFilter.selectedSegmentIndex)
        progressFilter.addTarget(self, action: #selector(progressFilterChanged), for: .valueChanged)

        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 56))
        progressFilter.frame = CGRect(x: 16, y: 6, width: max(tableView.bounds.width - 32, 0), height: 44)
        progressFilter.autoresizingMask = [.flexibleWidth]
        headerView.addSubview(progressFilter)
        tableView.tableHeaderView = headerView
    }

    @objc func progressFilterChanged() {
        switch progressFilter.selectedSegmentIndex {
        case 1:
            dataSource.filterMode = .notStarted
        case 2:
            dataSource.filterMode = .completed
        default:
            dataSource.filterMode = .all
        }

        progressFilter.accessibilityValue = progressFilter.titleForSegment(at: progressFilter.selectedSegmentIndex)
        tableView.reloadData()
    }

    /// Refreshes the list when the user changes.
    func userDataChanged() {
        dataSource.rebuildVisibleSections()
        tableView.reloadData()
    }

    func startStudying(title: String) {
        coordinator?.startStudying(title: title)
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        if let indexPath = tableView.indexPathForRow(at: location) {
            let selectedChapter = dataSource.title(for: indexPath)
            let controller = coordinator?.studyViewController(for: selectedChapter)

            return UIContextMenuConfiguration(identifier: nil, previewProvider: {
                return controller
            }, actionProvider: nil)
        }

        return nil
    }

    @objc func showGlossary() {
        coordinator?.showGlossary()
    }
}
