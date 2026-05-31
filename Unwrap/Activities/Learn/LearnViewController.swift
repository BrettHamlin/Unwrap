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
    private let filterControl = UISegmentedControl(items: LearnFilterMode.allCases.map(\.rawValue))

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

        configureFilterControl()
    }

    /// Refreshes the list when the user changes.
    func userDataChanged() {
        dataSource.rebuildFilteredChapters()
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
        filterControl.selectedSegmentIndex = LearnFilterMode.allCases.firstIndex(of: dataSource.filterMode) ?? 0
        filterControl.addTarget(self, action: #selector(filterModeChanged(_:)), for: .valueChanged)
        filterControl.accessibilityLabel = "Learn filter"
        filterControl.accessibilityValue = dataSource.filterMode.rawValue

        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 60))
        filterControl.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(filterControl)

        NSLayoutConstraint.activate([
            filterControl.leadingAnchor.constraint(equalTo: headerView.layoutMarginsGuide.leadingAnchor),
            filterControl.trailingAnchor.constraint(equalTo: headerView.layoutMarginsGuide.trailingAnchor),
            filterControl.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            filterControl.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])

        tableView.tableHeaderView = headerView
    }

    @objc private func filterModeChanged(_ sender: UISegmentedControl) {
        guard LearnFilterMode.allCases.indices.contains(sender.selectedSegmentIndex) else { return }

        let selectedMode = LearnFilterMode.allCases[sender.selectedSegmentIndex]
        dataSource.filterMode = selectedMode
        sender.accessibilityValue = selectedMode.rawValue
        tableView.reloadData()
    }
}
