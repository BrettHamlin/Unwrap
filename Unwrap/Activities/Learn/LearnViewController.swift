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

    let progressFilterControl = UISegmentedControl(items: ["All", "Not Started", "Completed"])

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

        configureProgressFilter()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateProgressFilterHeaderSize()
    }

    /// Refreshes visible sections when the user changes.
    func userDataChanged() {
        dataSource.applyFilter(dataSource.currentFilter)
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

    private func configureProgressFilter() {
        progressFilterControl.selectedSegmentIndex = 0
        progressFilterControl.addTarget(self, action: #selector(progressFilterChanged), for: .valueChanged)

        let headerView = UIView()
        progressFilterControl.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(progressFilterControl)

        NSLayoutConstraint.activate([
            progressFilterControl.leadingAnchor.constraint(equalTo: headerView.layoutMarginsGuide.leadingAnchor),
            progressFilterControl.trailingAnchor.constraint(equalTo: headerView.layoutMarginsGuide.trailingAnchor),
            progressFilterControl.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 12),
            progressFilterControl.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -12)
        ])

        tableView.tableHeaderView = headerView
        updateProgressFilterHeaderSize()
    }

    private func updateProgressFilterHeaderSize() {
        guard let headerView = tableView.tableHeaderView else { return }

        let headerWidth = tableView.bounds.width > 0 ? tableView.bounds.width : UIScreen.main.bounds.width
        let fittingSize = CGSize(width: headerWidth, height: UIView.layoutFittingCompressedSize.height)
        let headerHeight = headerView.systemLayoutSizeFitting(fittingSize, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
        let headerSize = CGSize(width: headerWidth, height: headerHeight)

        if headerView.frame.size != headerSize {
            headerView.frame.size = headerSize
            tableView.tableHeaderView = headerView
        }
    }

    @objc func progressFilterChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 1:
            dataSource.applyFilter(.notStarted)
        case 2:
            dataSource.applyFilter(.completed)
        default:
            dataSource.applyFilter(.all)
        }
    }
}
