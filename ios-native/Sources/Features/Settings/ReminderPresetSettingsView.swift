import SwiftUI

/// リマインダープリセット設定画面
@available(iOS 15.0, macOS 12.0, *)
struct ReminderPresetSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var showAddSheet = false
    
    // ホイールピッカー用の状態
    @State private var selectedHours: Int = 0
    @State private var selectedMinutes: Int = 15
    @State private var pickerMode: PickerMode = .duration
    @State private var selectedTime: Date = Date()
    
    enum PickerMode: String, CaseIterable {
        case duration = "◯分/時間後"
        case specificTime = "時刻指定"
    }
    
    var body: some View {
        ZStack {
            Color.kotoBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // 説明テキスト
                    descriptionSection
                    
                    // プリセット一覧
                    presetsSection
                    
                    // 追加ボタン
                    addButton
                    
                    // 特殊プリセットトグル
                    specialPresetsSection
                    
                    // デフォルトに戻すボタン
                    resetButton
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, KotoDesign.horizontalPadding)
                .padding(.top, 16)
            }
        }
        .navigationTitle("リマインダー候補")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .sheet(isPresented: $showAddSheet) {
            addPresetSheet
        }
    }
    
    // MARK: - Description Section
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("「保存＋通知」で表示されるリマインダーの候補をカスタマイズできます。")
                .font(.system(size: 14))
                .foregroundColor(.kotoSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Presets Section
    
    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("プリセット一覧", systemImage: "clock")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.kotoSecondaryText)
            
            VStack(spacing: 0) {
                ForEach(Array(environment.presetStore.minutePresets.enumerated()), id: \.offset) { index, minutes in
                    presetRow(minutes: minutes, index: index)
                    
                    if index < environment.presetStore.minutePresets.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: KotoDesign.smallCornerRadius, style: .continuous)
                    .fill(Color.kotoCardBackground)
            )
        }
    }
    
    private func presetRow(minutes: Int, index: Int) -> some View {
        HStack {
            Text(ReminderPreset.formatMinutesLabel(minutes))
                .font(.system(size: 16))
                .foregroundColor(.kotoPrimaryText)
            
            Spacer()
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    environment.presetStore.removePreset(at: index)
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.kotoDiscard)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(16)
    }
    
    // MARK: - Add Button
    
    private var addButton: some View {
        Button {
            // リセット
            selectedHours = 0
            selectedMinutes = 15
            pickerMode = .duration
            selectedTime = Date().addingTimeInterval(3600) // 1時間後
            showAddSheet = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                Text("新しいプリセットを追加")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.kotoReminder)
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: KotoDesign.smallCornerRadius, style: .continuous)
                    .fill(Color.kotoReminder.opacity(0.1))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Special Presets Section
    
    private var specialPresetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("特殊プリセット", systemImage: "moon.stars")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.kotoSecondaryText)
            
            VStack(spacing: 0) {
                Toggle(isOn: $environment.presetStore.includeSpecialPresets) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("「今夜」「明日朝」を含める")
                            .font(.system(size: 16))
                            .foregroundColor(.kotoPrimaryText)
                        Text("今夜 20:00・明日朝 9:00")
                            .font(.system(size: 13))
                            .foregroundColor(.kotoSecondaryText)
                    }
                }
                .tint(.kotoReminder)
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: KotoDesign.smallCornerRadius, style: .continuous)
                    .fill(Color.kotoCardBackground)
            )
        }
    }
    
    // MARK: - Reset Button
    
    private var resetButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                environment.presetStore.resetToDefaults()
            }
        } label: {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16))
                Text("デフォルトに戻す")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.kotoSecondaryText)
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: KotoDesign.smallCornerRadius, style: .continuous)
                    .stroke(Color.kotoSecondaryText.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Add Preset Sheet (Wheel Picker)
    
    private var addPresetSheet: some View {
        NavigationView {
            ZStack {
                Color.kotoBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // モード切り替えセグメント
                    Picker("モード", selection: $pickerMode) {
                        ForEach(PickerMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    if pickerMode == .duration {
                        durationPicker
                    } else {
                        specificTimePicker
                    }
                    
                    // プレビュー
                    previewLabel
                    
                    Spacer()
                    
                    // 追加ボタン
                    addPresetButton
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                }
            }
            .navigationTitle("プリセットを追加")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        showAddSheet = false
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        showAddSheet = false
                    }
                }
                #endif
            }
        }
    }
    
    // MARK: - Duration Picker (時間 + 分)
    
    private var durationPicker: some View {
        HStack(spacing: 0) {
            // 時間ピッカー
            Picker("時間", selection: $selectedHours) {
                ForEach(0..<25, id: \.self) { hour in
                    Text("\(hour)時間").tag(hour)
                }
            }
            // .wheel style is generic but works best on iOS. macOS will render as popup or list
            #if os(iOS)
            .pickerStyle(.wheel)
            #endif
            .frame(width: 120)
            .clipped()
            
            // 分ピッカー
            Picker("分", selection: $selectedMinutes) {
                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { minute in
                    Text("\(minute)分").tag(minute)
                }
            }
            #if os(iOS)
            .pickerStyle(.wheel)
            #endif
            .frame(width: 100)
            .clipped()
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Specific Time Picker
    
    private var specificTimePicker: some View {
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
        .padding(.horizontal, 16)
    }
    
    // MARK: - Preview Label
    
    private var previewLabel: some View {
        VStack(spacing: 8) {
            Text("追加されるプリセット")
                .font(.system(size: 13))
                .foregroundColor(.kotoSecondaryText)
            
            Text(previewText)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.kotoReminder)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.kotoReminder.opacity(0.1))
                )
        }
    }
    
    private var previewText: String {
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
    
    // MARK: - Add Preset Button
    
    private var addPresetButton: some View {
        Button {
            if pickerMode == .duration {
                let totalMinutes = selectedHours * 60 + selectedMinutes
                if totalMinutes > 0 {
                    environment.presetStore.addPreset(minutes: totalMinutes)
                }
            } else {
                // 時刻指定の場合は、時刻から分数に変換して保存
                let calendar = Calendar.current
                let hour = calendar.component(.hour, from: selectedTime)
                let minute = calendar.component(.minute, from: selectedTime)
                // 特定時刻は負の値で保存（特殊処理）
                environment.presetStore.addSpecificTime(hour: hour, minute: minute)
            }
            showAddSheet = false
        } label: {
            Text("このプリセットを追加")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.kotoReminder, Color.kotoReminder.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(pickerMode == .duration && selectedHours == 0 && selectedMinutes == 0)
        .opacity(pickerMode == .duration && selectedHours == 0 && selectedMinutes == 0 ? 0.5 : 1.0)
    }
}
