import SwiftUI

@available(iOS 15.0, macOS 12.0, *)
struct EditView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var memo: MemoModel
    @State private var reminderEnabled: Bool
    @State private var reminderDate: Date
    @State private var showDeleteConfirmation: Bool = false
    @State private var isSaving: Bool = false
    
    var onSave: (MemoModel) async throws -> Void
    var onDelete: () async throws -> Void
    
    init(memo: MemoModel,
         onSave: @escaping (MemoModel) async throws -> Void,
         onDelete: @escaping () async throws -> Void) {
        _memo = State(initialValue: memo)
        _reminderEnabled = State(initialValue: memo.reminderAt != nil)
        _reminderDate = State(initialValue: memo.reminderAt ?? Date().addingTimeInterval(3600))
        self.onSave = onSave
        self.onDelete = onDelete
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.kotoBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Text editor section
                        textEditorSection
                        
                        // Status section
                        statusSection
                        
                        // Reminder section
                        reminderSection
                        
                        // Quick reminder presets
                        if reminderEnabled {
                            quickReminderPresets
                        }
                        
                        // Meta info
                        metaInfoSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, KotoDesign.horizontalPadding)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("編集")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundColor(.kotoSecondaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await save()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("保存")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.kotoAccent)
                    .disabled(isSaving || memo.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await save()
                        }
                    }
                    .disabled(isSaving || memo.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                #endif
            }
            .safeAreaInset(edge: .bottom) {
                deleteButton
            }
        }
        .confirmationDialog(
            "このメモを削除しますか？",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                Task {
                    try? await onDelete()
                    dismiss()
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作は取り消せません")
        }
    }
    
    // MARK: - Text Editor Section
    
    private var textEditorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("メモ", systemImage: "text.alignleft")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.kotoSecondaryText)
            
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: KotoDesign.smallCornerRadius, style: .continuous)
                    .fill(Color.kotoCardBackground)
                
                TextEditor(text: $memo.text)
                    .font(.system(size: 16))
                    .foregroundColor(.kotoPrimaryText)
                    .padding(12)
                    .frame(minHeight: 150)
                    .onAppear {
                        #if canImport(UIKit)
                        UITextView.appearance().backgroundColor = .clear
                        #endif
                    }
                
                if memo.text.isEmpty {
                    Text("メモを入力...")
                        .font(.system(size: 16))
                        .foregroundColor(.kotoSecondaryText.opacity(0.5))
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("ステータス", systemImage: "flag")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.kotoSecondaryText)
            
            HStack {
                Button {
                    memo.isDone.toggle()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: memo.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundColor(memo.isDone ? .kotoSave : .kotoSecondaryText)
                        
                        Text(memo.isDone ? "完了" : "未完了")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.kotoPrimaryText)
                        
                        Spacer()
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
    }
    
    // MARK: - Reminder Section
    
    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("リマインダー", systemImage: "bell")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.kotoSecondaryText)
            
            VStack(spacing: 0) {
                // Toggle
                HStack {
                    Text("通知を設定")
                        .font(.system(size: 16))
                        .foregroundColor(.kotoPrimaryText)
                    
                    Spacer()
                    
                    Toggle("", isOn: $reminderEnabled)
                        .labelsHidden()
                        .tint(.kotoReminder)
                }
                .padding(16)
                
                if reminderEnabled {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Date picker
                    DatePicker(
                        "通知日時",
                        selection: $reminderDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .padding(16)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: KotoDesign.smallCornerRadius, style: .continuous)
                    .fill(Color.kotoCardBackground)
            )
        }
    }
    
    // MARK: - Quick Reminder Presets
    
    private var quickReminderPresets: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("クイック設定")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.kotoSecondaryText)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickPresets, id: \.label) { preset in
                        Button {
                            reminderDate = preset.resolve(from: Date())
                        } label: {
                            Text(preset.label)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.kotoPrimaryText)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.kotoReminder.opacity(0.12))
                                )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
    }
    
    private var quickPresets: [ReminderPreset] {
        [
            ReminderPreset(label: "10分後", kind: .minutes(10)),
            ReminderPreset(label: "1時間後", kind: .minutes(60)),
            ReminderPreset(label: "3時間後", kind: .minutes(180)),
            ReminderPreset(label: "今夜", kind: .tonight),
            ReminderPreset(label: "明日朝", kind: .tomorrowMorning)
        ]
    }
    
    // MARK: - Meta Info Section
    
    private var metaInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("情報", systemImage: "info.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.kotoSecondaryText)
            
            VStack(spacing: 0) {
                infoRow(label: "作成日時", value: formatFullDate(memo.createdAt))
                Divider().padding(.horizontal, 16)
                infoRow(label: "更新日時", value: formatFullDate(memo.updatedAt))
                
                if !memo.inlineTags.isEmpty {
                    Divider().padding(.horizontal, 16)
                    HStack {
                        Text("タグ")
                            .font(.system(size: 14))
                            .foregroundColor(.kotoSecondaryText)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            ForEach(memo.inlineTags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.kotoAccent)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: KotoDesign.smallCornerRadius, style: .continuous)
                    .fill(Color.kotoCardBackground)
            )
        }
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.kotoSecondaryText)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.kotoPrimaryText)
        }
        .padding(16)
    }
    
    // MARK: - Delete Button
    
    private var deleteButton: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("メモを削除")
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.kotoDiscard)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: KotoDesign.smallCornerRadius, style: .continuous)
                    .fill(Color.kotoDiscard.opacity(0.1))
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, KotoDesign.horizontalPadding)
        .padding(.bottom, 16)
        .background(Color.kotoBackground)
    }
    
    // MARK: - Actions
    
    private func save() async {
        isSaving = true
        defer { isSaving = false }
        
        memo.updatedAt = Date()
        memo.inlineTags = InlineTagExtractor.extract(from: memo.text)
        memo.reminderAt = reminderEnabled ? reminderDate : nil
        
        do {
            try await onSave(memo)
            dismiss()
        } catch {
            // Handle error - could show an alert
        }
    }
    
    // MARK: - Formatters
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/M/d HH:mm"
        return formatter.string(from: date)
    }
}
