import SwiftUI
import CoreLocation

// MARK: - Compass model

class CompassHeading: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var heading: Double = 0
    @Published var authorized: Bool = false

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        authorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
        if authorized { manager.startUpdatingHeading() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.magneticHeading
    }
}

// MARK: - Needle shape

struct CompassNeedle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        path.move(to: CGPoint(x: midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Main view

struct ContentView: View {
    @StateObject private var compass = CompassHeading()

    // 0 = far from north, 1 = exactly north (within 25°)
    private var northProximity: Double {
        let dist = min(compass.heading, 360 - compass.heading)
        return max(0, 1 - dist / 25.0)
    }

    private var isNorth: Bool { northProximity > 0.95 }
    private var isClose: Bool { northProximity > 0.3 }

    private var bgColor: Color { Color(white: northProximity) }
    private var fgColor: Color { Color(white: northProximity > 0.5 ? 0 : 1) }

    private var statusText: String {
        if isNorth   { return "YOU FOUND NORTH! 🎉" }
        if isClose   { return "Getting warm... 🤔" }
        let h = compass.heading
        if h < 90    { return "Slightly lost 🙃" }
        if h < 180   { return "Going East, buddy 😅" }
        if h < 270   { return "Hello, South! 🤪" }
        return "Almost! Keep spinning 🌀"
    }

    var body: some View {
        ZStack {
            bgColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: northProximity)

            if !compass.authorized {
                permissionView
            } else {
                compassView
            }
        }
    }

    // MARK: Compass face

    private var compassView: some View {
        VStack(spacing: 28) {
            Text(statusText)
                .font(.system(size: 22, weight: .black))
                .foregroundColor(fgColor)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.3), value: isNorth)
                .padding(.horizontal)

            ZStack {
                // Outer ring
                Circle()
                    .stroke(fgColor.opacity(0.25), lineWidth: 1)
                    .frame(width: 260, height: 260)

                // Tick marks
                ForEach(0..<36, id: \.self) { i in
                    Rectangle()
                        .fill(fgColor.opacity(i % 9 == 0 ? 0.8 : 0.3))
                        .frame(width: i % 9 == 0 ? 2 : 1,
                               height: i % 9 == 0 ? 14 : 8)
                        .offset(y: -118)
                        .rotationEffect(.degrees(Double(i) * 10))
                }

                // Cardinal labels
                ForEach([("N", 0.0), ("E", 90.0), ("S", 180.0), ("W", 270.0)],
                        id: \.0) { (label, angle) in
                    Text(label)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(label == "N" ? .red : fgColor)
                        .offset(y: -90)
                        .rotationEffect(.degrees(angle))
                }

                // Compass needle (always points to magnetic north)
                ZStack {
                    // North half — red
                    CompassNeedle()
                        .fill(Color.red)
                        .frame(width: 18, height: 58)
                        .offset(y: -29)

                    // South half — flipped, neutral color
                    CompassNeedle()
                        .fill(fgColor.opacity(0.45))
                        .frame(width: 18, height: 58)
                        .scaleEffect(x: 1, y: -1)
                        .offset(y: 29)

                    // Center dot
                    Circle()
                        .fill(fgColor)
                        .frame(width: 10, height: 10)
                }
                .rotationEffect(.degrees(-compass.heading))
                .animation(.easeInOut(duration: 0.25), value: compass.heading)
            }

            // Heading readout
            Text(String(format: "%03.0f°", compass.heading))
                .font(.system(size: 52, weight: .thin, design: .monospaced))
                .foregroundColor(fgColor)
                .animation(.none, value: compass.heading)

            // North celebration
            if isNorth {
                Text("Your phone is smarter than you thought!")
                    .font(.footnote.italic())
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .padding()
    }

    // MARK: Permission prompt

    private var permissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("Location permission needed")
                .font(.title2.bold())
                .foregroundColor(.white)
            Text("Please allow location access in Settings so the compass can tell which way is North.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}
