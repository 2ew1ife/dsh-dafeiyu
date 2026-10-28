import Foundation

/// Interruptible pose weights. The state is sampled at the instant a new
/// target commits, so a transition never snaps back to its former destination.
struct SkinPoseMixer {
    private(set) var targetPose: String
    let duration: Double
    let minimumDwell: Double
    let coalescingDelay: Double
    private var startWeights: [String: Double]
    private var transitionStarted = -Double.infinity
    private var lastCommit = -Double.infinity
    private var candidate: String?
    private var candidateSince: Double = 0

    init(initialPose: String = "IDLE", duration: Double = 0.42,
         minimumDwell: Double = 0.36, coalescingDelay: Double = 0.12) {
        targetPose = initialPose
        startWeights = [initialPose: 1]
        self.duration = max(0, duration)
        self.minimumDwell = max(0, minimumDwell)
        self.coalescingDelay = max(0, coalescingDelay)
    }

    mutating func update(requested: String, at time: Double, immediate: Bool = false) -> [String: Double] {
        guard time.isFinite else { return [targetPose: 1] }
        if requested == targetPose {
            candidate = nil
        } else {
            if candidate != requested {
                candidate = requested
                candidateSince = time
            }
            if immediate || (time - candidateSince >= coalescingDelay && time - lastCommit >= minimumDwell) {
                startWeights = weights(at: time)
                targetPose = requested
                transitionStarted = time
                lastCommit = time
                candidate = nil
            }
        }
        return weights(at: time)
    }

    func weights(at time: Double) -> [String: Double] {
        guard duration > 0, time.isFinite else { return [targetPose: 1] }
        let progress = min(1, max(0, (time - transitionStarted) / duration))
        // Quintic smootherstep has zero velocity and acceleration at both ends.
        let eased = progress * progress * progress * (progress * (progress * 6 - 15) + 10)
        if progress >= 1 { return [targetPose: 1] }
        var result = startWeights.mapValues { $0 * (1 - eased) }
        result[targetPose, default: 0] += eased
        return result.filter { $0.value > 0 }
    }

    mutating func reset(to pose: String, at time: Double) {
        targetPose = pose
        startWeights = [pose: 1]
        transitionStarted = time
        lastCommit = time
        candidate = nil
    }
}

/// An exact damped spring solution, independent of frame cadence. Retargeting
/// first advances the presentation and retains position and velocity.
struct DampedSkinSpring {
    private(set) var position: Double
    private(set) var velocity: Double
    private(set) var target: Double
    private var sampledAt: Double
    private let omega: Double
    private let damping: Double

    init(position: Double = 0, velocity: Double = 0, target: Double = 0,
         time: Double = 0, frequency: Double = 3.0, dampingRatio: Double = 0.68) {
        self.position = position
        self.velocity = velocity
        self.target = target
        sampledAt = time
        omega = 2 * .pi * max(0.01, frequency)
        damping = min(0.999, max(0.01, dampingRatio))
    }

    mutating func retarget(_ value: Double, at time: Double) {
        advance(to: time)
        if value.isFinite { target = value }
    }

    mutating func impulse(velocity addedVelocity: Double, at time: Double) {
        advance(to: time)
        if addedVelocity.isFinite { velocity += addedVelocity }
    }

    mutating func advance(to time: Double) {
        guard time.isFinite, time >= sampledAt else { return }
        let delta = time - sampledAt
        guard delta > 0 else { return }
        sampledAt = time
        let offset = position - target
        let decay = damping * omega
        let frequency = omega * sqrt(1 - damping * damping)
        let sine = sin(frequency * delta)
        let cosine = cos(frequency * delta)
        let envelope = exp(-decay * delta)
        let oldVelocity = velocity
        position = target + envelope * (offset * cosine + (oldVelocity + decay * offset) / frequency * sine)
        velocity = envelope * (oldVelocity * cosine - (decay * oldVelocity + omega * omega * offset) / frequency * sine)
    }
}
