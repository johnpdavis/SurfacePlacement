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
                
                PlacementUtilities.snap(value.entity, toSurfaceOf: surfaceCube)
//                reorient(value.entity, to: surfaceCube, at: convertedLocation)
            }
            .onEnded { value in
                dragStartPosition = nil
            }
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
    
    func attemptToStartImmseriveCoordinator() {
        guard let realityViewContent else { return }
        guard !arSessionController.isRunning else { return }
        
        Task {
            await arSessionController.start(realityViewContent: realityViewContent)
        }
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
        PlacementUtilities.rotate(cylinder, toNormal: result.normal)
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
