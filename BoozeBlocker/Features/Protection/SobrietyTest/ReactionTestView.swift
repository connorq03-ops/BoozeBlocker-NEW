import SwiftUI

/// Reaction time test - tap when the screen turns green
struct ReactionTestView: View {
    let onComplete: (Bool) -> Void
    
    @State private var testState: ReactionTestState = .waiting
    @State private var reactionTimes: [TimeInterval] = []
    @State private var waitStartTime: Date?
    @State private var greenStartTime: Date?
    @State private var currentRound: Int = 0
    @State private var tooEarlyCount: Int = 0
    
    private let totalRounds = 5
    private let maxReactionTime: TimeInterval = 0.5 // 500ms threshold
    private let requiredPasses = 3 // Need 3 out of 5 under threshold
    
    var averageReactionTime: TimeInterval {
        guard !reactionTimes.isEmpty else { return 0 }
        return reactionTimes.reduce(0, +) / Double(reactionTimes.count)
    }
    
    var passedRounds: Int {
        reactionTimes.filter { $0 < maxReactionTime }.count
    }
    
    var body: some View {
        ZStack {
            // Background color based on state
            backgroundColor
                .ignoresSafeArea()
                .onTapGesture {
                    handleTap()
                }
            
            VStack(spacing: 20) {
                // Header
                if testState != .showingGreen {
                    VStack(spacing: 8) {
                        Text("Reaction Test")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(textColor)
                        
                        Text("Round \(currentRound + 1) of \(totalRounds)")
                            .font(.subheadline)
                            .foregroundColor(textColor.opacity(0.8))
                    }
                    .padding(.top, 60)
                }
                
                Spacer()
                
                // Instructions/Results
                VStack(spacing: 16) {
                    switch testState {
                    case .waiting:
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 60))
                            .foregroundColor(textColor)
                        Text("Wait for green...")
                            .font(.title3)
                            .foregroundColor(textColor)
                        
                    case .showingGreen:
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                        Text("TAP NOW!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                    case .tooEarly:
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        Text("Too early!")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("Wait for green")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                    case .showingResult(let time):
                        Image(systemName: time < maxReactionTime ? "checkmark.circle.fill" : "clock.fill")
                            .font(.system(size: 60))
                            .foregroundColor(time < maxReactionTime ? .green : .orange)
                        Text("\(Int(time * 1000)) ms")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(textColor)
                        Text(time < maxReactionTime ? "Good!" : "Too slow")
                            .font(.title3)
                            .foregroundColor(time < maxReactionTime ? .green : .orange)
                        
                    case .complete:
                        completionView
                    }
                }
                
                Spacer()
                
                // Progress dots
                if testState != .complete {
                    HStack(spacing: 12) {
                        ForEach(0..<totalRounds, id: \.self) { index in
                            Circle()
                                .fill(dotColor(for: index))
                                .frame(width: 12, height: 12)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            startRound()
        }
    }
    
    private var completionView: some View {
        VStack(spacing: 20) {
            let passed = passedRounds >= requiredPasses
            
            Image(systemName: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(passed ? .green : .red)
            
            Text(passed ? "Test Passed!" : "Test Failed")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(textColor)
            
            VStack(spacing: 8) {
                Text("Average: \(Int(averageReactionTime * 1000)) ms")
                    .font(.headline)
                Text("\(passedRounds)/\(totalRounds) rounds under \(Int(maxReactionTime * 1000))ms")
                    .font(.subheadline)
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
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
    }
    
    private var backgroundColor: Color {
        switch testState {
        case .waiting:
            return Color.blue.opacity(0.8)
        case .showingGreen:
            return Color.green
        case .tooEarly:
            return Color.red
        case .showingResult:
            return Color(.systemBackground)
        case .complete:
            return Color(.systemBackground)
        }
    }
    
    private var textColor: Color {
        switch testState {
        case .waiting, .showingGreen, .tooEarly:
            return .white
        case .showingResult, .complete:
            return .primary
        }
    }
    
    private func dotColor(for index: Int) -> Color {
        if index < reactionTimes.count {
            return reactionTimes[index] < maxReactionTime ? .green : .orange
        } else if index == currentRound {
            return .white
        }
        return .white.opacity(0.3)
    }
    
    private func handleTap() {
        switch testState {
        case .waiting:
            // Tapped too early
            tooEarlyCount += 1
            testState = .tooEarly
            HapticService.shared.error()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if tooEarlyCount >= 3 {
                    // Too many early taps, fail the test
                    testState = .complete
                } else {
                    startRound()
                }
            }
            
        case .showingGreen:
            // Calculate reaction time
            if let startTime = greenStartTime {
                let reactionTime = Date().timeIntervalSince(startTime)
                reactionTimes.append(reactionTime)
                testState = .showingResult(time: reactionTime)
                
                if reactionTime < maxReactionTime {
                    HapticService.shared.success()
                } else {
                    HapticService.shared.warning()
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    nextRound()
                }
            }
            
        case .tooEarly:
            break
            
        case .showingResult:
            break
            
        case .complete:
            break
        }
    }
    
    private func startRound() {
        testState = .waiting
        
        // Random delay between 1.5 and 4 seconds
        let delay = Double.random(in: 1.5...4.0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if case .waiting = testState {
                greenStartTime = Date()
                testState = .showingGreen
                HapticService.shared.mediumImpact()
            }
        }
    }
    
    private func nextRound() {
        currentRound += 1
        
        if currentRound >= totalRounds {
            testState = .complete
        } else {
            startRound()
        }
    }
}

enum ReactionTestState: Equatable {
    case waiting
    case showingGreen
    case tooEarly
    case showingResult(time: TimeInterval)
    case complete
}

#Preview {
    ReactionTestView { passed in
        print("Passed: \(passed)")
    }
}
