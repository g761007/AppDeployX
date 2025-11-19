//
//  AppDeployX.swift
//  AppDeployX
//
//  Created by Daniel Hsieh on 2025/11/19.
//

import SwiftUI

@main
struct AppDeployX: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}
