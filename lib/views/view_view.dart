import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:koto/main.dart';
import 'package:koto/models/memo.dart';
import 'package:koto/services/subscription_service.dart';
import 'package:koto/services/notification_service.dart';
import 'package:koto/widgets/reminder_badge.dart';
import 'package:koto/views/edit_view.dart';
import 'package:koto/views/paywall_view.dart';
import 'package:koto/widgets/ad_banner.dart';

/// 保存されたメモを一覧表示する画面
class ViewView extends ConsumerStatefulWidget {
  const ViewView({super.key});

  @override
  ConsumerState<ViewView> createState() => _ViewViewState();
}

class _ViewViewState extends ConsumerState<ViewView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  final Set<int> _doneOverlay = <int>{};
  // Multi-select state
  bool _selectionMode = false;
  final Set<int> _selected = <int>{};
  // Track currently visible memo ids for Select All
  List<int> _visibleMemoIds = const [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchTerm = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isar = ref.watch(isarProvider);

    final tier = ref.watch(subscriptionProvider);
    return Scaffold(
      appBar: AppBar(
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectionMode = false;
                    _selected.clear();
                  });
                },
              )
            : null,
        title: _selectionMode
            ? Text('${_selected.length}件選択')
            : const Text('メモ一覧'),
        actions: _selectionMode
            ? [
                IconButton(
                  tooltip: 'すべて選択/解除',
                  icon: Icon(
                    _selected.length == _visibleMemoIds.length && _visibleMemoIds.isNotEmpty
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                  ),
                  onPressed: () {
                    setState(() {
                      if (_selected.length == _visibleMemoIds.length) {
                        _selected.clear();
                      } else {
                        _selected
                          ..clear()
                          ..addAll(_visibleMemoIds);
                      }
                    });
                  },
                ),
                IconButton(
                  tooltip: '選択したメモを削除',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: _selected.isEmpty
                      ? null
                      : () async {
                          final db = await ref.read(isarProvider.future);
                          await _deleteSelected(db);
                        },
                ),
              ]
            : [
                if (tier == SubscriptionTier.free)
                  TextButton(
                    onPressed: () async {
                      // Lazy import to avoid build-time coupling in this file
                      // ignore: use_build_context_synchronously
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) {
                          // Import here to keep top of file tidy
                          // ignore: avoid_types_on_closure_parameters
                          return const _PaywallEntry();
                        }),
                      );
                      setState(() {});
                    },
                    child: const Text('Proにする'),
                  ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectionMode = true;
                      _selected.clear();
                    });
                  },
                  child: const Text('選択'),
                ),
              ],
        bottom: !_selectionMode && tier == SubscriptionTier.pro
            ? PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '検索...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: isar.when(
        data: (db) {
          // Isarからメモを取得するStream
          final stream = tier == SubscriptionTier.pro
              ? db.memos
                  .where()
                  .filter()
                  .textContains(_searchTerm, caseSensitive: false)
                  .sortByCreatedAtDesc()
                  .watch(fireImmediately: true)
              : db.memos
                  .where()
                  .sortByCreatedAtDesc()
                  .limit(50)
                  .watch(fireImmediately: true);

          return StreamBuilder<List<Memo>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                var memos = snapshot.data!;
                // Proのタグ検索（#タグ記法）をクライアント側で簡易対応
                if (tier == SubscriptionTier.pro && _searchTerm.trim().startsWith('#')) {
                  final tag = _searchTerm.trim().replaceFirst('#', '').toLowerCase();
                  if (tag.isNotEmpty) {
                    memos = memos.where((m) => m.text.toLowerCase().contains('#$tag')).toList();
                  }
                }
                // ピン留めと通常に分割
                final nowUtc = DateTime.now().toUtc();
                final pinned = memos
                    .where((m) => m.reminderAt != null && !m.isDone && m.reminderAt!.isAfter(nowUtc))
                    .toList()
                  ..sort((a, b) => a.reminderAt!.compareTo(b.reminderAt!));
                final pinnedIds = pinned.map((e) => e.id).toSet();
                final remaining = memos.where((m) => !pinnedIds.contains(m.id)).toList();

                // Update visible ids for Select All (pinned + remaining in view order)
                _visibleMemoIds = [
                  ...pinned.map((e) => e.id),
                  ...remaining.map((e) => e.id),
                ];

                if (memos.isEmpty) {
                  return Column(
                    children: [
                      const Expanded(child: Center(child: Text('メモがありません'))),
                      if (tier == SubscriptionTier.free) const AdBanner(),
                    ],
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        children: [
                          if (pinned.isNotEmpty) _buildPinnedSection(db, pinned),
                          for (final memo in remaining) _buildMemoCard(db, memo),
                        ],
                      ),
                    ),
                    if (tier == SubscriptionTier.free) const AdBanner(),
                  ],
                );
              } else if (snapshot.hasError) {
                return Column(
                  children: [
                    Expanded(child: Center(child: Text('Error: ${snapshot.error}'))),
                    if (tier == SubscriptionTier.free) const AdBanner(),
                  ],
                );
              } else {
                return Column(
                  children: const [
                    Expanded(child: Center(child: CircularProgressIndicator())),
                    AdBanner(),
                  ],
                );
              }
            },
          );
        },
        loading: () => Column(
          children: const [
            Expanded(child: Center(child: CircularProgressIndicator())),
            AdBanner(),
          ],
        ),
        error: (err, stack) => Column(
          children: [
            Expanded(child: Center(child: Text('Error: $err'))),
            if (tier == SubscriptionTier.free) const AdBanner(),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleDone(Isar db, Memo memo) async {
    final newVal = !(_doneOverlay.contains(memo.id) || memo.isDone);
    // UI即時反映
    setState(() {
      if (newVal) {
        _doneOverlay.add(memo.id);
      } else {
        _doneOverlay.remove(memo.id);
      }
    });
    // DB反映（コード生成前でもUIは保つ）
    try {
      await db.writeTxn(() async {
        memo.isDone = newVal;
        memo.updatedAt = DateTime.now().toUtc();
        await db.memos.put(memo);
      });
      if (newVal && memo.reminderAt != null) {
        await NotificationService.instance.cancelReminder(memo.id);
      }
    } catch (_) {
      // 失敗時はUIを元に戻す
      if (mounted) {
        setState(() {
          if (newVal) {
            _doneOverlay.remove(memo.id);
          } else {
            _doneOverlay.add(memo.id);
          }
        });
      }
    }
  }

  // 以前の単体操作用コンテキストメニューは未使用のため削除

  Widget _buildPinnedSection(Isar db, List<Memo> pinned) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        color: Colors.yellow[50],
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.yellow[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('これからのリマインド', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final m in pinned.take(6))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: InkWell(
                    onTap: () {
                      if (_selectionMode) {
                        setState(() => _toggleSelect(m.id));
                      }
                    },
                    onLongPress: () async {
                      if (_selectionMode) {
                        setState(() {
                          _toggleSelect(m.id);
                        });
                        return;
                      }
                      final changed = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EditView(memoId: m.id),
                        ),
                      );
                      if (changed == true && mounted) setState(() {});
                    },
                    child: Row(
                      children: [
                        if (_selectionMode) ...[
                          Checkbox(
                            value: _selected.contains(m.id),
                            onChanged: (_) {
                              setState(() => _toggleSelect(m.id));
                            },
                          ),
                          Expanded(
                            child: Text(m.text, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ] else ...[
                          const Icon(Icons.notifications_active, size: 16, color: Colors.amber),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(m.text, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Text('${m.reminderAt!.toLocal()}'.substring(0, 16),
                              style: const TextStyle(color: Colors.black54)),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'リマインド変更',
                            icon: const Icon(Icons.edit_notifications, size: 18),
                            onPressed: () => _changeReminder(db, m),
                          ),
                          IconButton(
                            tooltip: '解除',
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () async {
                              await db.writeTxn(() async {
                                m.reminderAt = null;
                                m.updatedAt = DateTime.now().toUtc();
                                await db.memos.put(m);
                              });
                              await NotificationService.instance.cancelReminder(m.id);
                              if (mounted) setState(() {});
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 以前のピン留め用選択シートは削除（AppBarの「選択」ボタンで統一）

  Widget _buildMemoCard(Isar db, Memo memo) {
    final overdue = memo.reminderAt != null && memo.reminderAt!.isBefore(DateTime.now().toUtc());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Stack(
        children: [
          Card(
            elevation: 4.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: ListTile(
              leading: _selectionMode
                   ? Checkbox(
                       value: _selected.contains(memo.id),
                       onChanged: (_) {
                         setState(() => _toggleSelect(memo.id));
                       },
                     )
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        final db = await ref.read(isarProvider.future);
                        await _toggleDone(db, memo);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (_doneOverlay.contains(memo.id) || memo.isDone)
                              ? Colors.green
                              : Colors.transparent,
                          border: Border.all(
                            color: (_doneOverlay.contains(memo.id) || memo.isDone)
                                ? Colors.green
                                : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: (_doneOverlay.contains(memo.id) || memo.isDone)
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
              title: Text(
                memo.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  decoration: (_doneOverlay.contains(memo.id) || memo.isDone)
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              subtitle: Text('${memo.createdAt.toLocal()}'.substring(0, 16)),
              onTap: () async {
                if (_selectionMode) {
                  setState(() => _toggleSelect(memo.id));
                  return;
                }
                final changed = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EditView(memoId: memo.id),
                  ),
                );
                if (changed == true && mounted) setState(() {});
              },
              onLongPress: () {
                if (_selectionMode) {
                  setState(() => _toggleSelect(memo.id));
                } else {
                  setState(() {
                    _selectionMode = true;
                    _selected.clear();
                    _selected.add(memo.id);
                  });
                }
              },
            ),
          ),
          if (memo.reminderAt != null)
            Positioned(
              right: 12,
              top: 4,
              child: ReminderBadge(
                when: memo.reminderAt!.toLocal(),
                overdue: overdue,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _changeReminder(Isar db, Memo memo) async {
    final now = DateTime.now();
    DateTime tonight() {
      final t = DateTime(now.year, now.month, now.day, 20, 0);
      return now.isAfter(t) ? t.add(const Duration(days: 1)) : t;
    }

    DateTime tomorrowMorning() {
      final t = DateTime(now.year, now.month, now.day, 9, 0).add(const Duration(days: 1));
      return t;
    }

    // ignore: use_build_context_synchronously
    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('1時間後'),
                onTap: () => Navigator.of(ctx).pop(now.add(const Duration(hours: 1))),
              ),
              ListTile(
                leading: const Icon(Icons.nightlight_round),
                title: const Text('今夜'),
                onTap: () => Navigator.of(ctx).pop(tonight()),
              ),
              ListTile(
                leading: const Icon(Icons.wb_sunny),
                title: const Text('明日朝'),
                onTap: () => Navigator.of(ctx).pop(tomorrowMorning()),
              ),
              ListTile(
                leading: const Icon(Icons.event),
                title: const Text('日時を選ぶ...'),
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: now,
                    firstDate: now,
                    lastDate: DateTime(now.year + 5),
                  );
                  if (date == null) {
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                    return;
                  }
                  if (!ctx.mounted) return;
                  final time = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
                  );
                  if (time == null) {
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                    return;
                  }
                  final selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop(selected);
                },
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      await db.writeTxn(() async {
        memo.reminderAt = selected.toUtc();
        memo.updatedAt = DateTime.now().toUtc();
        await db.memos.put(memo);
      });
      await NotificationService.instance.scheduleReminder(
        id: memo.id,
        when: selected,
        title: 'KOTO リマインダー',
        body: memo.text,
      );
    }
  }

  void _toggleSelect(int id) {
    if (_selected.contains(id)) {
      _selected.remove(id);
      if (_selected.isEmpty) {
        // Optionally exit selection mode automatically
        // _selectionMode = false;
      }
    } else {
      _selected.add(id);
    }
  }

  Future<void> _deleteSelected(Isar db) async {
    if (_selected.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text('${_selected.length}件のメモを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ids = _selected.toList();
    await db.writeTxn(() async {
      for (final id in ids) {
        await db.memos.delete(id);
      }
    });
    // Cancel any scheduled notifications for these ids
    for (final id in ids) {
      await NotificationService.instance.cancelReminder(id);
    }
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ids.length}件のメモを削除しました')),
      );
    }
  }
}

class _PaywallEntry extends StatelessWidget {
  const _PaywallEntry();
  @override
  Widget build(BuildContext context) => const PaywallView();
}
