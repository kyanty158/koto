import SwiftUI

@available(iOS 15.0, macOS 12.0, *)
struct MemoListView: View {
    @ObservedObject var viewModel: MemoListViewModel
    @EnvironmentObject private var environment: AppEnvironment
    @Binding var selectedMemo: MemoModel?
    
    @State private var showDeleteConfirmation: Bool = false
    @State private var searchText: String = ""
    
    init(viewModel: MemoListViewModel, selectedMemo: Binding<MemoModel?>) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _selectedMemo = selectedMemo
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.kotoBackground
                    .ignoresSafeArea()
                
                if viewModel.upcoming.isEmpty && viewModel.history.isEmpty {
                    emptyStateView
                } else {
                    memoListContent
                }
            }
            .navigationTitle("メモ")
            .navigationTitle("メモ")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    toolbarMenu
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    toolbarMenu
                }
                #endif
            }
            .searchable(
                text: $searchText,
                placement: .automatic,
                prompt: "メモを検索..."
            )
            .onChange(of: searchText) { newValue in
                viewModel.searchTerm = newValue
            }
        }
        .sheet(item: $selectedMemo) { memo in
            EditView(
                memo: memo,
                onSave: { updated in
                    _ = try environment.memoRepository.updateMemo(updated)
                    if let reminder = updated.reminderAt {
                        try? await environment.notificationService.schedule(
                            id: updated.id,
                            when: reminder,
                            title: "すぐメモ リマインダー",
                            body: updated.text
                        )
                    } else {
                        await environment.notificationService.cancel(id: updated.id)
                    }
                },
                onDelete: {
                    try environment.memoRepository.delete(ids: [memo.id])
                    await environment.notificationService.cancel(id: memo.id)
                }
            )
        }
        .confirmationDialog(
            "選択したメモを削除しますか？",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                try? viewModel.deleteSelected()
            }
            Button("キャンセル", role: .cancel) {}
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "note.text")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(.kotoSecondaryText.opacity(0.4))
            
            VStack(spacing: 8) {
                Text("メモがありません")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.kotoPrimaryText)
                
                Text("「書く」タブでメモを作成しましょう")
                    .font(.system(size: 15))
                    .foregroundColor(.kotoSecondaryText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - List Content
    
    private var memoListContent: some View {
        ScrollView {
            LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                // Upcoming reminders

                if !viewModel.upcoming.isEmpty {
                    Section {
                        ForEach(viewModel.upcoming) { memo in
                            upcomingMemoCard(memo: memo)
                        }
                    } header: {
                        sectionHeader(title: "これからのリマインド", icon: "bell.badge.fill", color: .kotoReminder)
                    }
                }
                
                // History
                if !viewModel.history.isEmpty {
                    Section {
                        ForEach(viewModel.history) { memo in
                            memoRow(memo: memo)
                        }
                    } header: {
                        sectionHeader(title: "履歴", icon: "clock.fill", color: .kotoSecondaryText)
                    }
                }
            }
            .padding(.horizontal, KotoDesign.horizontalPadding)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Section Header
    
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.kotoPrimaryText)
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(Color.kotoBackground)
    }
    
    // MARK: - Upcoming Memo Card
    
    private func upcomingMemoCard(memo: MemoModel) -> some View {
        Button {
            selectedMemo = memo
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if let reminder = memo.reminderAt {
                        Label(formatRelativeTime(reminder), systemImage: "bell.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.kotoReminder)
                            )
                    }
                    
                    Spacer()
                    
                    if memo.isDone {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.kotoSave)
                    }
                }
                
                Text(memo.text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.kotoPrimaryText)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                // Tags
                if !memo.inlineTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(memo.inlineTags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.kotoAccent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color.kotoAccent.opacity(0.12))
                                    )
                            }
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: KotoDesign.smallCornerRadius, style: .continuous)
                    .fill(Color.kotoCardBackground)
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: KotoDesign.smallCornerRadius, style: .continuous)
                    .stroke(Color.kotoReminder.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .contextMenu {
            memoContextMenu(memo: memo)
        }
    }
    
    // MARK: - Regular Memo Row
    
    private func memoRow(memo: MemoModel) -> some View {
        Button {
            selectedMemo = memo
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(memo.text)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.kotoPrimaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 8) {
                        Text(formatDate(memo.createdAt))
                            .font(.system(size: 12))
                            .foregroundColor(.kotoSecondaryText)
                        
                        if let reminder = memo.reminderAt, memo.isReminderActive {
                            Label(formatTime(reminder), systemImage: "bell")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.kotoReminder)
                        }
                    }
                }
                
                Spacer()
                
                if memo.isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.kotoSave)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: KotoDesign.smallCornerRadius, style: .continuous)
                    .fill(Color.kotoCardBackground)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .contextMenu {
            memoContextMenu(memo: memo)
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func memoContextMenu(memo: MemoModel) -> some View {
        Button {
            viewModel.markDone(memo, done: !memo.isDone)
        } label: {
            Label(
                memo.isDone ? "未完了にする" : "完了にする",
                systemImage: memo.isDone ? "circle" : "checkmark.circle"
            )
        }
        
        if memo.reminderAt != nil {
            Button {
                var updated = memo
                updated.reminderAt = nil
                _ = try? environment.memoRepository.updateMemo(updated)
                Task { await environment.notificationService.cancel(id: memo.id) }
            } label: {
                Label("リマインダーを解除", systemImage: "bell.slash")
            }
        }
        
        Divider()
        
        Button(role: .destructive) {
            try? environment.memoRepository.delete(ids: [memo.id])
            Task { await environment.notificationService.cancel(id: memo.id) }
        } label: {
            Label("削除", systemImage: "trash")
        }
    }
    
    // MARK: - Toolbar Menu
    
    private var toolbarMenu: some View {
        Menu {
            if viewModel.selectionMode {
                Button {
                    let allIds = viewModel.upcoming.map(\.id) + viewModel.history.map(\.id)
                    if Set(allIds) == viewModel.selectedIDs {
                        viewModel.selectedIDs.removeAll()
                    } else {
                        viewModel.selectedIDs = Set(allIds)
                    }
                } label: {
                    Label("すべて選択", systemImage: "checkmark.circle")
                }
                
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("削除", systemImage: "trash")
                }
                .disabled(viewModel.selectedIDs.isEmpty)
                
                Divider()
                
                Button {
                    viewModel.selectionMode = false
                    viewModel.selectedIDs.removeAll()
                } label: {
                    Label("選択を解除", systemImage: "xmark.circle")
                }
            } else {
                Button {
                    viewModel.selectionMode = true
                } label: {
                    Label("選択", systemImage: "checkmark.circle")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.kotoAccent)
                .accessibilityIdentifier("memoListToolbarMenu")
        }
    }
    
    // MARK: - Formatters
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "今日 HH:mm"
        } else if Calendar.current.isDateInYesterday(date) {
            formatter.dateFormat = "'昨日' HH:mm"
        } else {
            formatter.dateFormat = "M/d HH:mm"
        }
        
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let now = Date()
        let interval = date.timeIntervalSince(now)
        
        if interval < 0 {
            return "期限切れ"
        }
        
        let minutes = Int(interval / 60)
        let hours = minutes / 60
        
        if minutes < 60 {
            return "\(minutes)分後"
        } else if hours < 24 {
            return "\(hours)時間後"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ja_JP")
            formatter.dateFormat = "M/d HH:mm"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
