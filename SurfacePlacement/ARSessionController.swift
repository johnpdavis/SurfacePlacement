//
//  ARManager.swift
//  SurfacePlacement
//
//  Created by John Davis on 11/9/23.
//

import ARKit
import Foundation
import RealityKit
import SwiftUI

class ARSessionController: ObservableObject {
    private let session = ARKitSession()
    private(set) var worldTracking = WorldTrackingProvider()
    
    @Published var worldAnchors: [UUID: WorldAnchor] = [:]

    var realityViewContent: RealityViewContent?
    
    @Published private(set) var isRunning: Bool = false
    
    init() {
        
    }
    
    @MainActor
    func stop() {
        isRunning = false
        session.stop()
        
        realityViewContent?.entities.forEach {
            realityViewContent?.entities.remove($0)
        }
        
//        entityMap.removeAll()
//        collisionEntities.removeAll()
    }
    
    @MainActor
    func start(realityViewContent: RealityViewContent) async {
        self.realityViewContent = realityViewContent
        self.isRunning = true
        
        do {
            if WorldTrackingProvider.isSupported {
                try await session.run([worldTracking])
                print("World Tracking Provider Started.")
            } else {
                print("World Tracking not supported >.>")
            }
        } catch {
            print("ARKitSession error:", error)
        }
        
        for await update in worldTracking.anchorUpdates {
            switch update.event {
            case .added, .updated:
                updateAnchor(update.anchor)
            case .removed:
                removeAnchor(update.anchor)
            }
        }
    }
    
    @MainActor
    func updateAnchor(_ anchor: WorldAnchor) {
        worldAnchors[anchor.id] = anchor
    }
    
    @MainActor
    func removeAnchor(_ anchor: WorldAnchor) {
        worldAnchors.removeValue(forKey: anchor.id)
    }
}
