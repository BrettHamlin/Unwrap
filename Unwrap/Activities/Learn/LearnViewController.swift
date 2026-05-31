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
    var dataSource = LearnDataSource()

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
        addFilterControl()

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(DynamicHeightHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
    }

    /// Refreshes the table when the user changes.
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

    private func addFilterControl() {
        let headerWidth = tableView.bounds.width > 0 ? tableView.bounds.width : UIScreen.main.bounds.width
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: headerWidth, height: 56))
        headerView.autoresizingMask = [.flexibleWidth]

        let filterControl = UISegmentedControl(items: ["All", "Not Started", "Completed"])
        filterControl.selectedSegmentIndex = 0
        filterControl.accessibilityLabel = "Learn filter"
        filterControl.accessibilityValue = "All"
        filterControl.addTarget(self, action: #selector(filterChanged(_:)), for: .valueChanged)
        filterControl.frame = headerView.bounds.insetBy(dx: 16, dy: 10)
        filterControl.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        headerView.addSubview(filterControl)
        tableView.tableHeaderView = headerView
    }

    @objc func filterChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 1:
            dataSource.filter = .notStarted
        case 2:
            dataSource.filter = .completed
        default:
            dataSource.filter = .all
        }

        if sender.selectedSegmentIndex >= 0 {
            sender.accessibilityValue = sender.titleForSegment(at: sender.selectedSegmentIndex)
        }

        tableView.reloadData()
    }
}
