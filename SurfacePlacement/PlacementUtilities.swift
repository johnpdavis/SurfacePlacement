//
//  PlacementUtilities.swift
//  SurfacePlacement
//
//  Created by John Davis on 11/22/23.
//

import ARKit
import RealityKit

enum PlacementUtilities {
    @discardableResult
    static func snap(_ entity: Entity, toSurfaceOf surfaceEntity: Entity) -> Bool {
        guard let scene = entity.scene else { return false }
        
        let locationOfEntityInWorld = Transform(matrix: entity.transformMatrix(relativeTo: nil)).translation
        let locationOfSurfaceInWorld = Transform(matrix: surfaceEntity.transformMatrix(relativeTo: nil)).translation
        
        let raycastResult = scene.raycast(from: locationOfEntityInWorld, to: locationOfSurfaceInWorld, query: .all, relativeTo: nil)
        
        guard let result = raycastResult.first(where: { $0.entity == surfaceEntity }) else {
            print("NO RAYCAST HITS")
            print("Origin: \(locationOfEntityInWorld), Destination: \(locationOfSurfaceInWorld)")
//            let line = drawLineWithCylinder(startPoint: locationOfEntityInWorld, endPoint: locationOfSurfaceInWorld, color: .red)
//            realityViewContent?.add(line)
            return false
        }
        
        // Following the normal of the raycast result, move the raycast position away the size of the small guy.
        let correctedLOcationOfEntityInWorld = locationOfEntityInWorld + result.normal * 0.15
        
        let secondRaycastResult = scene.raycast(from: correctedLOcationOfEntityInWorld, to: locationOfSurfaceInWorld, query: .all, relativeTo: nil)
        
        guard let result = secondRaycastResult.first(where: { $0.entity == surfaceEntity }) else {
            print("NO RAYCAST HITS")
            print("Origin: \(correctedLOcationOfEntityInWorld), Destination: \(locationOfSurfaceInWorld)")
//            let line = drawLineWithCylinder(startPoint: locationOfEntityInWorld, endPoint: locationOfSurfaceInWorld, color: .red)
//            realityViewContent?.add(line)
            return false
        }
        
        // Set new Transform

        entity.setPosition(result.position, relativeTo: nil)
        rotate(entity, toNormal: result.normal)
        
        let translateForSize = result.normal * 0.05
        entity.transform.translation += translateForSize
        
        return true
    }
    
    static func rotate(_ entity: Entity, toNormal normalVector: SIMD3<Float>, relativeTo anchorEntity: Entity? = nil) {
        // Ensure the normal vector is normalized
        let normalizedNormal = normalize(normalVector)

        let rotationQuaternion = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: normalizedNormal)

        // Apply the rotation to the entity
        entity.transform.rotation = rotationQuaternion
    }
    
    static func reorient(_ entity: Entity, to surfaceEntity: ModelEntity, at position: SIMD3<Float>, devicePose: DeviceAnchor) {
        guard let scene = surfaceEntity.scene else { return }
        
        raycastOnto(surfaceEntity, at: position, scene: scene, pose: devicePose) { result in
            rotate(entity, toNormal: result.normal)
        }
    }
    
    static func raycastOnto(_ entity: Entity, at destination: SIMD3<Float>, scene: RealityKit.Scene, pose: DeviceAnchor, withResult handle: (CollisionCastHit) -> Void ) {
//        guard let pose = self.arSessionController.worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
//            print("FAILED TO GET POSITION")
//            return
//        }
        let transform = Transform(matrix: pose.originFromAnchorTransform)
        let locationOfDevice = transform.translation
        
        let raycastResult = scene.raycast(from: locationOfDevice, to: destination, query: .all, relativeTo: nil)
        
        guard let result = raycastResult.first(where:  { $0.entity == entity }) else {
            print("NO RAYCAST HITS")
            print("Origin: \(locationOfDevice), Destination: \(destination)")
//            let line = drawLineWithCylinder(startPoint: locationOfDevice, endPoint: destination, color: .red)
//            realityViewContent?.add(line)
            return
        }
        
        print("Origin: \(locationOfDevice), Destination: \(destination), result position: \(result.position), normal: \(result.normal)")
        handle(result)
    }
    
}
