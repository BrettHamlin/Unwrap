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
    let filterControl = UISegmentedControl(items: ["All", "Not Started", "Completed"])

    override func viewDidLoad() {
        super.viewDidLoad()

        assert(coordinator != nil, "You must set a coordinator before presenting this view controller.")

        title = "Learn"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Glossary", style: .plain, target: self, action: #selector(showGlossary))
        registerForUserChanges()
        extendedLayoutIncludesOpaqueBars = true
        configureFilterControl()

        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        tableView.addInteraction(UIContextMenuInteraction(delegate: self))
        dataSource.delegate = self

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
    }

    func configureFilterControl() {
        filterControl.selectedSegmentIndex = 0
        filterControl.accessibilityLabel = "Learn filter"
        filterControl.accessibilityValue = filterControl.titleForSegment(at: filterControl.selectedSegmentIndex)
        filterControl.addTarget(self, action: #selector(filterChanged), for: .valueChanged)

        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 56))
        headerView.addSubview(filterControl)
        filterControl.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            filterControl.leadingAnchor.constraint(equalTo: headerView.layoutMarginsGuide.leadingAnchor),
            filterControl.trailingAnchor.constraint(equalTo: headerView.layoutMarginsGuide.trailingAnchor),
            filterControl.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])

        tableView.tableHeaderView = headerView
    }

    @objc func filterChanged() {
        switch filterControl.selectedSegmentIndex {
        case 1:
            dataSource.filter = .notStarted
        case 2:
            dataSource.filter = .completed
        default:
            dataSource.filter = .all
        }

        filterControl.accessibilityValue = filterControl.titleForSegment(at: filterControl.selectedSegmentIndex)
        tableView.reloadData()
    }

    /// Refreshes all cells when the user changes.
    func userDataChanged() {
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
