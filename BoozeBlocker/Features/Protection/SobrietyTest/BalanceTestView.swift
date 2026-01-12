import SwiftUI
import CoreMotion

/// Balance test using device motion sensors
struct BalanceTestView: View {
    let onComplete: (Bool) -> Void
    
    @State private var testState: BalanceTestState = .instructions
    @State private var motionManager = CMMotionManager()
    @State private var deviations: [Double] = []
    @State private var currentDeviation: Double = 0
    @State private var timeRemaining: Int = 10
    @State private var timer: Timer?
    @State private var averageDeviation: Double = 0
    
    private let testDuration = 10 // seconds
    private let maxAllowedDeviation: Double = 0.15 // radians (~8.5 degrees)
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "figure.stand")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                Text("Balance Test")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(instructionText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Test visualization
            switch testState {
            case .instructions:
                instructionsView
                
            case .testing:
                testingView
                
            case .complete:
                resultsView
            }
            
            Spacer()
            
            // Action button
            if testState == .instructions {
                Button {
                    startTest()
                } label: {
                    Text("Start Test")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .onDisappear {
            stopTest()
        }
    }
    
    private var instructionText: String {
        switch testState {
        case .instructions:
            return "Hold your phone flat in front of you and keep it as steady as possible for 10 seconds"
        case .testing:
            return "Keep the phone steady..."
        case .complete:
            return averageDeviation < maxAllowedDeviation ? "Great balance!" : "Too much movement detected"
        }
    }
    
    private var instructionsView: some View {
        VStack(spacing: 20) {
            // Phone illustration
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.blue, lineWidth: 3)
                    .frame(width: 120, height: 200)
                
                VStack {
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 40, height: 40)
                    
                    Text("📱")
                        .font(.system(size: 40))
                }
            }
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "1.circle.fill")
                        .foregroundColor(.blue)
                    Text("Hold phone flat in front of you")
                }
                
                HStack {
                    Image(systemName: "2.circle.fill")
                        .foregroundColor(.blue)
                    Text("Keep arms slightly extended")
                }
                
                HStack {
                    Image(systemName: "3.circle.fill")
                        .foregroundColor(.blue)
                    Text("Stay as still as possible")
                }
            }
            .font(.subheadline)
        }
    }
    
    private var testingView: some View {
        VStack(spacing: 30) {
            // Timer
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 10)
                    .frame(width: 150, height: 150)
                
                Circle()
                    .trim(from: 0, to: CGFloat(timeRemaining) / CGFloat(testDuration))
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timeRemaining)
                
                Text("\(timeRemaining)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
            }
            
            // Deviation indicator
            VStack(spacing: 8) {
                Text("Stability")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(stabilityColor)
                            .frame(width: max(0, geometry.size.width * (1 - currentDeviation / maxAllowedDeviation)), height: 8)
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, 40)
                
                Text(stabilityText)
                    .font(.caption)
                    .foregroundColor(stabilityColor)
            }
        }
    }
    
    private var resultsView: some View {
        VStack(spacing: 20) {
            let passed = averageDeviation < maxAllowedDeviation
            
            ZStack {
                Circle()
                    .fill(passed ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(passed ? .green : .red)
            }
            
            Text(passed ? "Test Passed" : "Test Failed")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 4) {
                Text("Average deviation: \(String(format: "%.1f", averageDeviation * 57.3))°")
                    .font(.subheadline)
                Text("Threshold: \(String(format: "%.1f", maxAllowedDeviation * 57.3))°")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button {
                onComplete(passed)
            } label: {
                Text("Continue")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(passed ? Color.green : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
    
    private var stabilityColor: Color {
        if currentDeviation < maxAllowedDeviation * 0.5 {
            return .green
        } else if currentDeviation < maxAllowedDeviation {
            return .yellow
        } else {
            return .red
        }
    }
    
    private var stabilityText: String {
        if currentDeviation < maxAllowedDeviation * 0.5 {
            return "Excellent"
        } else if currentDeviation < maxAllowedDeviation {
            return "Good"
        } else {
            return "Too much movement"
        }
    }
    
    private func startTest() {
        testState = .testing
        timeRemaining = testDuration
        deviations = []
        
        // Start motion updates
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
                guard let motion = motion else { return }
                
                // Calculate deviation from flat (pitch and roll)
                let pitch = abs(motion.attitude.pitch)
                let roll = abs(motion.attitude.roll)
                let deviation = sqrt(pitch * pitch + roll * roll)
                
                currentDeviation = deviation
                deviations.append(deviation)
            }
        }
        
        // Start countdown timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            timeRemaining -= 1
            
            if timeRemaining <= 0 {
                finishTest()
            }
        }
    }
    
    private func stopTest() {
        timer?.invalidate()
        timer = nil
        motionManager.stopDeviceMotionUpdates()
    }
    
    private func finishTest() {
        stopTest()
        
        // Calculate average deviation
        if !deviations.isEmpty {
            averageDeviation = deviations.reduce(0, +) / Double(deviations.count)
        }
        
        testState = .complete
        
        if averageDeviation < maxAllowedDeviation {
            HapticService.shared.success()
        } else {
            HapticService.shared.error()
        }
    }
}

enum BalanceTestState {
    case instructions
    case testing
    case complete
}

#Preview {
    BalanceTestView { passed in
        print("Passed: \(passed)")
    }
}
