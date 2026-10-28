import XCTest
@testable import BigFishCore

/// Time is supplied explicitly so redraw cadence and event timing cannot hide
/// a discontinuity behind wall-clock sleeps or screenshot tolerance.
final class CustomSkinMotionTests: XCTestCase {
    private func assertWeightsEqual(_ first: [String: Double], _ second: [String: Double],
                                    file: StaticString = #filePath, line: UInt = #line) {
        for pose in Set(first.keys).union(second.keys) {
            XCTAssertEqual(first[pose] ?? 0, second[pose] ?? 0, accuracy: 1e-10,
                           "Pose \(pose) changed at the interruption", file: file, line: line)
        }
    }

    private func assertNormalized(_ weights: [String: Double],
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(weights.values.reduce(0, +), 1, accuracy: 1e-9, file: file, line: line)
        for weight in weights.values {
            XCTAssertTrue(weight.isFinite, file: file, line: line)
            XCTAssertGreaterThanOrEqual(weight, 0, file: file, line: line)
            XCTAssertLessThanOrEqual(weight, 1, file: file, line: line)
        }
    }

    func testInterruptedTransitionStartsFromCurrentBlendRatherThanOldDestination() {
        var mixer = SkinPoseMixer(initialPose: "IDLE")
        mixer.reset(to: "IDLE", at: 0)
        _ = mixer.update(requested: "THINKING", at: 0, immediate: true)
        let presented = mixer.weights(at: 0.21)
        XCTAssertGreaterThan(presented["IDLE"] ?? 0, 0.1)
        XCTAssertGreaterThan(presented["THINKING"] ?? 0, 0.1)

        let interrupted = mixer.update(requested: "WORKING", at: 0.21, immediate: true)
        assertWeightsEqual(interrupted, presented)
        assertWeightsEqual(mixer.weights(at: 0.21), presented)

        let progressing = mixer.weights(at: 0.35)
        XCTAssertGreaterThan(progressing["IDLE"] ?? 0, 0)
        XCTAssertGreaterThan(progressing["THINKING"] ?? 0, 0)
        XCTAssertGreaterThan(progressing["WORKING"] ?? 0, 0)
        assertNormalized(progressing)
        XCTAssertEqual(mixer.weights(at: 0.7)["WORKING"] ?? 0, 1, accuracy: 1e-9)
    }

    func testRepeatedStateEventsDoNotRestartAnActiveTransition() {
        var mixer = SkinPoseMixer(initialPose: "IDLE")
        mixer.reset(to: "IDLE", at: 0)
        _ = mixer.update(requested: "WORKING", at: 0, immediate: true)
        _ = mixer.update(requested: "WORKING", at: 0.1, immediate: true)
        _ = mixer.update(requested: "WORKING", at: 0.2, immediate: true)
        _ = mixer.update(requested: "WORKING", at: 0.4, immediate: true)
        XCTAssertEqual(mixer.weights(at: 0.43)["WORKING"] ?? 0, 1, accuracy: 1e-9)
    }

    func testRapidNoncriticalCandidatesCoalesceAndRespectMinimumDwell() {
        var mixer = SkinPoseMixer(initialPose: "IDLE", duration: 0.42,
                                  minimumDwell: 1, coalescingDelay: 0.12)
        mixer.reset(to: "IDLE", at: 0)
        _ = mixer.update(requested: "THINKING", at: 0, immediate: true)
        _ = mixer.update(requested: "WORKING", at: 0.2)
        _ = mixer.update(requested: "WAITING", at: 0.23)
        _ = mixer.update(requested: "WAITING", at: 0.34)
        XCTAssertEqual(mixer.targetPose, "THINKING")
        _ = mixer.update(requested: "WAITING", at: 0.36)
        XCTAssertEqual(mixer.targetPose, "THINKING", "A stable candidate must still respect dwell")
        _ = mixer.update(requested: "WAITING", at: 1.01)
        XCTAssertEqual(mixer.targetPose, "WAITING")
        XCTAssertNil(mixer.weights(at: 1.22)["WORKING"], "Superseded transient pose must not flash")
    }

    func testImmediateInteractionBypassesDwellButPreservesCurrentPresentation() {
        var mixer = SkinPoseMixer(initialPose: "IDLE", minimumDwell: 10, coalescingDelay: 10)
        mixer.reset(to: "IDLE", at: 0)
        _ = mixer.update(requested: "THINKING", at: 0, immediate: true)
        let before = mixer.weights(at: 0.05)
        let after = mixer.update(requested: "dragging", at: 0.05, immediate: true)
        XCTAssertEqual(mixer.targetPose, "dragging")
        assertWeightsEqual(before, after)
        XCTAssertEqual(mixer.weights(at: 0.5)["dragging"] ?? 0, 1, accuracy: 1e-9)
    }

    func testInterruptedWeightsRemainFiniteNormalizedAndBounded() {
        var mixer = SkinPoseMixer(initialPose: "IDLE")
        mixer.reset(to: "IDLE", at: 0)
        let poses = ["IDLE", "THINKING", "WORKING", "interaction", "dragging"]
        for index in 0..<600 {
            let time = Double(index) / 120
            let pose = poses[(index / 7) % poses.count]
            let weights = mixer.update(requested: pose, at: time, immediate: true)
            assertNormalized(weights)
            assertNormalized(mixer.weights(at: time + 1.0 / 240.0))
        }
    }

    func testSpringRetargetPreservesPositionAndVelocityAtRelease() {
        var spring = DampedSkinSpring(position: 0, velocity: 0, target: 1, time: 0)
        var expected = spring
        expected.advance(to: 0.18)
        spring.retarget(0, at: 0.18)
        XCTAssertEqual(spring.position, expected.position, accuracy: 1e-10)
        XCTAssertEqual(spring.velocity, expected.velocity, accuracy: 1e-10)
        spring.advance(to: 2.18)
        XCTAssertEqual(spring.position, 0, accuracy: 1e-7)
        XCTAssertEqual(spring.velocity, 0, accuracy: 1e-6)
    }

    func testSpringHasSameTrajectoryAtThirtySixtyAndOneTwentyHertz() {
        func sampled(at fps: Int) -> DampedSkinSpring {
            var spring = DampedSkinSpring(position: -0.5, velocity: 2, target: 0, time: 0)
            for index in 1...fps { spring.advance(to: Double(index) / Double(fps)) }
            return spring
        }
        let baseline = sampled(at: 30)
        for fps in [60, 120] {
            let other = sampled(at: fps)
            XCTAssertEqual(other.position, baseline.position, accuracy: 1e-10)
            XCTAssertEqual(other.velocity, baseline.velocity, accuracy: 1e-10)
        }
    }

    func testSpringImpulseAddsVelocityWithoutTeleportingPosition() {
        var spring = DampedSkinSpring(position: 0.3, velocity: 0, target: 0, time: 0)
        var expected = spring
        expected.advance(to: 0.2)
        spring.impulse(velocity: 1.2, at: 0.2)
        XCTAssertEqual(spring.position, expected.position, accuracy: 1e-10)
        XCTAssertEqual(spring.velocity, expected.velocity + 1.2, accuracy: 1e-10)
    }
}
