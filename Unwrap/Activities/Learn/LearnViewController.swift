//
//  LearnViewController.swift
//  Unwrap
//
//  Created by Paul Hudson on 09/08/2018.
//  Copyright © 2019 Hacking with Swift.
//

import UIKit

/// The main view controller you see in  the Home tab in the app.
class LearnViewController: UITableViewController, UserTracking, UIContextMenuInteractionDelegate, LearnSelectionDelegate {
    var coordinator: LearnCoordinator?

    /// This handles all the rows in our table view.
    var dataSource = LearnDataSource()

    let progressFilterControl = UISegmentedControl(items: ["All", "Not Started", "Completed"])

    override func viewDidLoad() {
        super.viewDidLoad()

        assert(coordinator != nil, "You must set a coordinator before presenting this view controller.")

        title = "Learn"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Glossary", style: .plain, target: self, action: #selector(showGlossary))
        configureProgressFilterControl()
        registerForUserChanges()
        extendedLayoutIncludesOpaqueBars = true

        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        tableView.addInteraction(UIContextMenuInteraction(delegate: self))
        dataSource.delegate = self

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
    }

    /// Refreshes the table when the user changes.
    func userDataChanged() {
        dataSource.refreshVisibleChapters()
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

    private func configureProgressFilterControl() {
        progressFilterControl.selectedSegmentIndex = 0
        progressFilterControl.accessibilityLabel = "Learn filter"
        progressFilterControl.accessibilityValue = progressFilterControl.titleForSegment(at: 0)
        progressFilterControl.addTarget(self, action: #selector(progressFilterChanged), for: .valueChanged)
        navigationItem.titleView = progressFilterControl
    }

    @objc func progressFilterChanged() {
        switch progressFilterControl.selectedSegmentIndex {
        case 1:
            dataSource.filter = .notStarted

        case 2:
            dataSource.filter = .completed

        default:
            dataSource.filter = .all
        }

        progressFilterControl.accessibilityValue = progressFilterControl.titleForSegment(at: progressFilterControl.selectedSegmentIndex)
        tableView.reloadData()
    }
}
