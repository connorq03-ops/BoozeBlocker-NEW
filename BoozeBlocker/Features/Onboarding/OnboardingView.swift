import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Welcome to Booze Blocker",
            subtitle: "Protect yourself from drunk texting, calling, and app usage",
            imageName: "shield.checkmark.fill",
            imageColor: .blue
        ),
        OnboardingPage(
            title: "Block Apps",
            subtitle: "Choose which apps to block while you're drinking - social media, dating apps, messaging, and more",
            imageName: "app.badge.fill",
            imageColor: .purple
        ),
        OnboardingPage(
            title: "Block Contacts",
            subtitle: "Select contacts you shouldn't reach out to - exes, bosses, or anyone else",
            imageName: "person.crop.circle.badge.xmark",
            imageColor: .red
        ),
        OnboardingPage(
            title: "Sobriety Tests",
            subtitle: "Want to deactivate early? You'll need to pass a test to prove you're thinking clearly",
            imageName: "brain.head.profile",
            imageColor: .orange
        ),
        OnboardingPage(
            title: "Emergency Contacts",
            subtitle: "Designate contacts that are always accessible, no matter what",
            imageName: "staroflife.fill",
            imageColor: .green
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)
            
            // Page indicator
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut, value: currentPage)
                }
            }
            .padding(.bottom, 20)
            
            // Navigation buttons
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if currentPage < pages.count - 1 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .fontWeight(.semibold)
                } else {
                    Button("Get Started") {
                        completeOnboarding()
                    }
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    private func completeOnboarding() {
        var settings = PersistenceService.shared.loadUserSettings()
        settings.hasCompletedOnboarding = true
        PersistenceService.shared.saveUserSettings(settings)
        
        withAnimation {
            hasCompletedOnboarding = true
        }
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let imageName: String
    let imageColor: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(page.imageColor.opacity(0.15))
                    .frame(width: 150, height: 150)
                
                Image(systemName: page.imageName)
                    .font(.system(size: 60))
                    .foregroundColor(page.imageColor)
            }
            
            // Text
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(page.subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
