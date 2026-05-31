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

    private(set) var progressFilterControl = UISegmentedControl(items: ["All", "Not Started", "Completed"])

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

        configureProgressFilterControl()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
    }

    /// Refreshes visible cells when the user changes.
    func userDataChanged() {
        dataSource.updateVisibleChapters()
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
        progressFilterControl.accessibilityValue = "All"
        progressFilterControl.addTarget(self, action: #selector(progressFilterChanged), for: .valueChanged)

        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 56))
        progressFilterControl.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(progressFilterControl)

        NSLayoutConstraint.activate([
            progressFilterControl.leadingAnchor.constraint(equalTo: headerView.layoutMarginsGuide.leadingAnchor),
            progressFilterControl.trailingAnchor.constraint(equalTo: headerView.layoutMarginsGuide.trailingAnchor),
            progressFilterControl.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 12),
            progressFilterControl.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8)
        ])

        tableView.tableHeaderView = headerView
    }

    @objc func progressFilterChanged() {
        switch progressFilterControl.selectedSegmentIndex {
        case 1:
            dataSource.activeFilter = .notStarted
        case 2:
            dataSource.activeFilter = .completed
        default:
            dataSource.activeFilter = .all
        }

        progressFilterControl.accessibilityValue = progressFilterControl.titleForSegment(at: progressFilterControl.selectedSegmentIndex)
        tableView.reloadData()
    }
}
