import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@available(iOS 15.0, macOS 12.0, *)
struct WriteView: View {
    @ObservedObject var viewModel: WriteViewModel
    @Binding var tabSelection: AppTab
    var isTestMode: Bool = false
    @EnvironmentObject private var environment: AppEnvironment
    @FocusState private var isFocused: Bool
    
    // State
    @State private var showReminderSheet: Bool = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var keyboardShowObserver: NSObjectProtocol?
    @State private var keyboardHideObserver: NSObjectProtocol?
    @State private var isCustomizing: Bool = false
    @State private var showAddPresetPicker: Bool = false
    @State private var selectedHours: Int = 0
    @State private var selectedMinutes: Int = 15
    @State private var pickerMode: AddPresetMode = .duration
    @State private var selectedTime: Date = Date()
    
    private enum AddPresetMode: String, CaseIterable {
        case duration = "◯分/時間後"
        case specificTime = "時刻指定"
    }
    
    // MARK: - Helper Views (Split for compiler performance and clarity)
    
    @ViewBuilder
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greetingText())
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.kotoPrimaryText)
            
            Text("思いついたことを書いてみよう")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.kotoSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private var cardArea: some View {
        mainCard
            .padding(.horizontal, 8)
    }
    
    @ViewBuilder
    private var mainCard: some View {
        ZStack(alignment: .topLeading) {
            // Card background
            RoundedRectangle(cornerRadius: KotoDesign.cardCornerRadius, style: .continuous)
                .fill(Color.kotoCardBackground)
                .shadow(
                    color: .black.opacity(KotoDesign.shadowOpacity),
                    radius: KotoDesign.shadowRadius,
                    x: 0,
                    y: 4
                )
            
            // Text input
            TextEditor(text: $viewModel.text)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.kotoPrimaryText)
                .padding(16)
                .focused($isFocused)
            
            // Placeholder
            if viewModel.text.isEmpty {
                Text("何を覚えておく？")
                    .font(.system(size: 17))
                    .foregroundColor(.kotoSecondaryText.opacity(0.5))
                    .padding(20)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 160)
    }
    
    @ViewBuilder
    private var reminderSheet: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if !isCustomizing {
                        // 通常モード: プリセット選択
                        reminderRailFloating
                            .padding(.top, 8)
                            .padding(.horizontal, 12)
                    }
                    
                    // カスタマイズセクション
                    customizeSection
                        .padding(.horizontal, 12)
                }
                .padding(.bottom, 24)
            }
            .background(Color.kotoBackground.ignoresSafeArea())
            .navigationTitle(isCustomizing ? "候補をカスタマイズ" : "リマインダー")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        isCustomizing = false
                        showAddPresetPicker = false
                        showReminderSheet = false
                    }
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
    
    @ViewBuilder
    private var reminderRailFloating: some View {
        VStack(spacing: 4) {
            Label("リマインダー", systemImage: "bell.badge.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.kotoReminder)
                .padding(.bottom, 8)
            
            ForEach(environment.presetStore.presets) { preset in
                presetRow(preset: preset)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.kotoCardBackground)
                .shadow(color: .black.opacity(0.15), radius: 12, x: -4, y: 0)
        )
    }
    
    @ViewBuilder
    private var customizeSection: some View {
        VStack(spacing: 12) {
            // カスタマイズ開始/終了ボタン
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isCustomizing.toggle()
                    if !isCustomizing {
                        showAddPresetPicker = false
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isCustomizing ? "checkmark.circle.fill" : "slider.horizontal.3")
                        .font(.system(size: 16))
                    Text(isCustomizing ? "完了" : "カスタマイズする")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(isCustomizing ? .kotoReminder : .kotoSecondaryText)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isCustomizing ? Color.kotoReminder.opacity(0.1) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isCustomizing ? Color.kotoReminder.opacity(0.3) : Color.kotoSecondaryText.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())
            
            // カスタマイズモード
            if isCustomizing {
                VStack(spacing: 16) {
                    // 編集可能なプリセット一覧
                    editablePresetsList
                    
                    // プリセット追加
                    addPresetSection
                    
                    // 特殊プリセットトグル
                    specialPresetsToggle
                    
                    // リセットボタン
                    resetToDefaultsButton
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
    }
    
    @ViewBuilder
    private var editablePresetsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("現在の候補", systemImage: "list.bullet")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.kotoSecondaryText)
            
            VStack(spacing: 0) {
                // 分数プリセット
                ForEach(Array(environment.presetStore.minutePresets.enumerated()), id: \.offset) { index, minutes in
                    presetRowView(
                        label: ReminderPreset.formatMinutesLabel(minutes),
                        onDelete: { environment.presetStore.removePreset(at: index) },
                        showDivider: index < environment.presetStore.minutePresets.count - 1 || !environment.presetStore.specificTimes.isEmpty
                    )
                }
                
                // 時刻指定プリセット
                ForEach(Array(environment.presetStore.specificTimes.enumerated()), id: \.offset) { index, timeMinutes in
                    let hour = timeMinutes / 60
                    let minute = timeMinutes % 60
                    let label = String(format: "%02d:%02d に通知", hour, minute)
                    presetRowView(
                        label: label,
                        onDelete: { environment.presetStore.removeSpecificTime(timeMinutes: timeMinutes) },
                        showDivider: index < environment.presetStore.specificTimes.count - 1
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.kotoCardBackground)
            )
        }
    }
    
    @ViewBuilder
    private func presetRowView(label: String, onDelete: @escaping () -> Void, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 16))
                    .foregroundColor(.kotoPrimaryText)
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.kotoDiscard)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if showDivider {
                Divider()
                    .padding(.leading, 16)
            }
        }
    }
    
    @ViewBuilder
    private var addPresetSection: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showAddPresetPicker.toggle()
                    if showAddPresetPicker {
                        selectedTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("新しい候補を追加")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.kotoReminder)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.kotoReminder.opacity(0.1))
                )
            }
            .buttonStyle(ScaleButtonStyle())
            
            if showAddPresetPicker {
                VStack(spacing: 12) {
                    // モード切り替えセグメント
                    Picker("モード", selection: $pickerMode) {
                        ForEach(AddPresetMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 20)
                    
                    if pickerMode == .duration {
                        // ◯分/時間後
                        HStack(spacing: 0) {
                            Picker("時間", selection: $selectedHours) {
                                ForEach(0..<25, id: \.self) { hour in
                                    Text("\(hour)時間").tag(hour)
                                }
                            }
                            #if os(iOS)
                            .pickerStyle(.wheel)
                            #endif
                            .frame(width: 110)
                            .clipped()
                            
                            Picker("分", selection: $selectedMinutes) {
                                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { minute in
                                    Text("\(minute)分").tag(minute)
                                }
                            }
                            #if os(iOS)
                            .pickerStyle(.wheel)
                            #endif
                            .frame(width: 90)
                            .clipped()
                        }
                        .frame(height: 120)
                    } else {
                        // 時刻指定
                        DatePicker(
                            "通知時刻",
                            selection: $selectedTime,
                            displayedComponents: .hourAndMinute
                        )
                        #if os(iOS)
                        .datePickerStyle(.wheel)
                        #else
                        .datePickerStyle(.stepperField)
                        #endif
                        .labelsHidden()
                        .frame(height: 120)
                    }
                    
                    // プレビュー
                    Text(addPresetPreviewText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.kotoReminder)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.kotoReminder.opacity(0.1))
                        )
                    
                    Button {
                        if pickerMode == .duration {
                            let totalMinutes = selectedHours * 60 + selectedMinutes
                            if totalMinutes > 0 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    environment.presetStore.addPreset(minutes: totalMinutes)
                                }
                            }
                        } else {
                            let calendar = Calendar.current
                            let hour = calendar.component(.hour, from: selectedTime)
                            let minute = calendar.component(.minute, from: selectedTime)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                environment.presetStore.addSpecificTime(hour: hour, minute: minute)
                            }
                        }
                        showAddPresetPicker = false
                        selectedHours = 0
                        selectedMinutes = 15
                    } label: {
                        Text("追加")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(Color.kotoReminder)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(pickerMode == .duration && selectedHours == 0 && selectedMinutes == 0)
                    .opacity(pickerMode == .duration && selectedHours == 0 && selectedMinutes == 0 ? 0.5 : 1.0)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.kotoCardBackground)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
    
    private var addPresetPreviewText: String {
        if pickerMode == .duration {
            let totalMinutes = selectedHours * 60 + selectedMinutes
            return ReminderPreset.formatMinutesLabel(totalMinutes)
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ja_JP")
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: selectedTime) + " に通知"
        }
    }
    
    @ViewBuilder
    private var specialPresetsToggle: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $environment.presetStore.includeSpecialPresets) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("「今夜」「明日朝」を含める")
                        .font(.system(size: 15))
                        .foregroundColor(.kotoPrimaryText)
                    Text("今夜 20:00・明日朝 9:00")
                        .font(.system(size: 12))
                        .foregroundColor(.kotoSecondaryText)
                }
            }
            .tint(.kotoReminder)
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.kotoCardBackground)
        )
    }
    
    @ViewBuilder
    private var resetToDefaultsButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                environment.presetStore.resetToDefaults()
            }
        } label: {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14))
                Text("デフォルトに戻す")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.kotoSecondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.kotoSecondaryText.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private func presetRow(preset: ReminderPreset) -> some View {
        return Button {
            performSaveWithReminder(preset: preset)
        } label: {
            Text(preset.label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.kotoPrimaryText)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .frame(minWidth: 80)
                .background(
                    Capsule()
                        .fill(Color.kotoReminder.opacity(0.08))
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                Button(action: performDiscard) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                        Text("破棄")
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .layoutPriority(1)
                    }
                    .foregroundColor(.kotoDiscard)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color.kotoDiscard.opacity(0.1))
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .fixedSize()
                
                Button(action: performSave) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 16, weight: .bold))
                        Text("ただ保存")
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .layoutPriority(1)
                    }
                    .foregroundColor(.kotoSecondaryText)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color.kotoCardBackground)
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.kotoSecondaryText.opacity(0.15), lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .fixedSize()
                
                Button(action: { showReminderSheet = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.and.waves.left.and.right.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("保存＋通知")
                            .font(.system(size: 16, weight: .heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .layoutPriority(1)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.kotoReminder,
                                        Color.kotoReminder.opacity(0.92),
                                        Color.kotoReminder.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .frame(minWidth: 150, minHeight: 54)
                    .shadow(color: Color.kotoReminder.opacity(0.35), radius: 10, x: 0, y: 6)
                }
                .buttonStyle(ScaleButtonStyle())
                .fixedSize()
            }
            .padding(.horizontal, KotoDesign.horizontalPadding)
            .padding(.vertical, 4)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.kotoBackground
                    .ignoresSafeArea()
                    .onTapGesture { isFocused = false }
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                        .padding(.top, 16)
                        .padding(.horizontal, KotoDesign.horizontalPadding)

                    Spacer()
                    
                    // Main card area
                    cardArea
                    
                    // Action buttons
                    actionButtons
                        .padding(.top, 20)
                    
                    Spacer()
                    
                    // Inline tab selector（ミニタブバー）
                    inlineTabBar
                        .padding(.bottom, 20)
                }
                .padding(.bottom, bottomPadding(geometry))
                
                // Snackbar overlay
                if let message = viewModel.feedbackMessage {
                    VStack {
                        Spacer()
                        snackbar(message: message)
                            .padding(.bottom, 100)
                            .allowsHitTesting(false)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.feedbackMessage)
                }
            }
            // Reminder rail floats above keyboard
            .overlay(alignment: .bottomTrailing) {
                // overlay removed; sheet is used instead
            }
            .background(
                TwoFingerTapView { performUndo() }
            )
        }
        .sheet(isPresented: $showReminderSheet) {
            reminderSheet
        }
        .onAppear {
            // 1回だけフォーカス（再描画時の再フォーカス防止）
            if !isFocused {
                // 次のrun loopでレイアウト確定を待つ（iOS 15互換）
                DispatchQueue.main.async {
                    isFocused = true
                }
            }
            #if canImport(UIKit)
            UITextView.appearance().backgroundColor = .clear
            #endif
            startKeyboardObservers()
        }
        .onDisappear {
            stopKeyboardObservers()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: showReminderSheet)
    }

    // MARK: - Keyboard handling
    private func bottomPadding(_ geometry: GeometryProxy) -> CGFloat {
        #if canImport(UIKit)
        let safe = geometry.safeAreaInsets.bottom
        let overlap = max(keyboardHeight - safe, 0)
        let extraGap: CGFloat = keyboardHeight > 0 ? 60 : 12
        return overlap + extraGap
        #else
        return 12
        #endif
    }
    
    private func startKeyboardObservers() {
        #if canImport(UIKit)
        keyboardShowObserver = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { note in
            if let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.easeOut(duration: 0.2)) {
                    keyboardHeight = frame.height
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardDidShowNotification, object: nil, queue: .main) { _ in
            LaunchTimer.logKeyboardReady()
        }
        keyboardHideObserver = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            withAnimation(.easeOut(duration: 0.2)) {
                keyboardHeight = 0
            }
        }
        #endif
    }
    
    private func stopKeyboardObservers() {
        #if canImport(UIKit)
        if let show = keyboardShowObserver {
            NotificationCenter.default.removeObserver(show)
            keyboardShowObserver = nil
        }
        if let hide = keyboardHideObserver {
            NotificationCenter.default.removeObserver(hide)
            keyboardHideObserver = nil
        }
        #endif
    }


    
    // MARK: - Inline Tab Bar
    private var inlineTabBar: some View {
        let tabs: [AppTab] = [.write, .list, .settings]
        
        return HStack(spacing: 14) {
            ForEach(tabs, id: \.self) { tab in
                Button {
                    tabSelection = tab
                    triggerHaptic(.light)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: icon(for: tab))
                            .font(.system(size: 15, weight: .semibold))
                        Text(label(for: tab))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(tabSelection == tab ? .white : .kotoPrimaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(tabSelection == tab ? Color.kotoAccent : Color.kotoCardBackground)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, 16)
    }
    
    private func snackbar(message: String) -> some View {
        Text(message)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.85))
            )
    }
    
    // MARK: - Actions
    
    private func performSave() {
        guard !viewModel.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        triggerHaptic(.medium)
        isFocused = false
        Task {
            await viewModel.saveWithoutReminder()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
    }
    
    private func performDiscard() {
        guard !viewModel.text.isEmpty else { return }
        
        triggerHaptic(.light)
        viewModel.discardCurrent(reminder: nil)
    }
    
    private func performSaveWithReminder(preset: ReminderPreset) {
        guard !viewModel.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        triggerHaptic(.heavy)
        isFocused = false
        showReminderSheet = false
        let when = preset.resolve(from: Date())
        Task {
            await viewModel.save(reminder: when, label: preset.label)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
    }
    
    private func performUndo() {
        triggerHaptic(.medium)
        Task {
            await viewModel.undoLastSave { memo in
                if let reminder = memo.reminderAt {
                    try? await environment.notificationService.schedule(
                        id: memo.id,
                        when: reminder,
                        title: "すぐメモ リマインダー",
                        body: memo.text
                    )
                }
            }
        }
    }
    
    private func triggerHaptic(_ style: HapticStyle) {
        #if canImport(UIKit)
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .light: generator = UIImpactFeedbackGenerator(style: .light)
        case .medium: generator = UIImpactFeedbackGenerator(style: .medium)
        case .heavy: generator = UIImpactFeedbackGenerator(style: .heavy)
        }
        generator.impactOccurred()
        #endif
    }
    
    private enum HapticStyle {
        case light, medium, heavy
    }
    
    // MARK: - Helpers

    private func greetingText() -> String {
        _ = Calendar.current.component(.hour, from: Date())
        return "すぐメモ！"
    }
    
    private func icon(for tab: AppTab) -> String {
        switch tab {
        case .write: return tabSelection == .write ? "square.and.pencil.circle.fill" : "square.and.pencil"
        case .list: return tabSelection == .list ? "list.bullet.rectangle.fill" : "list.bullet.rectangle"
        case .settings: return tabSelection == .settings ? "gearshape.fill" : "gearshape"
        }
    }
    
    private func label(for tab: AppTab) -> String {
        switch tab {
        case .write: return "書く"
        case .list: return "見る"
        case .settings: return "設定"
        }
    }
}
