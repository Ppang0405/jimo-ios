//
//  ContentView.swift
//  Jimo
//
//  Created by Gautam Mekkat on 11/6/20.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            if case .loading = appState.firebaseSession {
                Image("splash")
            } else if case .doesNotExist = appState.firebaseSession {
                AuthView()
                    .transition(.slide)
            } else if case .loading = appState.currentUser {
                // Firebase user exists, loading user profile
                Text("Just a sec!")
                    .transition(.opacity)
            } else if case .failed = appState.currentUser {
                // Firebase user exists, failed while loading user profile
                VStack {
                    Button("Unable to connect to server. Tap here to try again") {
                        appState.refreshCurrentUser()
                    }
                    .transition(.opacity)
                    
                    Button("Tap here to sign out") {
                        appState.signOut()
                    }
                    .transition(.opacity)
                }
            } else if case let .user(user) = appState.currentUser {
                // Both exist
                MainAppView(
                    profileVM: ProfileVM(appState: appState, user: user))
                    .transition(.slide)
            } else { // appState.currentUser == .empty
                // Firebase user exists, user profile does not exist
                CreateProfileView()
                    .transition(.slide)
            }
        }
        .onAppear(perform: appState.listen)
    }
}

struct ContentView_Previews: PreviewProvider {
    static let api = APIClient()
    static var previews: some View {
        ContentView()
            .environmentObject(api)
            .environmentObject(AppState(apiClient: api))
    }
}
