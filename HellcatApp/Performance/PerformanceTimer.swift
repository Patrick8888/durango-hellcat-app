import CoreLocation
import Foundation
import Observation

/// Times a sprint between two speeds. Uses OBD speed when the adapter is streaming
/// (several updates per second) and falls back to the iPhone's GPS (about 1 per second).
/// Crossing points are interpolated between samples, which matters a lot at 1 Hz.
@Observable
final class PerformanceTimer: NSObject, CLLocationManagerDelegate {
    enum Phase: Equatable {
        case idle
        /// Waiting for the car to be below the start speed.
        case waitingForStart
        /// Below the start speed; the clock starts when the car moves past it.
        case armed
        case running(startedAt: Date)
        case finished(seconds: Double)
    }

    private(set) var phase: Phase = .idle
    private(set) var currentSpeed: Double = 0
    private(set) var source = "GPS"
    var kind: RunKind = .zeroTo100

    @ObservationIgnored private let locationManager = CLLocationManager()
    @ObservationIgnored private var lastSample: (time: Date, speed: Double)?
    @ObservationIgnored private var obdTimer: Timer?
    @ObservationIgnored private var obdSpeed: (() -> Double?)?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.activityType = .automotiveNavigation
    }

    /// - Parameter obdSpeed: returns the latest OBD speed, or nil if no adapter is streaming.
    func arm(obdSpeed: @escaping () -> Double?) {
        self.obdSpeed = obdSpeed
        lastSample = nil
        phase = .waitingForStart

        if obdSpeed() != nil {
            source = "OBD"
            obdTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self, let speed = self.obdSpeed?() else { return }
                self.process(speed: speed, at: Date())
            }
        } else {
            source = "GPS"
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
        }
    }

    func cancel() {
        stopSources()
        phase = .idle
    }

    private func stopSources() {
        obdTimer?.invalidate()
        obdTimer = nil
        locationManager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations where location.speed >= 0 {
            process(speed: location.speed * 3.6, at: location.timestamp)
        }
    }

    // MARK: - Timing

    private func process(speed: Double, at time: Date) {
        // OBD values repeat between polls; only real changes count as samples.
        if let last = lastSample, last.speed == speed, source == "OBD" { return }
        defer { lastSample = (time, speed) }
        currentSpeed = speed

        switch phase {
        case .waitingForStart:
            if kind.startSpeed == 0 ? speed < 1 : speed < kind.startSpeed - 5 {
                phase = .armed
            }
        case .armed:
            let threshold = kind.startSpeed == 0 ? 1 : kind.startSpeed
            if speed >= threshold {
                phase = .running(startedAt: crossing(of: threshold, to: (time, speed)))
            }
        case .running(let start):
            if speed >= kind.targetSpeed {
                let end = crossing(of: kind.targetSpeed, to: (time, speed))
                phase = .finished(seconds: end.timeIntervalSince(start))
                stopSources()
            }
        case .idle, .finished:
            break
        }
    }

    /// Linear interpolation of when the speed passed `threshold` between the previous and current sample.
    private func crossing(of threshold: Double, to sample: (time: Date, speed: Double)) -> Date {
        guard let last = lastSample, sample.speed > last.speed else { return sample.time }
        let fraction = (threshold - last.speed) / (sample.speed - last.speed)
        let interval = sample.time.timeIntervalSince(last.time)
        return last.time.addingTimeInterval(interval * min(max(fraction, 0), 1))
    }
}
