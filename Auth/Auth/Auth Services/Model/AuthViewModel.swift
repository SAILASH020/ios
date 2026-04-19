//
//  AuthViewModel.swift
//  Auth
//
//  Created by Shailesh Kumar on 05/04/26.
//

import Foundation
import FirebaseAuth
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var user: User?
    
    init() {
        Auth.auth().addStateDidChangeListener { _, user in
            self.user = user
        }
    }
    
    func signup(email: String, password: String) async throws {
        
        try await Auth.auth().createUser(withEmail: email, password: password)
    }
    
    func signin(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password           )
    }
    
    func signOut() {
        try? Auth.auth().signOut()
    }
    
    
}
