import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@available(iOS 15.0, macOS 12.0, *)
public struct ContentView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @ObservedObject var writeViewModel: WriteViewModel
    @ObservedObject var listViewModel: MemoListViewModel
    
    @State private var tabSelection: AppTab = .write
    @State private var editSheetMemo: MemoModel?
    @State private var hasInitializedServices = false
    
    public init(writeViewModel: WriteViewModel, listViewModel: MemoListViewModel) {
        self.writeViewModel = writeViewModel
        self.listViewModel = listViewModel
    }
    
    private var isTestMode: Bool {
        #if DEBUG
        return true
        #else
        return ProcessInfo.processInfo.environment["KOTO_TEST_MODE"] == "1"
        #endif
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $tabSelection) {
                WriteView(viewModel: writeViewModel,
                          tabSelection: $tabSelection,
                          isTestMode: isTestMode)
                    .tabItem {
                        Label("書く", systemImage: tabSelection == .write ? "square.and.pencil.circle.fill" : "square.and.pencil")
                    }
                    .tag(AppTab.write)
                
                MemoListView(
                    viewModel: listViewModel,
                    selectedMemo: $editSheetMemo
                )
                .tabItem {
                    Label("見る", systemImage: tabSelection == .list ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                }
                .tag(AppTab.list)
                
                SettingsView(isTestMode: isTestMode)
                    .environmentObject(environment)
                    .tabItem {
                        Label("設定", systemImage: tabSelection == .settings ? "gearshape.fill" : "gearshape")
                    }
                    .tag(AppTab.settings)
            }
        }
        .background(Color.kotoBackground.ignoresSafeArea())
        .tint(.kotoAccent)
        .task {
            // 1回だけ実行ガード
            guard !hasInitializedServices else { return }
            hasInitializedServices = true
            
            // キーボード表示を優先するため遅延
            do {
                try await Task.sleep(nanoseconds: 500_000_000)
            } catch {
                return  // キャンセル時は終了
            }
            if Task.isCancelled { return }
            
            await environment.notificationService.configure()
        }
        .onReceive(environment.$pendingEditMemo) { memo in
            guard let memo else { return }
            tabSelection = .list
            editSheetMemo = memo
        }
        .onChange(of: editSheetMemo) { memo in
            if memo == nil {
                environment.pendingEditMemo = nil
            }
        }
    }
}

// MARK: - Settings View

@available(iOS 15.0, macOS 12.0, *)
struct SettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    var isTestMode: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.kotoBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Notifications section
                        notificationSection
                        
                        // Reminder presets section
                        reminderPresetsSection
                        
                        // Data section
                        dataSection
                        
                        // About section
                        aboutSection
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, KotoDesign.horizontalPadding)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("設定")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }
    
    // MARK: - Notification Section
    
    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("通知", systemImage: "bell")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.kotoSecondaryText)
            
            Button {
                #if canImport(UIKit)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                #endif
            } label: {
                HStack {
                    Text("通知設定を開く")
                    .font(.system(size: 16))
                    .foregroundColor(.kotoPrimaryText)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 14))
                        .foregroundColor(.kotoSecondaryText)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: KotoDesign.smallCornerRadius, style: .continuous)
                        .fill(Color.kotoCardBackground)
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
    
    // MARK: - Reminder Presets Section
    
    private var reminderPresetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("リマインダー候補", systemImage: "clock.badge")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.kotoSecondaryText)
            
            NavigationLink {
                ReminderPresetSettingsView()
                    .environmentObject(environment)
            } label: {
                HStack {
                    Text("通知時間をカスタマイズ")
                        .font(.system(size: 16))
                        .foregroundColor(.kotoPrimaryText)
                    
                    Spacer()
                    
                    Text("\(environment.presetStore.minutePresets.count)個")
                        .font(.system(size: 14))
                        .foregroundColor(.kotoSecondaryText)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.kotoSecondaryText)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: KotoDesign.smallCornerRadius, style: .continuous)
                        .fill(Color.kotoCardBackground)
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
    
    // MARK: - Data Section
    
    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("データ", systemImage: "externaldrive")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.kotoSecondaryText)
            
            VStack(spacing: 0) {
                Button {
                    // Export functionality - to be implemented
                } label: {
                    HStack {
                        Text("メモをエクスポート")
                            .font(.system(size: 16))
                            .foregroundColor(.kotoSecondaryText)
                        
                        Spacer()
                        
                        Text("近日公開")
                            .font(.system(size: 12))
                            .foregroundColor(.kotoSecondaryText.opacity(0.6))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.kotoSecondaryText.opacity(0.1))
                            )
                    }
                    .padding(16)
                }
                .disabled(true)
            }
            .background(
                RoundedRectangle(cornerRadius: KotoDesign.smallCornerRadius, style: .continuous)
                .fill(Color.kotoCardBackground)
            )
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("アプリについて", systemImage: "info.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.kotoSecondaryText)
            
            VStack(spacing: 0) {
                HStack {
                    Text("バージョン")
                        .font(.system(size: 16))
                        .foregroundColor(.kotoPrimaryText)
                    Spacer()
                    Text("1.0.0")
                        .font(.system(size: 16))
                        .foregroundColor(.kotoSecondaryText)
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: KotoDesign.smallCornerRadius, style: .continuous)
                    .fill(Color.kotoCardBackground)
            )
            
            // Tagline
            Text("書くは一瞬、思い出すは一目")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.kotoSecondaryText.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
        }
    }
}

