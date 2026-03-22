//
//  MainViewController.swift
//  FacialRecognition
//
//  Created by chetuimac0031 on 06/03/26.
//

import UIKit

enum ScannerMode { case registration, attendance }

class MainViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground; setupUI()
    }
    
    private func setupUI() {
        let stack = UIStackView()
        stack.axis = .vertical; stack.spacing = 25; stack.distribution = .fillEqually
        
        let regBtn = createBtn(title: "Register New Face", color: .systemBlue, action: #selector(onRegister))
        let logBtn = createBtn(title: "Clock In/Out", color: .systemGreen, action: #selector(onAttendance))
        let histBtn = createBtn(title: "View History", color: .systemGray, action: #selector(onHistory))
        
        [regBtn, logBtn, histBtn].forEach { stack.addArrangedSubview($0) }
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.widthAnchor.constraint(equalToConstant: 260),
            stack.heightAnchor.constraint(equalToConstant: 240)
        ])
    }

    @objc func onRegister() {
        let alert = UIAlertController(title: "Register", message: "Enter Name", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Full Name" }
        alert.addAction(UIAlertAction(title: "Open Camera", style: .default) { _ in
            guard let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            self.presentScanner(mode: .registration, name: name)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel)); present(alert, animated: true)
    }

    @objc func onAttendance() { presentScanner(mode: .attendance) }
    @objc func onHistory() { present(UINavigationController(rootViewController: HistoryViewController()), animated: true) }

    private func presentScanner(mode: ScannerMode, name: String? = nil) {
        let sc = ScannerViewController(); sc.mode = mode; sc.registerName = name
        sc.modalPresentationStyle = .fullScreen; present(sc, animated: true)
    }

    private func createBtn(title: String, color: UIColor, action: Selector) -> UIButton {
        let b = UIButton(type: .system); b.setTitle(title, for: .normal); b.backgroundColor = color
        b.setTitleColor(.white, for: .normal); b.layer.cornerRadius = 15; b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }
}
