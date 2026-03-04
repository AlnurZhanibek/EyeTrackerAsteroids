//
//  GameViewController.swift
//  EyeTrackerAsteroids
//
//  Created by Alnur on 03.03.2026.
//

import UIKit
import SpriteKit
import ARKit
import SceneKit

class GameViewController: UIViewController, ARSessionDelegate {

    private var sceneView: ARSCNView!
    private var skView: SKView!
    private var gameScene: GameScene!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up the hidden ARSCNView for face tracking
        sceneView = ARSCNView(frame: view.bounds)
        sceneView.session.delegate = self
        sceneView.isHidden = true
        view.addSubview(sceneView)

        // Set up the visible SKView for the game
        skView = SKView(frame: view.bounds)
        skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(skView)

        skView.ignoresSiblingOrder = true

        // Go straight to the game
        gameScene = GameScene(size: view.bounds.size)
        gameScene.scaleMode = .resizeFill
        skView.presentScene(gameScene)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startFaceTracking()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    // MARK: - Face Tracking

    private func startFaceTracking() {
        guard ARFaceTrackingConfiguration.isSupported else {
            gameScene?.showUnsupportedMessage()
            return
        }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = false
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.first(where: { $0 is ARFaceAnchor }) as? ARFaceAnchor else {
            return
        }

        let gazePoint = rawGazeScreenPoint(from: faceAnchor)

        DispatchQueue.main.async { [weak self] in
            self?.gameScene?.updateGazePoint(gazePoint)
        }
    }

    private func rawGazeScreenPoint(from faceAnchor: ARFaceAnchor) -> CGPoint {
        let lookAtPoint = faceAnchor.lookAtPoint

        guard let cameraTransform = sceneView.session.currentFrame?.camera.transform else {
            return CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        }

        // Transform lookAtPoint into world space, then into camera space
        let lookAtInWorld = faceAnchor.transform * simd_float4(lookAtPoint, 1)
        let lookAtInCamera = simd_mul(simd_inverse(cameraTransform), lookAtInWorld)

        let screenWidth = view.bounds.width
        let screenHeight = view.bounds.height

        // Approximate physical screen size in meters
        let ppi: CGFloat = 460
        let scale = UIScreen.main.scale
        let physicalWidth = screenWidth * scale / ppi * 0.0254
        let physicalHeight = screenHeight * scale / ppi * 0.0254

        // In camera space for portrait: Y maps to screen X, X maps to screen Y.
        // Normalize to [-0.5, 0.5] range, then shift to [0, 1] for screen mapping.
        let normalizedX = 0.5 + CGFloat(lookAtInCamera.y) / physicalWidth
        let normalizedY = 0.5 + CGFloat(lookAtInCamera.x) / physicalHeight

        let screenX = normalizedX * screenWidth
        let screenY = normalizedY * screenHeight

        return CGPoint(
            x: max(0, min(screenWidth, screenX)),
            y: max(0, min(screenHeight, screenY))
        )
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
