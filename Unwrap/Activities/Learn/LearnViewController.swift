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

    private let filterControl = UISegmentedControl(items: LearnFilterMode.allCases.map { $0.label })

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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard let headerView = tableView.tableHeaderView, headerView.frame.width != tableView.bounds.width else { return }

        headerView.frame.size.width = tableView.bounds.width
        filterControl.frame = headerView.bounds.insetBy(dx: 16, dy: 10)
        tableView.tableHeaderView = headerView
    }

    /// Refreshes visible cells when the user changes.
    func userDataChanged() {
        guard dataSource.filterMode == .all else {
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

    private func configureFilterControl() {
        filterControl.selectedSegmentIndex = dataSource.filterMode.rawValue
        filterControl.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        filterControl.accessibilityLabel = "Learn filter"
        filterControl.accessibilityValue = dataSource.filterMode.label

        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 56))
        headerView.backgroundColor = tableView.backgroundColor

        filterControl.frame = headerView.bounds.insetBy(dx: 16, dy: 10)
        filterControl.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
        headerView.addSubview(filterControl)

        tableView.tableHeaderView = headerView
    }

    @objc private func filterChanged() {
        guard let filterMode = LearnFilterMode(rawValue: filterControl.selectedSegmentIndex) else { return }

        dataSource.filterMode = filterMode
        filterControl.accessibilityValue = filterMode.label
        tableView.reloadData()
    }
}
