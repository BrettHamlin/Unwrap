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

    private lazy var filterControl: UISegmentedControl = {
        let control = UISegmentedControl(items: LearnProgressFilter.allCases.map { $0.displayTitle })
        control.selectedSegmentIndex = LearnProgressFilter.allCases.firstIndex(of: .all) ?? 0
        control.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        control.accessibilityLabel = "Learn filter"
        control.accessibilityValue = LearnProgressFilter.all.displayTitle
        return control
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        assert(coordinator != nil, "You must set a coordinator before presenting this view controller.")

        title = "Learn"
        navigationItem.titleView = filterControl
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Glossary", style: .plain, target: self, action: #selector(showGlossary))
        registerForUserChanges()
        extendedLayoutIncludesOpaqueBars = true

        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        tableView.addInteraction(UIContextMenuInteraction(delegate: self))
        dataSource.delegate = self

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
    }

    /// Refreshes visible cells when the user changes.
    func userDataChanged() {
        dataSource.refreshVisibleChapters()

        if dataSource.filter != .all {
            tableView.reloadData()
            return
        }

        guard let indexPaths = tableView.indexPathsForVisibleRows else { return }
        tableView.reloadRows(at: indexPaths, with: .none)
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

    @objc private func filterChanged() {
        let filters = LearnProgressFilter.allCases
        let selectedIndex = filterControl.selectedSegmentIndex

        guard filters.indices.contains(selectedIndex) else { return }

        let selectedFilter = filters[selectedIndex]
        filterControl.accessibilityValue = selectedFilter.displayTitle
        dataSource.filter = selectedFilter
    }
}
