//
//  HistoryViewController.swift
//  FacialRecognition
//
//  Created by chetuimac0031 on 06/03/26.
//

import UIKit

class HistoryViewController: UITableViewController {
    var logs: [[String: String]] = []; var users: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "History & Users"; navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Close", style: .done, target: self, action: #selector(close))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell"); refresh()
    }

    private func refresh() { logs = AttendanceDB.shared.getTodayLogs(); users = AttendanceDB.shared.getAllUserNames(); tableView.reloadData() }
    @objc func close() { dismiss(animated: true) }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection s: Int) -> String? { s == 0 ? "Today's Logs" : "Registered Users" }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection s: Int) -> Int { s == 0 ? logs.count : users.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        if indexPath.section == 0 {
            let l = logs[indexPath.row]; cell.textLabel?.text = l["name"]
            cell.detailTextLabel?.text = "In: \(l["in"]?.suffix(8) ?? "") | Out: \(l["out"]?.suffix(8) ?? "")"
        } else { cell.textLabel?.text = users[indexPath.row]; cell.detailTextLabel?.text = "Registered User" }
        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete && indexPath.section == 1 {
            AttendanceDB.shared.deleteUser(name: users[indexPath.row]); users.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
}

