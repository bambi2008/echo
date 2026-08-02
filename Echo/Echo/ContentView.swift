import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $selectedTab) {
                EchoLayerView()
                    .tabItem {
                        Image(systemName: selectedTab == 0 ? "person.2.fill" : "person.2")
                    }.tag(0)
                
                PeopleLibraryView()
                    .tabItem {
                        Image(systemName: selectedTab == 1 ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                    }.tag(1)
                
                SettingsView()
                    .tabItem {
                        Image(systemName: selectedTab == 2 ? "gearshape.fill" : "gearshape")
                    }.tag(2)
            }
            .tint(.white)
        }
        .environmentObject(StoreManager.shared)
        .environmentObject(AuthManager.shared)
        .environmentObject(TrialManager.shared)
        .fullScreenCover(isPresented: .constant(!hasCompletedOnboarding)) {
            SimpleOnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }
}

struct SimpleOnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var step = 0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                if step == 0 {
                    // Welcome
                    VStack(spacing: 16) {
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "wave.3.right")
                                    .font(.system(size: 40, weight: .light))
                                    .foregroundStyle(.white)
                            )
                        Text("Echo")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                        Text("不再错过重要的人")
                            .font(.system(size: 17))
                            .foregroundStyle(.secondary)
                    }
                } else if step == 1 {
                    // Import contacts
                    VStack(spacing: 16) {
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.white)
                            )
                        Text("导入通讯录")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Echo 会读取你的通讯录来帮你管理关系。\n所有数据只存在你的设备上。")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    // Done
                    VStack(spacing: 16) {
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 40, weight: .light))
                                    .foregroundStyle(.white)
                            )
                        Text("准备就绪")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                        Text("开始管理你的人际关系吧")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    if step < 2 {
                        step += 1
                    } else {
                        hasCompletedOnboarding = true
                    }
                } label: {
                    Text(step == 2 ? "开始使用" : "继续")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
                
                // Dots indicator
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(i == step ? Color.white : Color.white.opacity(0.2))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 32)
            }
        }
    }
}
