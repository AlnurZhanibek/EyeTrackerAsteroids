//
//  CalibrationScene.swift
//  EyeTrackerAsteroids
//
//  Created by Alnur on 03.03.2026.
//

import SpriteKit

/// Stores the result of calibration: offset and scale corrections applied to raw gaze.
struct CalibrationData {
    var offsetX: CGFloat = 0
    var offsetY: CGFloat = 0
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
}

protocol CalibrationSceneDelegate: AnyObject {
    func calibrationDidComplete(with data: CalibrationData)
}

class CalibrationScene: SKScene {

    // MARK: - Properties

    weak var calibrationDelegate: CalibrationSceneDelegate?

    /// Raw gaze point updated by GameViewController.
    private var rawGazePoint: CGPoint = .zero

    /// Calibration target positions in SpriteKit coordinates.
    private var targetPoints: [CGPoint] = []

    /// Collected raw gaze samples for each target.
    private var collectedSamples: [[CGPoint]] = []
    private var currentSamples: [CGPoint] = []

    private var currentTargetIndex = 0
    private var dotNode: SKShapeNode!
    private var ringNode: SKShapeNode!
    private var instructionLabel: SKLabelNode!
    private var countdownLabel: SKLabelNode!

    private var isCollecting = false
    private var collectTimer: TimeInterval = 0
    private let collectDuration: TimeInterval = 2.0
    private let delayBetweenPoints: TimeInterval = 0.8
    private var delayTimer: TimeInterval = 0
    private var isDelaying = false

    private var lastUpdateTime: TimeInterval = 0

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .black

        setupTargetPoints()
        setupNodes()
        showInstruction()
    }

    // MARK: - Setup

    private func setupTargetPoints() {
        let insetX: CGFloat = 80
        let insetY: CGFloat = 100
        let midX = size.width / 2
        let midY = size.height / 2

        // 5-point calibration: center, then four corners
        targetPoints = [
            CGPoint(x: midX, y: midY),                              // center
            CGPoint(x: insetX, y: size.height - insetY),             // top-left
            CGPoint(x: size.width - insetX, y: size.height - insetY),// top-right
            CGPoint(x: insetX, y: insetY),                           // bottom-left
            CGPoint(x: size.width - insetX, y: insetY),              // bottom-right
        ]
    }

    private func setupNodes() {
        // Target dot
        dotNode = SKShapeNode(circleOfRadius: 14)
        dotNode.fillColor = .cyan
        dotNode.strokeColor = .white
        dotNode.lineWidth = 2
        dotNode.zPosition = 50
        dotNode.isHidden = true
        addChild(dotNode)

        // Progress ring around dot
        ringNode = SKShapeNode(circleOfRadius: 22)
        ringNode.strokeColor = .clear
        ringNode.fillColor = .clear
        ringNode.lineWidth = 3
        ringNode.zPosition = 49
        ringNode.isHidden = true
        addChild(ringNode)

        // Instruction label
        instructionLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        instructionLabel.fontSize = 18
        instructionLabel.fontColor = .white
        instructionLabel.numberOfLines = 3
        instructionLabel.preferredMaxLayoutWidth = size.width - 60
        instructionLabel.horizontalAlignmentMode = .center
        instructionLabel.verticalAlignmentMode = .center
        instructionLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        instructionLabel.zPosition = 60
        addChild(instructionLabel)

        // Countdown label
        countdownLabel = SKLabelNode(fontNamed: "Menlo")
        countdownLabel.fontSize = 14
        countdownLabel.fontColor = SKColor(white: 0.6, alpha: 1.0)
        countdownLabel.position = CGPoint(x: size.width / 2, y: 40)
        countdownLabel.zPosition = 60
        countdownLabel.isHidden = true
        addChild(countdownLabel)
    }

    // MARK: - Instruction

    private func showInstruction() {
        instructionLabel.text = "Calibration\n\nLook at each dot as it appears.\nTap to begin."
        instructionLabel.isHidden = false
    }

    // MARK: - Touch to Start

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !isCollecting && !isDelaying && instructionLabel.isHidden == false {
            instructionLabel.isHidden = true
            beginNextTarget()
        }
    }

    // MARK: - Gaze Update

    /// Called by GameViewController with the raw (uncalibrated) gaze point in UIKit coordinates.
    func updateRawGazePoint(_ point: CGPoint) {
        // Convert from UIKit (top-left origin) to SpriteKit (bottom-left origin)
        rawGazePoint = CGPoint(x: point.x, y: size.height - point.y)
    }

    // MARK: - Calibration Flow

    private func beginNextTarget() {
        print("[Calibration] beginNextTarget: index=\(currentTargetIndex), total=\(targetPoints.count)")
        guard currentTargetIndex < targetPoints.count else {
            finishCalibration()
            return
        }

        let target = targetPoints[currentTargetIndex]
        dotNode.position = target
        ringNode.position = target
        dotNode.isHidden = false
        ringNode.isHidden = false
        countdownLabel.isHidden = false

        // Animate dot appearance
        dotNode.setScale(0.1)
        dotNode.run(SKAction.scale(to: 1.0, duration: 0.3))

        // Start collecting after a short settle delay
        isDelaying = true
        delayTimer = 0
        isCollecting = false
        collectTimer = 0
        currentSamples = []

        updateCountdownLabel()
    }

    private func updateProgressRing(progress: CGFloat) {
        ringNode.removeAllChildren()

        guard progress > 0 else {
            return
        }

        let arcPath = CGMutablePath()
        let startAngle = CGFloat.pi / 2
        let endAngle = startAngle - progress * .pi * 2
        arcPath.addArc(center: .zero, radius: 22,
                       startAngle: startAngle, endAngle: endAngle, clockwise: true)

        let arcNode = SKShapeNode(path: arcPath)
        arcNode.strokeColor = .green
        arcNode.lineWidth = 3
        arcNode.lineCap = .round
        arcNode.fillColor = .clear
        arcNode.zPosition = 49
        ringNode.addChild(arcNode)
    }

    private func updateCountdownLabel() {
        let remaining = currentTargetIndex + 1
        let total = targetPoints.count
        countdownLabel.text = "Point \(remaining) of \(total)"
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        let deltaTime: TimeInterval
        if lastUpdateTime == 0 {
            deltaTime = 0
        } else {
            deltaTime = currentTime - lastUpdateTime
        }
        lastUpdateTime = currentTime

        if isDelaying {
            delayTimer += deltaTime
            if delayTimer >= delayBetweenPoints {
                isDelaying = false
                isCollecting = true
                collectTimer = 0
            }
            return
        }

        guard isCollecting else { return }

        collectTimer += deltaTime
        currentSamples.append(rawGazePoint)

        let progress = CGFloat(collectTimer / collectDuration)
        updateProgressRing(progress: min(progress, 1.0))

        if collectTimer >= collectDuration {
            isCollecting = false
            collectedSamples.append(currentSamples)
            print("[Calibration] Finished collecting target \(currentTargetIndex), samples=\(currentSamples.count), total collected=\(collectedSamples.count)")

            // Flash dot green to confirm
            let flash = SKAction.sequence([
                SKAction.run { [weak self] in self?.dotNode.fillColor = .green },
                SKAction.wait(forDuration: 0.3),
                SKAction.run { [weak self] in
                    self?.dotNode.fillColor = .cyan
                    self?.dotNode.isHidden = true
                    self?.ringNode.isHidden = true
                    self?.ringNode.removeAllChildren()
                }
            ])
            dotNode.run(flash) { [weak self] in
                print("[Calibration] Flash completion, self is \(self == nil ? "nil" : "alive")")
                self?.currentTargetIndex += 1
                self?.beginNextTarget()
            }
        }
    }

    // MARK: - Compute Calibration

    private func finishCalibration() {
        print("[Calibration] finishCalibration called")
        print("[Calibration] collectedSamples.count=\(collectedSamples.count), targetPoints.count=\(targetPoints.count)")
        dotNode.isHidden = true
        ringNode.isHidden = true
        countdownLabel.isHidden = true

        let data = computeCalibration()
        print("[Calibration] computeCalibration done: scaleX=\(data.scaleX), scaleY=\(data.scaleY), offsetX=\(data.offsetX), offsetY=\(data.offsetY)")

        // Show completion message briefly
        instructionLabel.text = "Calibration Complete!"
        instructionLabel.isHidden = false

        print("[Calibration] calibrationDelegate is \(calibrationDelegate == nil ? "nil" : "set")")
        let delegate = calibrationDelegate
        print("[Calibration] captured delegate is \(delegate == nil ? "nil" : "set"), scheduling 1s wait...")

        run(SKAction.wait(forDuration: 1.0)) {
            print("[Calibration] SKAction.wait completed, calling delegate...")
            delegate?.calibrationDidComplete(with: data)
            print("[Calibration] delegate call finished")
        }
    }

    private func computeCalibration() -> CalibrationData {
        // For each calibration point, compute the average raw gaze position
        // then use least-squares to find offset and scale that maps raw -> target.

        guard collectedSamples.count == targetPoints.count else {
            return CalibrationData()
        }

        var averagedRaw: [CGPoint] = []
        for samples in collectedSamples {
            guard !samples.isEmpty else {
                averagedRaw.append(.zero)
                continue
            }
            // Trim first 20% of samples (settling time)
            let trimCount = max(1, samples.count / 5)
            let trimmed = Array(samples.dropFirst(trimCount))
            guard !trimmed.isEmpty else {
                averagedRaw.append(.zero)
                continue
            }
            let avgX = trimmed.map(\.x).reduce(0, +) / CGFloat(trimmed.count)
            let avgY = trimmed.map(\.y).reduce(0, +) / CGFloat(trimmed.count)
            averagedRaw.append(CGPoint(x: avgX, y: avgY))
        }

        // Compute linear fit: targetX = scaleX * rawX + offsetX  (same for Y)
        // Using simple least-squares with 5 points.
        let n = CGFloat(targetPoints.count)

        let sumRawX = averagedRaw.map(\.x).reduce(0, +)
        let sumRawY = averagedRaw.map(\.y).reduce(0, +)
        let sumTargetX = targetPoints.map(\.x).reduce(0, +)
        let sumTargetY = targetPoints.map(\.y).reduce(0, +)

        let sumRawX2 = averagedRaw.map { $0.x * $0.x }.reduce(0, +)
        let sumRawY2 = averagedRaw.map { $0.y * $0.y }.reduce(0, +)

        var sumRawXTargetX: CGFloat = 0
        var sumRawYTargetY: CGFloat = 0
        for i in 0..<targetPoints.count {
            sumRawXTargetX += averagedRaw[i].x * targetPoints[i].x
            sumRawYTargetY += averagedRaw[i].y * targetPoints[i].y
        }

        // Solve for scale and offset via normal equations
        let denomX = n * sumRawX2 - sumRawX * sumRawX
        let denomY = n * sumRawY2 - sumRawY * sumRawY

        var scaleX: CGFloat = 1
        var offsetX: CGFloat = 0
        var scaleY: CGFloat = 1
        var offsetY: CGFloat = 0

        if abs(denomX) > 0.001 {
            scaleX = (n * sumRawXTargetX - sumRawX * sumTargetX) / denomX
            offsetX = (sumTargetX - scaleX * sumRawX) / n
        }

        if abs(denomY) > 0.001 {
            scaleY = (n * sumRawYTargetY - sumRawY * sumTargetY) / denomY
            offsetY = (sumTargetY - scaleY * sumRawY) / n
        }

        return CalibrationData(offsetX: offsetX, offsetY: offsetY,
                               scaleX: scaleX, scaleY: scaleY)
    }
}
