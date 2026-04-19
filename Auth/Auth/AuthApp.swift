//
//  AuthApp.swift
//  Auth
//
//  Created by Shailesh Kumar on 05/04/26.
//

import SwiftUI
import FirebaseCore

@main
struct AuthApp: App {
    init() {
        FirebaseApp.configure()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
