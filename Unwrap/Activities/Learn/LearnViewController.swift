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

    private let filterControl = UISegmentedControl(items: ["All", "Not Started", "Completed"])

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Learn"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Glossary", style: .plain, target: self, action: #selector(showGlossary))
        registerForUserChanges()
        extendedLayoutIncludesOpaqueBars = true

        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        tableView.addInteraction(UIContextMenuInteraction(delegate: self))
        dataSource.delegate = self

        configureFilterControl()

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
    }

    /// Refreshes visible cells when the user changes.
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

    private func configureFilterControl() {
        filterControl.selectedSegmentIndex = 0
        filterControl.accessibilityLabel = "Learn filter"
        filterControl.accessibilityValue = "All"
        filterControl.addTarget(self, action: #selector(filterChanged), for: .valueChanged)

        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 56))
        headerView.autoresizingMask = [.flexibleWidth]

        filterControl.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(filterControl)

        NSLayoutConstraint.activate([
            filterControl.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            filterControl.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            filterControl.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 10),
            filterControl.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -10)
        ])

        tableView.tableHeaderView = headerView
    }

    @objc private func filterChanged() {
        switch filterControl.selectedSegmentIndex {
        case 1:
            dataSource.filter = .notStarted
            filterControl.accessibilityValue = "Not Started"

        case 2:
            dataSource.filter = .completed
            filterControl.accessibilityValue = "Completed"

        default:
            dataSource.filter = .all
            filterControl.accessibilityValue = "All"
        }

        tableView.reloadData()
    }
}
