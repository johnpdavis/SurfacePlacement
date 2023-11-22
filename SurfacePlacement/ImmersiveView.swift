//
//  ImmersiveView.swift
//  SurfacePlacement
//
//  Created by John Davis on 11/9/23.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @StateObject var arSessionController: ARSessionController = ARSessionController()
    @State private var realityViewContent: RealityViewContent?
    
    let cylinder: ModelEntity = ModelEntity(
        mesh: .generateCylinder(height: 0.5, radius: 0.02),
        materials: [SimpleMaterial(color: .red, isMetallic: true)]
    )
    
    let targetEntity: ModelEntity = ModelEntity(
        mesh: .generateBox(size: 0.1, cornerRadius: 0.02),
        materials: [SimpleMaterial(color: .cyan, roughness: 0.5, isMetallic: true)],
        collisionShape: .generateBox(size: [0.1, 0.1, 0.1]),
        mass: 0
    )
    
    let surfaceCube: ModelEntity = ModelEntity(
        mesh: .generateBox(width: 1, height: 1, depth: 1, cornerRadius: 0.1),
        materials: [SimpleMaterial(color: .white.withAlphaComponent(0.6), isMetallic: false)],
        collisionShape: .generateBox(size: [1, 1, 1]),
        mass: 0)
    
    var cubeTapGesture: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                let worldPosition: SIMD3<Float> = value.convert(value.location3D, from: .local, to: .scene)
                raycastToLocation(worldPosition, scene: value.entity.scene!)
                
//                let sphere = ModelEntity(mesh: .generateSphere(radius: 0.01), materials: [SimpleMaterial(color: .magenta, isMetallic: false)])
//                realityViewContent?.add(sphere)
//                sphere.setPosition(worldPosition, relativeTo: nil)
            }
    }
    
    @State private var dragStartPosition: SIMD3<Float>? = nil
    var dragTargetGesture: some Gesture {
        DragGesture(coordinateSpace: .local)
            .targetedToEntity(targetEntity)
            .onChanged { value in
                let convertedLocation = value.convert(value.location3D, from: .local, to: value.entity.parent!)
                let convertedStartLocation = value.convert(value.startLocation3D, from: .local, to: value.entity.parent!)
                let delta = convertedLocation - convertedStartLocation
                
                let startLocation = dragStartPosition ?? value.entity.position
                self.dragStartPosition = startLocation
                
                value.entity.position.x = startLocation.x + delta.x
                value.entity.position.y = startLocation.y + delta.y
                value.entity.position.z = startLocation.z + delta.z
                
                snap(value.entity, toSurfaceOf: surfaceCube)
//                reorient(value.entity, to: surfaceCube, at: convertedLocation)
            }
            .onEnded { value in
                dragStartPosition = nil
            }
    }
    
    /*
     @discardableResult
     func snap(_ entity: Entity, toSurfaceOf surfaceEntity: Entity) -> Bool {
         guard let scene = entity.scene else { return false }
         
         let locationOfEntityInWorld = Transform(matrix: entity.transformMatrix(relativeTo: nil)).translation
         let locationOfSurfaceInWorld = Transform(matrix: surfaceEntity.transformMatrix(relativeTo: nil)).translation
         
         let raycastResult = scene.raycast(from: locationOfEntityInWorld, to: locationOfSurfaceInWorld, query: .all, relativeTo: nil)
         
         guard let result = raycastResult.first(where: { $0.entity == surfaceEntity }) else {
             print("NO RAYCAST HITS")
             print("Origin: \(locationOfEntityInWorld), Destination: \(locationOfSurfaceInWorld)")
             let line = drawLineWithCylinder(startPoint: locationOfEntityInWorld, endPoint: locationOfSurfaceInWorld, color: .red)
             realityViewContent?.add(line)
             return false
         }
         
         let oldTransform = entity.transform
         
         // Set new Transform

         entity.setPosition(result.position, relativeTo: nil)
         rotate(entity, toNormal: result.normal)
         
         let translateForSize = result.normal * 0.05
         entity.transform.translation += translateForSize
        }
     */
    

    @discardableResult
    func snap(_ entity: Entity, toSurfaceOf surfaceEntity: Entity) -> Bool {
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

    var body: some View {
        RealityView { content in
            self.realityViewContent = content
            attemptToStartImmseriveCoordinator()
//            await arSessionController.start(realityViewContent:  content)
            // Add the initial RealityKit content
            
            surfaceCube.components.set(InputTargetComponent())
            
            surfaceCube.transform.translation = [0, 1, -3]
            surfaceCube.transform.rotation *= simd_quatf(angle: 90, axis: [1, 0, 0])
            surfaceCube.transform.rotation *= simd_quatf(angle: 90, axis: [0, 1, 0])
            surfaceCube.transform.rotation *= simd_quatf(angle: 90, axis: [0, 0, 1])
            
            surfaceCube.physicsBody = PhysicsBodyComponent(shapes: [.generateConvex(from: surfaceCube.model!.mesh)], density: 1,  mode: .static)
            
            content.add(surfaceCube)
            
            cylinder.transform.translation = [0, 2.5, -3]
            content.add(cylinder)
            
            targetEntity.transform.translation = [0, 2.5, -1]
            targetEntity.components.set(InputTargetComponent())
            targetEntity.physicsBody = PhysicsBodyComponent(shapes: [.generateConvex(from: targetEntity.model!.mesh)], density: 1,  mode: .static)
            content.add(targetEntity)
            
        }
        .gesture(cubeTapGesture)
        .gesture(dragTargetGesture)
        .onAppear {
            attemptToStartImmseriveCoordinator()
        }
        .onDisappear {
            arSessionController.stop()
        }
    }
    
    func reorient(_ entity: Entity, to surfaceEntity: ModelEntity, at position: SIMD3<Float>) {
        guard let scene = surfaceEntity.scene else { return }
        
        raycastOnto(surfaceEntity, at: position, scene: scene) { result in
            rotate(entity, toNormal: result.normal)
        }
    }
    
    func attemptToStartImmseriveCoordinator() {
        guard let realityViewContent else { return }
        guard !arSessionController.isRunning else { return }
        
        Task {
            await arSessionController.start(realityViewContent: realityViewContent)
        }
    }
    
    func raycastOnto(_ entity: Entity, at destination: SIMD3<Float>, scene: RealityKit.Scene, withResult handle: (CollisionCastHit) -> Void ) {
        guard let pose = self.arSessionController.worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            print("FAILED TO GET POSITION")
            return
        }
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
    
//    func orientEntityToNormal(_ entityToOrient: Entity, normal: SIMD3<Float>) {
//        // Calculate the rotation quaternion to align the forward axis with the normal vector
////        let rotation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: normal)
////        let currentForward = simd_make_float3(entityToOrient.transform.matrix.columns.2)
//        let currentForward =
//        let rotation = simd_quatf(from: currentForward, to: normal)
//
//        // Apply the rotation to the entity's transform
//        entityToOrient.transform.rotation *= rotation
//    }
    
    func rotate(_ entity: Entity, toNormal normalVector: SIMD3<Float>, relativeTo anchorEntity: Entity? = nil) {
        // Ensure the normal vector is normalized
        let normalizedNormal = normalize(normalVector)

        let rotationQuaternion = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: normalizedNormal)

        // Apply the rotation to the entity
        entity.transform.rotation = rotationQuaternion
    }
    
    func raycastToLocation(_ destination: SIMD3<Float>, scene: RealityKit.Scene) {
//        guard let content = self.arSessionController.realityViewContent else { return }
        
        guard let pose = self.arSessionController.worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            print("FAILED TO GET POSITION")
            return
        }
        let transform = Transform(matrix: pose.originFromAnchorTransform)
        let locationOfDevice = transform.translation
        
        let raycastResult = scene.raycast(from: locationOfDevice, to: destination, query: .nearest, relativeTo: nil)
        
        guard let result = raycastResult.first else {
            print("NO RAYCAST HITS?????")
            print("Origin: \(locationOfDevice), Destination: \(destination)")
            let line = drawLineWithCylinder(startPoint: locationOfDevice, endPoint: destination, color: .red)
            realityViewContent?.add(line)
            return
        }
        
        let line = drawLineWithCylinder(startPoint: locationOfDevice, endPoint: destination, color: .green)
        realityViewContent?.add(line)
        print("Origin: \(locationOfDevice), Destination: \(destination), result position: \(result.position), normal: \(result.normal)")
        
        let normal = result.normal
        print(normal)
        

        // ROTATE THE CYLINDER
        rotate(cylinder, toNormal: result.normal)
    }
    
    func drawLineWithCylinder(startPoint: SIMD3<Float>, endPoint: SIMD3<Float>, color: UIColor) -> Entity {
        let distance = length(endPoint - startPoint)
        let cylinder = ModelEntity(mesh: .generateCylinder(height: distance, radius: 0.005), materials: [SimpleMaterial(color: color, isMetallic: true)])
        
        let lineEntity = Entity()
        lineEntity.addChild(cylinder)
        lineEntity.transform.translation = (startPoint + endPoint) / 2
        
        let direction = normalize(endPoint - startPoint)
        let axis = cross(SIMD3<Float>(0, 1, 0), direction)
        let angle = acos(dot(SIMD3<Float>(0, 1, 0), direction))
        
        lineEntity.transform.rotation = simd_quatf(angle: angle, axis: axis)
        
        return lineEntity
    }
}

#Preview {
    ImmersiveView()
        .previewLayout(.sizeThatFits)
}
