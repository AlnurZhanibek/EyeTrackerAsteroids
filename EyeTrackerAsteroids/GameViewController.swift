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

class GameViewController: UIViewController, ARSessionDelegate, CalibrationSceneDelegate {

    private var sceneView: ARSCNView!
    private var skView: SKView!
    private var gameScene: GameScene!
    private var calibrationScene: CalibrationScene?
    private var calibrationData: CalibrationData?
    private var isCalibrating = true

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

        // Start with calibration
        showCalibration()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startFaceTracking()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    // MARK: - Calibration

    private func showCalibration() {
        isCalibrating = true
        calibrationScene = CalibrationScene(size: view.bounds.size)
        calibrationScene!.scaleMode = .resizeFill
        calibrationScene!.calibrationDelegate = self
        skView.presentScene(calibrationScene!)
    }

    func calibrationDidComplete(with data: CalibrationData) {
        calibrationData = data
        isCalibrating = false
        calibrationScene = nil
        
        // Transition to the game scene
        gameScene = GameScene(size: view.bounds.size)
        gameScene.scaleMode = .resizeFill
        skView.presentScene(gameScene)
    }

    // MARK: - Face Tracking

    private func startFaceTracking() {
        guard ARFaceTrackingConfiguration.isSupported else {
            if isCalibrating {
                // Skip calibration if face tracking isn't available
                calibrationDidComplete(with: CalibrationData())
            }
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

        let rawPoint = rawGazeScreenPoint(from: faceAnchor)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.isCalibrating {
                // Feed raw gaze to calibration scene
                self.calibrationScene?.updateRawGazePoint(rawPoint)
            } else {
                // Apply calibration and feed to game scene
                let calibrated = self.applyCalibration(to: rawPoint)
                self.gameScene?.updateGazePoint(calibrated)
            }
        }
    }

    /// Projects the eye gaze direction onto screen coordinates (raw, uncalibrated).
    private func rawGazeScreenPoint(from faceAnchor: ARFaceAnchor) -> CGPoint {
        let lookAt = faceAnchor.lookAtPoint

        let screenWidth = view.bounds.width
        let screenHeight = view.bounds.height

        let distance = sqrt(lookAt.x * lookAt.x + lookAt.y * lookAt.y + lookAt.z * lookAt.z)
        guard distance > 0 else { return CGPoint(x: screenWidth / 2, y: screenHeight / 2) }

        let horizontalAngle = atan2(lookAt.x, lookAt.z)
        let verticalAngle = atan2(lookAt.y, lookAt.z)

        let sensitivity: CGFloat = 3.5

        let normalizedX = 0.5 - CGFloat(horizontalAngle) * sensitivity
        let normalizedY = 0.5 - CGFloat(verticalAngle) * sensitivity

        let clampedX = max(0, min(screenWidth, normalizedX * screenWidth))
        let clampedY = max(0, min(screenHeight, normalizedY * screenHeight))

        return CGPoint(x: clampedX, y: clampedY)
    }

    /// Applies calibration correction to raw gaze point.
    /// The calibration data maps raw coordinates to corrected screen coordinates
    /// using a linear model: corrected = scale * raw + offset.
    /// Input and output are in UIKit coordinates (origin top-left).
    private func applyCalibration(to rawPoint: CGPoint) -> CGPoint {
        guard let cal = calibrationData else { return rawPoint }

        let screenWidth = view.bounds.width
        let screenHeight = view.bounds.height

        // Calibration was computed in SpriteKit coords (bottom-left origin).
        // Convert raw point to SK coords, apply calibration, convert back.
        let rawSK = CGPoint(x: rawPoint.x, y: screenHeight - rawPoint.y)

        let correctedX = cal.scaleX * rawSK.x + cal.offsetX
        let correctedY = cal.scaleY * rawSK.y + cal.offsetY

        // Convert back to UIKit coords and clamp
        let uiX = max(0, min(screenWidth, correctedX))
        let uiY = max(0, min(screenHeight, screenHeight - correctedY))

        return CGPoint(x: uiX, y: uiY)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
