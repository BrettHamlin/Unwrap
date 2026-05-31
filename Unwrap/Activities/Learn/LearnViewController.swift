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
    let progressFilterControl = UISegmentedControl(items: LearnProgressFilter.allCases.map { $0.label })

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

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")

        configureProgressFilterControl()
    }

    private func configureProgressFilterControl() {
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 56))

        progressFilterControl.selectedSegmentIndex = LearnProgressFilter.allCases.firstIndex(of: dataSource.activeFilter) ?? 0
        progressFilterControl.accessibilityLabel = "Learn filter"
        progressFilterControl.accessibilityValue = dataSource.activeFilter.label
        progressFilterControl.addTarget(self, action: #selector(progressFilterChanged), for: .valueChanged)
        progressFilterControl.translatesAutoresizingMaskIntoConstraints = false

        headerView.addSubview(progressFilterControl)

        NSLayoutConstraint.activate([
            progressFilterControl.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            progressFilterControl.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            progressFilterControl.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 10),
            progressFilterControl.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -10)
        ])

        tableView.tableHeaderView = headerView
    }

    @objc func progressFilterChanged(_ sender: UISegmentedControl) {
        guard LearnProgressFilter.allCases.indices.contains(sender.selectedSegmentIndex) else { return }

        let filter = LearnProgressFilter.allCases[sender.selectedSegmentIndex]
        dataSource.activeFilter = filter
        sender.accessibilityValue = filter.label
        tableView.reloadData()
    }

    /// Refreshes table rows and sections when the user changes.
    func userDataChanged() {
        dataSource.updateFilteredChapters()
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
