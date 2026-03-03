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

        gameScene = GameScene(size: view.bounds.size)
        gameScene.scaleMode = .resizeFill
        skView.presentScene(gameScene)

        skView.ignoresSiblingOrder = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startFaceTracking()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    private func startFaceTracking() {
        guard ARFaceTrackingConfiguration.isSupported else {
            gameScene.showUnsupportedMessage()
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

        let screenPoint = gazeScreenPoint(from: faceAnchor)
        DispatchQueue.main.async { [weak self] in
            self?.gameScene.updateGazePoint(screenPoint)
        }
    }

    /// Projects the eye gaze direction onto screen coordinates.
    /// Uses the lookAtPoint from the face anchor, which gives the gaze direction
    /// in face-local space, and maps it to 2D screen coordinates.
    private func gazeScreenPoint(from faceAnchor: ARFaceAnchor) -> CGPoint {
        let lookAt = faceAnchor.lookAtPoint

        // lookAtPoint is in face coordinate space:
        // +x = face's left (viewer's right), +y = up, +z = out of face (toward viewer)
        // The front camera mirrors the image horizontally, so we negate x.
        // We map the gaze angles to screen positions.

        let screenWidth = view.bounds.width
        let screenHeight = view.bounds.height

        // Calculate gaze angles (in radians)
        let distance = sqrt(lookAt.x * lookAt.x + lookAt.y * lookAt.y + lookAt.z * lookAt.z)
        guard distance > 0 else { return CGPoint(x: screenWidth / 2, y: screenHeight / 2) }

        // Horizontal and vertical gaze angles
        let horizontalAngle = atan2(lookAt.x, lookAt.z)  // left-right
        let verticalAngle = atan2(lookAt.y, lookAt.z)     // up-down

        // Sensitivity multiplier: maps gaze angle range to screen coordinates.
        // Typical eye movement range is roughly ±0.5 radians for comfortable viewing.
        let sensitivity: CGFloat = 3.5

        // Map to screen coordinates. Center of screen is the neutral gaze position.
        // Negate horizontal because face coordinate x is mirrored relative to screen.
        let normalizedX = 0.5 - CGFloat(horizontalAngle) * sensitivity
        let normalizedY = 0.5 - CGFloat(verticalAngle) * sensitivity

        let clampedX = max(0, min(screenWidth, normalizedX * screenWidth))
        let clampedY = max(0, min(screenHeight, normalizedY * screenHeight))

        return CGPoint(x: clampedX, y: clampedY)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
