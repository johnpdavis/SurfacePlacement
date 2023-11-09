//
//  SurfacePlacementApp.swift
//  SurfacePlacement
//
//  Created by John Davis on 11/9/23.
//

import SwiftUI

@main
struct SurfacePlacementApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
        }.immersionStyle(selection: .constant(.progressive), in: .progressive)
    }
}
