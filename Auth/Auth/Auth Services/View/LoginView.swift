//
//  LoginView.swift
//  Auth
//
//  Created by Shailesh Kumar on 05/04/26.
//

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @EnvironmentObject var viewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Login")
                .font(.largeTitle.bold())
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
            
            Button("Sign In") {
                Task {
                    try? await viewModel.signin(email: email, password: password)}
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    LoginView()
}
