//
//  GameScene.swift
//  EyeTrackerAsteroids
//
//  Created by Alnur on 03.03.2026.
//

import SpriteKit

class GameScene: SKScene {

    // MARK: - Properties

    private var gazePoint: CGPoint = .zero
    private var gazeCursor: SKShapeNode!
    private var asteroids: [Asteroid] = []
    private var scoreLabel: SKLabelNode!
    private var score: Int = 0
    private var lastUpdateTime: TimeInterval = 0
    private var spawnTimer: TimeInterval = 0
    private let spawnInterval: TimeInterval = 2.5
    private let gazeHoldDuration: TimeInterval = 5.0
    private let asteroidHitRadius: CGFloat = 60.0
    private var isGameActive = false
    private var startLabel: SKLabelNode!

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .black
        setupStarfield()
        setupGazeCursor()
        setupScoreLabel()
        setupStartPrompt()
    }

    // MARK: - Setup

    private func setupStarfield() {
        // Create a simple starfield background
        for _ in 0..<100 {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...2.0))
            star.fillColor = .white
            star.strokeColor = .clear
            star.alpha = CGFloat.random(in: 0.3...1.0)
            star.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            star.zPosition = -10
            addChild(star)

            // Twinkling animation
            let fadeOut = SKAction.fadeAlpha(to: CGFloat.random(in: 0.1...0.3), duration: Double.random(in: 1.0...3.0))
            let fadeIn = SKAction.fadeAlpha(to: CGFloat.random(in: 0.6...1.0), duration: Double.random(in: 1.0...3.0))
            star.run(SKAction.repeatForever(SKAction.sequence([fadeOut, fadeIn])))
        }
    }

    private func setupGazeCursor() {
        gazeCursor = SKShapeNode(circleOfRadius: 8)
        gazeCursor.fillColor = SKColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 0.5)
        gazeCursor.strokeColor = SKColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 0.8)
        gazeCursor.lineWidth = 2
        gazeCursor.zPosition = 100
        gazeCursor.isHidden = true
        addChild(gazeCursor)
    }

    private func setupScoreLabel() {
        scoreLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        scoreLabel.fontSize = 24
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: 20, y: size.height - 50)
        scoreLabel.zPosition = 50
        scoreLabel.text = "Score: 0"
        addChild(scoreLabel)
    }

    private func setupStartPrompt() {
        startLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        startLabel.fontSize = 20
        startLabel.fontColor = .cyan
        startLabel.text = "Tap to Start"
        startLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 40)
        startLabel.zPosition = 50

        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.fontSize = 28
        title.fontColor = .white
        title.text = "EYE TRACKER ASTEROIDS"
        title.position = CGPoint(x: size.width / 2, y: size.height / 2 + 40)
        title.zPosition = 50
        title.name = "titleLabel"
        addChild(title)

        let instructions = SKLabelNode(fontNamed: "Menlo")
        instructions.fontSize = 14
        instructions.fontColor = SKColor(white: 0.7, alpha: 1.0)
        instructions.text = "Look at an asteroid for 5 seconds to destroy it"
        instructions.position = CGPoint(x: size.width / 2, y: size.height / 2)
        instructions.zPosition = 50
        instructions.name = "instructionsLabel"
        addChild(instructions)

        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.4, duration: 0.8),
            SKAction.fadeAlpha(to: 1.0, duration: 0.8)
        ])
        startLabel.run(SKAction.repeatForever(pulse))
        addChild(startLabel)
    }

    func showUnsupportedMessage() {
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.fontSize = 18
        label.fontColor = .red
        label.numberOfLines = 2
        label.text = "Face tracking not supported\non this device"
        label.position = CGPoint(x: size.width / 2, y: size.height / 2)
        label.zPosition = 100
        addChild(label)
    }

    // MARK: - Game Flow

    private func startGame() {
        isGameActive = true
        score = 0
        scoreLabel.text = "Score: 0"
        gazeCursor.isHidden = false

        // Remove start screen elements
        startLabel.removeFromParent()
        childNode(withName: "titleLabel")?.removeFromParent()
        childNode(withName: "instructionsLabel")?.removeFromParent()

        // Remove any existing asteroids
        for asteroid in asteroids {
            asteroid.node.removeFromParent()
        }
        asteroids.removeAll()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !isGameActive {
            startGame()
        }
    }

    // MARK: - Eye Gaze Update

    /// Called by GameViewController when a new gaze point is calculated.
    func updateGazePoint(_ point: CGPoint) {
        // Convert from UIKit coordinates (origin top-left) to SpriteKit coordinates (origin bottom-left)
        gazePoint = CGPoint(x: point.x, y: size.height - point.y)
    }

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        guard isGameActive else {
            lastUpdateTime = currentTime
            return
        }

        let deltaTime: TimeInterval
        if lastUpdateTime == 0 {
            deltaTime = 0
        } else {
            deltaTime = currentTime - lastUpdateTime
        }
        lastUpdateTime = currentTime

        // Smoothly move gaze cursor
        let smoothing: CGFloat = 0.15
        let currentPos = gazeCursor.position
        gazeCursor.position = CGPoint(
            x: currentPos.x + (gazePoint.x - currentPos.x) * smoothing,
            y: currentPos.y + (gazePoint.y - currentPos.y) * smoothing
        )

        // Spawn asteroids
        spawnTimer += deltaTime
        if spawnTimer >= spawnInterval {
            spawnTimer = 0
            spawnAsteroid()
        }

        // Update asteroid gaze tracking
        updateAsteroidGazeTracking(deltaTime: deltaTime)

        // Move asteroids
        updateAsteroidMovement(deltaTime: deltaTime)
    }

    // MARK: - Asteroid Spawning

    private func spawnAsteroid() {
        let maxAsteroids = 5
        guard asteroids.count < maxAsteroids else { return }

        let asteroid = Asteroid(sceneSize: size)
        addChild(asteroid.node)
        asteroids.append(asteroid)
    }

    // MARK: - Gaze Tracking Logic

    private func updateAsteroidGazeTracking(deltaTime: TimeInterval) {
        let gazePos = gazeCursor.position

        for asteroid in asteroids {
            let distance = hypot(gazePos.x - asteroid.node.position.x,
                                 gazePos.y - asteroid.node.position.y)

            if distance < asteroidHitRadius {
                // User is looking at this asteroid
                asteroid.gazeTime += deltaTime
                asteroid.updateProgressRing(progress: asteroid.gazeTime / gazeHoldDuration)

                if asteroid.gazeTime >= gazeHoldDuration {
                    destroyAsteroid(asteroid)
                }
            } else {
                // User looked away - reset progress
                if asteroid.gazeTime > 0 {
                    asteroid.gazeTime = 0
                    asteroid.updateProgressRing(progress: 0)
                }
            }
        }
    }

    // MARK: - Asteroid Destruction

    private func destroyAsteroid(_ asteroid: Asteroid) {
        score += 100
        scoreLabel.text = "Score: \(score)"

        // Explosion effect
        let explosionPosition = asteroid.node.position
        createExplosion(at: explosionPosition)

        // Remove asteroid
        asteroid.node.removeFromParent()
        asteroids.removeAll { $0 === asteroid }
    }

    private func createExplosion(at position: CGPoint) {
        let particleCount = 12
        for i in 0..<particleCount {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...6))
            particle.fillColor = [SKColor.orange, SKColor.yellow, SKColor.red].randomElement()!
            particle.strokeColor = .clear
            particle.position = position
            particle.zPosition = 30
            addChild(particle)

            let angle = CGFloat(i) / CGFloat(particleCount) * .pi * 2
            let dist = CGFloat.random(in: 40...100)
            let dest = CGPoint(x: position.x + cos(angle) * dist,
                               y: position.y + sin(angle) * dist)

            let moveAction = SKAction.move(to: dest, duration: 0.4)
            moveAction.timingMode = .easeOut
            let fadeAction = SKAction.fadeOut(withDuration: 0.4)
            let group = SKAction.group([moveAction, fadeAction])
            particle.run(SKAction.sequence([group, SKAction.removeFromParent()]))
        }

        // Score popup
        let popup = SKLabelNode(fontNamed: "Menlo-Bold")
        popup.fontSize = 20
        popup.fontColor = .green
        popup.text = "+100"
        popup.position = position
        popup.zPosition = 40
        addChild(popup)
        let moveUp = SKAction.moveBy(x: 0, y: 50, duration: 0.8)
        let fade = SKAction.fadeOut(withDuration: 0.8)
        popup.run(SKAction.sequence([SKAction.group([moveUp, fade]), SKAction.removeFromParent()]))
    }

    // MARK: - Asteroid Movement

    private func updateAsteroidMovement(deltaTime: TimeInterval) {
        var toRemove: [Asteroid] = []
        for asteroid in asteroids {
            asteroid.node.position.x += asteroid.velocity.dx * CGFloat(deltaTime)
            asteroid.node.position.y += asteroid.velocity.dy * CGFloat(deltaTime)
            asteroid.node.zRotation += asteroid.rotationSpeed * CGFloat(deltaTime)

            // Remove asteroids that drift off screen (with padding)
            let padding: CGFloat = 80
            if asteroid.node.position.x < -padding ||
               asteroid.node.position.x > size.width + padding ||
               asteroid.node.position.y < -padding ||
               asteroid.node.position.y > size.height + padding {
                toRemove.append(asteroid)
            }
        }
        for asteroid in toRemove {
            asteroid.node.removeFromParent()
            asteroids.removeAll { $0 === asteroid }
        }
    }
}

// MARK: - Asteroid Class

class Asteroid {
    let node: SKNode
    var velocity: CGVector
    var rotationSpeed: CGFloat
    var gazeTime: TimeInterval = 0
    private let progressRing: SKShapeNode
    private let bodyNode: SKShapeNode
    private let radius: CGFloat

    init(sceneSize: CGSize) {
        radius = CGFloat.random(in: 20...40)
        node = SKNode()

        // Create an irregular asteroid shape
        let path = CGMutablePath()
        let segments = Int.random(in: 7...10)
        for i in 0...segments {
            let angle = CGFloat(i) / CGFloat(segments) * .pi * 2
            let variance = CGFloat.random(in: 0.7...1.3)
            let r = radius * variance
            let point = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()

        bodyNode = SKShapeNode(path: path)
        bodyNode.fillColor = SKColor(red: 0.4, green: 0.35, blue: 0.3, alpha: 1.0)
        bodyNode.strokeColor = SKColor(red: 0.6, green: 0.55, blue: 0.5, alpha: 1.0)
        bodyNode.lineWidth = 1.5
        bodyNode.zPosition = 10
        node.addChild(bodyNode)

        // Add some surface detail (craters)
        for _ in 0..<Int.random(in: 2...4) {
            let craterRadius = CGFloat.random(in: 3...8)
            let crater = SKShapeNode(circleOfRadius: craterRadius)
            crater.fillColor = SKColor(red: 0.3, green: 0.25, blue: 0.2, alpha: 1.0)
            crater.strokeColor = .clear
            let craterAngle = CGFloat.random(in: 0...(.pi * 2))
            let craterDist = CGFloat.random(in: 0...(radius * 0.5))
            crater.position = CGPoint(x: cos(craterAngle) * craterDist,
                                      y: sin(craterAngle) * craterDist)
            crater.zPosition = 11
            node.addChild(crater)
        }

        // Progress ring (hidden until gaze starts)
        progressRing = SKShapeNode(circleOfRadius: radius + 8)
        progressRing.strokeColor = .clear
        progressRing.fillColor = .clear
        progressRing.lineWidth = 3
        progressRing.zPosition = 15
        node.addChild(progressRing)

        // Determine spawn position along screen edges
        let edge = Int.random(in: 0...3)
        var startPos: CGPoint
        switch edge {
        case 0: // top
            startPos = CGPoint(x: CGFloat.random(in: 60...(sceneSize.width - 60)),
                               y: sceneSize.height + radius)
        case 1: // bottom
            startPos = CGPoint(x: CGFloat.random(in: 60...(sceneSize.width - 60)),
                               y: -radius)
        case 2: // left
            startPos = CGPoint(x: -radius,
                               y: CGFloat.random(in: 60...(sceneSize.height - 60)))
        default: // right
            startPos = CGPoint(x: sceneSize.width + radius,
                               y: CGFloat.random(in: 60...(sceneSize.height - 60)))
        }
        node.position = startPos

        // Velocity aimed roughly toward center of screen with some randomness
        let center = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        let dirX = center.x - startPos.x + CGFloat.random(in: -100...100)
        let dirY = center.y - startPos.y + CGFloat.random(in: -100...100)
        let length = hypot(dirX, dirY)
        let speed = CGFloat.random(in: 20...50)
        velocity = CGVector(dx: dirX / length * speed, dy: dirY / length * speed)

        rotationSpeed = CGFloat.random(in: -2...2)
    }

    func updateProgressRing(progress: Double) {
        progressRing.removeAllChildren()

        if progress <= 0 {
            progressRing.strokeColor = .clear
            return
        }

        let clampedProgress = min(progress, 1.0)

        // Create arc path for progress
        let arcPath = CGMutablePath()
        let startAngle = CGFloat.pi / 2 // Start from top
        let endAngle = startAngle - CGFloat(clampedProgress) * .pi * 2
        arcPath.addArc(center: .zero, radius: radius + 8,
                       startAngle: startAngle, endAngle: endAngle, clockwise: true)

        let arcNode = SKShapeNode(path: arcPath)
        arcNode.strokeColor = progressColor(for: clampedProgress)
        arcNode.lineWidth = 3
        arcNode.lineCap = .round
        arcNode.fillColor = .clear
        arcNode.zPosition = 15
        progressRing.addChild(arcNode)

        // Glow effect on the asteroid body when being gazed at
        bodyNode.strokeColor = progressColor(for: clampedProgress)
        bodyNode.lineWidth = 1.5 + CGFloat(clampedProgress) * 2.0
    }

    private func progressColor(for progress: Double) -> SKColor {
        // Transition from cyan to yellow to red as progress increases
        if progress < 0.5 {
            let t = CGFloat(progress / 0.5)
            return SKColor(red: t, green: 1.0, blue: 1.0 - t, alpha: 1.0)
        } else {
            let t = CGFloat((progress - 0.5) / 0.5)
            return SKColor(red: 1.0, green: 1.0 - t, blue: 0.0, alpha: 1.0)
        }
    }
}
