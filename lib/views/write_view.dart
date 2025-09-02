
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:koto/main.dart';
import 'package:koto/models/memo.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koto/services/notification_service.dart';
import 'package:flutter/services.dart';
import 'package:koto/widgets/reminder_badge.dart';
import 'package:koto/services/subscription_service.dart';
import 'package:koto/app_globals.dart';

/// 「書く」モードの画面
class WriteView extends ConsumerStatefulWidget {
  const WriteView({super.key});

  @override
  ConsumerState<WriteView> createState() => _WriteViewState();
}

class _WriteViewState extends ConsumerState<WriteView> with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // ドラッグ操作の状態を管理
  double _dragOffsetY = 0.0;
  double _dragOffsetX = 0.0;

  // Undo用の状態
  Memo? _lastSavedMemo;
  String? _lastDiscardedText;

  bool _showReminderChoices = false;
  Timer? _chipHideTimer;
  // 保存フィードバック
  bool _showSaveAffix = false; // エディタカード右上に付箋を短時間表示
  Timer? _saveAffixTimer;
  DateTime? _lastSavedReminderAt;
  // 右側のチェック付箋
  bool _showRightSaveCheck = false;
  String? _rightSaveLabel;
  bool _dragFromHandle = false; // 右端ハンドルからのドラッグ中か

  // 閾値（微調整しやすいよう定数化）
  // さらに緩和して“軽いドラッグ”で反応させる
  static const double _dragShowRailThresholdX = 8;  // レール出現をより早く
  static const double _dragActionThresholdX = 24;   // 保存・破棄の必要移動量も短く
  static const double _dragActionThresholdY = 80;   // 縦方向保存の必要移動量を軽減

  // ドロップレール用（ヒットテスト計算と選択ハイライト）
  int? _hoverTargetIndex;
  int? _latchedDropIndex; // カーソルが乗った時点で“選択確定”
  Offset _lastGlobalPos = Offset.zero;
  final GlobalKey _railKey = GlobalKey();
  final GlobalKey _cardKey = GlobalKey();
  Rect? _railRectCache; // 右レールの実サイズ（グローバル座標）
  static const double _railWidth = 180; // レール自体の幅
  static const double _segHeight = 44;
  static const double _segSpacing = 8;
  static const double _railPaddingV = 10;
  static const double _railHeaderHeight = 22; // アイコン+テキスト行の概算高さ

  static final List<_DropOption> _dropOptions = [
    _DropOption(label: '10分後', minutes: 10, icon: Icons.timelapse),
    _DropOption(label: '20分後', minutes: 20, icon: Icons.timelapse),
    _DropOption(label: '30分後', minutes: 30, icon: Icons.timer_outlined),
    _DropOption(label: '45分後', minutes: 45, icon: Icons.schedule),
    _DropOption(label: '1時間後', minutes: 60, icon: Icons.timer),
    _DropOption(label: '90分後', minutes: 90, icon: Icons.av_timer),
    _DropOption(label: '2時間後', minutes: 120, icon: Icons.timer),
    _DropOption(label: '3時間後', minutes: 180, icon: Icons.av_timer),
    _DropOption(label: '4時間後', minutes: 240, icon: Icons.schedule_outlined),
    _DropOption(label: '6時間後', minutes: 360, icon: Icons.schedule_outlined),
    _DropOption(
      label: '今夜',
      icon: Icons.nightlight_round,
      whenBuilder: () {
        final now = DateTime.now();
        final t = DateTime(now.year, now.month, now.day, 20, 0);
        return now.isAfter(t) ? t.add(const Duration(days: 1)) : t;
      },
    ),
    _DropOption(
      label: '明日朝',
      icon: Icons.wb_sunny,
      whenBuilder: () {
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day, 9, 0).add(const Duration(days: 1));
      },
    ),
  ];

  @override
  void initState() {
    super.initState();

    // 起動直後にキーボード表示（できるだけ早く）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_focusNode);
        // Warm KPI計測の停止と公開
        WarmKpi.stopAndPublish();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _chipHideTimer?.cancel();
    _saveAffixTimer?.cancel();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 10) {
      return 'おはようございます。今日のタスクは？';
    } else if (hour < 18) {
      return 'こんにちは。アイデアをどうぞ。';
    } else {
      return 'こんばんは。今日を振り返りましょう。';
    }
  }

  /// メモをIsarに保存する（必要ならリマインダーも設定）
  Future<void> _saveMemo({DateTime? reminderAt, String? reminderLabel}) async {
    final isar = await ref.read(isarProvider.future);
    // Basicのリマインダー上限チェック（月5回）
    final tier = ref.read(subscriptionProvider);
    if (reminderAt != null && tier == SubscriptionTier.free) {
      final now = DateTime.now().toUtc();
      final monthStart = DateTime.utc(now.year, now.month, 1);
      final nextMonth = DateTime.utc(now.year, now.month + 1, 1);
      final count = await isar.memos
          .filter()
          .reminderAtIsNotNull()
          .and()
          .reminderAtGreaterThan(monthStart, include: true)
          .and()
          .reminderAtLessThan(nextMonth, include: false)
          .count();
      if (count >= 5) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('今月のリマインダー上限（5件）に達しました')),
        );
        return;
      }
    }
    if (_textController.text.isNotEmpty) {
      // タグ抽出
      final tags = _extractInlineTags(_textController.text);
      final newMemo = Memo(
        text: _textController.text,
        createdAt: DateTime.now().toUtc(),
        updatedAtParam: DateTime.now().toUtc(),
        reminderAt: reminderAt?.toUtc(),
      );
      newMemo.inlineTags = tags;
      await isar.writeTxn(() async {
        await isar.memos.put(newMemo);
      });
      _lastSavedMemo = newMemo;

      // リマインドをスケジュール
      if (reminderAt != null) {
        await NotificationService.instance.scheduleReminder(
          id: newMemo.id,
          when: reminderAt,
          title: 'KOTO リマインダー',
          body: newMemo.text,
        );
        // 視覚フィードバック
        HapticFeedback.mediumImpact();
        if (!mounted) return; // guard after awaits
        setState(() {
          _lastSavedReminderAt = reminderAt;
          _showSaveAffix = true;
          _showRightSaveCheck = true;
          _rightSaveLabel = reminderLabel;
        });
        _saveAffixTimer?.cancel();
        _saveAffixTimer = Timer(const Duration(milliseconds: 1600), () {
          if (mounted) setState(() => _showSaveAffix = false);
        });
        _startRightSaveCheckAutoHide();
      }
      _textController.clear();
      if (!mounted) return; // guard before using context in snackbar
      final msg = reminderAt != null
          ? 'リマインダー（${reminderLabel ?? _formatReminderLabel(reminderAt)})で保存しました'
          : '保存しました';
      _showUndoSnackbar(msg, newMemo);
    }
  }

  /// メモを破棄する
  void _discardMemo() {
    _lastDiscardedText = _textController.text;
    _textController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('破棄しました')),
    );
  }

  // Removed unused _showReminderSheet to satisfy analyzer (unused_element)

  /// Undo（元に戻す）機能付きのスナックバーを表示
  void _showUndoSnackbar(String message, Memo memo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: '元に戻す',
          onPressed: () async {
            final isar = await ref.read(isarProvider.future);
            await isar.writeTxn(() async {
              await isar.memos.delete(memo.id);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // キーボード表示時にカードが隠れないように持ち上げる（BottomNav分を差し引いて二重上げを防止）
    final mq = MediaQuery.of(context);
    final keyboardInset = mq.viewInsets.bottom;
    final bool hasKeyboard = keyboardInset > 0;
    // 親Scaffoldが body をキーボード分だけリサイズしている前提
    return Container(
      color: Colors.grey[100],
      child: Stack(
        children: [
          _buildEditorArea(0.0, hasKeyboard, mq),

          // （ハンドル主導のドラッグに移行したため Pan オーバーレイは撤去）
          const SizedBox.shrink(),

          // 2本指タップ検知（Scaleのみ）
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onScaleStart: (details) {
                if (details.pointerCount == 2) {
                  HapticFeedback.lightImpact();
                  _undoLastAction();
                }
              },
            ),
          ),

          // 右ドラッグ時に現れるクイックリマインド付箋
          _showReminderChoices
              ? Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: Container(
                          key: _railKey,
                          width: _railWidth,
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(255, 255, 255, 0.95),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                            ],
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.notifications_active, size: 14, color: Colors.black54),
                                  SizedBox(width: 6),
                                  Text('リマインド', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              for (var i = 0; i < _dropOptions.length; i++) ...[
                                _railChip(
                                  icon: _dropOptions[i].icon,
                                  label: _dropOptions[i].label,
                                  color: Colors.amber[400]!,
                                  selected: (_hoverTargetIndex == i) || (_latchedDropIndex == i),
                                  onTap: () async {
                                    final opt = _dropOptions[i];
                                    final when = opt.whenBuilder != null
                                        ? opt.whenBuilder!.call()
                                        : DateTime.now().add(Duration(minutes: opt.minutes!));
                                    await _saveMemo(reminderAt: when, reminderLabel: _dropOptions[i].label);
                                    setState(() {
                                      _showReminderChoices = false;
                                      _latchedDropIndex = null;
                                      _hoverTargetIndex = null;
                                    });
                                  },
                                ),
                                if (i != _dropOptions.length - 1) const SizedBox(height: 8),
                              ],
                            ],
                          ),
                        ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),

          // ドロップ先プレビュー（選択中のラベルをレール左に表示）
          (_showReminderChoices && (_hoverTargetIndex != null || _latchedDropIndex != null))
              ? _buildHoverPreview()
              : const SizedBox.shrink(),

          // 右側の保存完了チェック付箋（短い入場アニメで“保存した感”を強調）
          (_showRightSaveCheck && _rightSaveLabel != null)
              ? Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _successChip(_rightSaveLabel!)
                            .animate()
                            .fadeIn(duration: 140.ms)
                            .slideX(begin: 0.06, end: 0, curve: Curves.easeOutCubic)
                            .scale(begin: Offset(0.96, 0.96), end: const Offset(1, 1), curve: Curves.easeOutBack),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildEditorArea(double editorLift, bool hasKeyboard, MediaQueryData mq) {
    final Alignment editorAlignment = hasKeyboard
        ? Alignment.bottomCenter
        : const Alignment(0, -0.4); // キーボード非表示時は少し上に配置
    return Align(
      alignment: editorAlignment,
      child: SafeArea(
        top: true,
        bottom: true,
        child: Transform.translate(
          offset: Offset(_dragOffsetX, _dragOffsetY),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: hasKeyboard ? 16.0 : 24.0,
              vertical: hasKeyboard ? 8.0 : 24.0,
            ),
            child: GestureDetector(
                dragStartBehavior: DragStartBehavior.down,
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  FocusScope.of(context).requestFocus(_focusNode);
                },
                onPanStart: (details) {
                  // 右側からのドラッグのみ受け付ける（カード幅の60%より右）
                  final box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
                  if (box != null && box.hasSize) {
                    final local = box.globalToLocal(details.globalPosition);
                    if (local.dx > box.size.width * 0.6) {
                      _dragFromHandle = true;
                    }
                  }
                },
                onPanUpdate: (details) {
                  if (_dragFromHandle || _showReminderChoices) {
                    _handleDragUpdate(details);
                  }
                },
                onPanEnd: (details) async {
                  if (_dragFromHandle || _showReminderChoices) {
                    await _handleDragEnd(details);
                  }
                  if (mounted) setState(() => _dragFromHandle = false);
                },
                onPanCancel: () {
                  _resetDragState();
                  if (mounted) setState(() => _dragFromHandle = false);
                },
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: (MediaQuery.of(context).size.height - mq.padding.top - 8)
                        .clamp(140.0, MediaQuery.of(context).size.height * 0.9),
                  ),
                  child: Card(
                    key: _cardKey,
                    elevation: 8.0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(hasKeyboard ? 14.0 : 20.0),
                          child: TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            maxLines: null,
                            enableInteractiveSelection: false, // ドラッグ操作優先（MVP）
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: _getGreeting(),
                              hintStyle: TextStyle(color: Colors.grey[400]),
                            ),
                            style: const TextStyle(fontSize: 18.0),
                          ),
                        ),
                        // 右端グラブハンドル（ここからドラッグで操作開始）
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: 28,
                            height: double.infinity,
                            child: IgnorePointer(
                              ignoring: true,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: Opacity(
                                  opacity: 0.18,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      SizedBox(height: 4),
                                      _GripDot(),
                                      _GripDot(),
                                      _GripDot(),
                                      _GripDot(),
                                      _GripDot(),
                                      SizedBox(height: 4),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        (_showSaveAffix && _lastSavedReminderAt != null)
                            ? Positioned(
                                right: 12,
                                top: 8,
                                child: ReminderBadge(
                                  when: _lastSavedReminderAt!,
                                  overdue: false,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ],
                    ),
                  ).animate().slideY(
                        begin: 0.12,
                        end: 0,
                        curve: Curves.easeOutCubic,
                      ),
                ),
              ),
            ),
          ),
        ),
      );
  }

  // 共通ドラッグ処理（右端ハンドル/外側オーバーレイから呼ばれる）
  void _handleDragUpdate(DragUpdateDetails details) {
    final wasShowing = _showReminderChoices;
    setState(() {
      _dragOffsetX += details.delta.dx;
      _dragOffsetY += details.delta.dy;
      _showReminderChoices = _dragOffsetX > _dragShowRailThresholdX;
      _lastGlobalPos = details.globalPosition;
    });

    if (!wasShowing && _showReminderChoices) {
      // レール表示の次フレームで安全にキーボードを閉じ、レール領域を計測
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        FocusScope.of(context).unfocus();
        _ensureRailRect();
      });
    }
    if (_showReminderChoices) {
      _updateHoverTarget(details);
    }
  }

  Future<void> _handleDragEnd(DragEndDetails details) async {
    final absX = _dragOffsetX.abs();
    final absY = _dragOffsetY.abs();

    // 1) レール上で候補が確定していれば、距離に関係なく保存（右ドラッグ時）
    if (_dragOffsetX > 0 && _showReminderChoices && _latchedDropIndex != null) {
      if (await _canSetReminder()) {
        final idx = _latchedDropIndex!;
        final opt = _dropOptions[idx];
        final when = opt.whenBuilder != null
            ? opt.whenBuilder!.call()
            : DateTime.now().add(Duration(minutes: opt.minutes!));
        await _saveMemo(reminderAt: when, reminderLabel: opt.label);
        setState(() {
          _showReminderChoices = false;
          _hoverTargetIndex = null;
          _latchedDropIndex = null;
        });
        _resetDragState();
        return;
      }
    }

    // 2) 従来の距離ベース（緩和済み）
    if (absX > _dragActionThresholdX && absX > absY) {
      if (_dragOffsetX > 0) {
        HapticFeedback.selectionClick();
        if (await _canSetReminder()) {
          int? idx = _latchedDropIndex ?? _hoverTargetIndex;
          idx ??= _indexForGlobal(_lastGlobalPos);
          idx ??= _defaultDropIndex();
          final opt = _dropOptions[idx];
          final when = opt.whenBuilder != null
              ? opt.whenBuilder!.call()
              : DateTime.now().add(Duration(minutes: opt.minutes!));
          await _saveMemo(reminderAt: when, reminderLabel: opt.label);
          setState(() {
            _showReminderChoices = false;
            _hoverTargetIndex = null;
            _latchedDropIndex = null;
          });
        }
      } else {
        HapticFeedback.lightImpact();
        _discardMemo();
      }
    } else if (_dragOffsetY > _dragActionThresholdY && absY > absX) {
      HapticFeedback.selectionClick();
      await _saveMemo();
    }

    _resetDragState();
  }

  void _resetDragState() {
    if (!mounted) return;
    setState(() {
      _dragOffsetX = 0.0;
      _dragOffsetY = 0.0;
      _showReminderChoices = false;
      _latchedDropIndex = null;
      _hoverTargetIndex = null;
    });
  }

  Future<void> _undoLastAction() async {
    // 直前の保存を取り消す
    if (_lastSavedMemo != null) {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        await isar.memos.delete(_lastSavedMemo!.id);
      });
      if (_lastSavedMemo!.reminderAt != null) {
        await NotificationService.instance.cancelReminder(_lastSavedMemo!.id);
      }
      _textController.text = _lastSavedMemo!.text;
      _lastSavedMemo = null;
      return;
    }

    // 直前の破棄を取り消す
    if (_lastDiscardedText != null) {
      _textController.text = _lastDiscardedText!;
      _lastDiscardedText = null;
    }
  }

  void _startChipAutoHide() {
    _chipHideTimer?.cancel();
    _chipHideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showReminderChoices = false;
          _latchedDropIndex = null;
          _hoverTargetIndex = null;
        });
      }
    });
  }

  void _startRightSaveCheckAutoHide() {
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _showRightSaveCheck = false);
    });
  }

  String _formatReminderLabel(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final isToday = now.year == local.year && now.month == local.month && now.day == local.day;
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final isTomorrow = tomorrow.year == local.year && tomorrow.month == local.month && tomorrow.day == local.day;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    if (isToday) return '今日 $hh:$mm';
    if (isTomorrow) return '明日 $hh:$mm';
    return '${local.month}/${local.day} $hh:$mm';
  }

  void _updateHoverTarget(DragUpdateDetails details) {
    _ensureRailRect();
    final rect = _railRectCache;
    if (rect == null) return;

    final gp = details.globalPosition;
    if (!rect.contains(gp)) {
      // レール外に出ても“確定選択”は保持したまま、ハイライトのみ消す
      if (_hoverTargetIndex != null) {
        _hoverTargetIndex = null;
        setState(() {});
      }
      return;
    }

    // レール内のローカル座標
    final local = gp - rect.topLeft;
    // ヘッダ + 余白を差し引く
    final yInItems = local.dy - _railPaddingV - _railHeaderHeight - 8;
    if (yInItems < 0) {
      if (_hoverTargetIndex != null) {
        _hoverTargetIndex = null;
        setState(() {});
      }
      return;
    }
    final segmentSpan = _segHeight + _segSpacing;
    int idx = (yInItems ~/ segmentSpan).clamp(0, _dropOptions.length - 1);
    if (_hoverTargetIndex != idx) {
      _hoverTargetIndex = idx;
      _latchedDropIndex = idx; // 乗った時点で選択確定
      HapticFeedback.selectionClick();
      setState(() {});
    }
  }

  void _ensureRailRect() {
    final ctx = _railKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final topLeft = box.localToGlobal(Offset.zero);
    _railRectCache = topLeft & box.size;
  }

  int? _indexForGlobal(Offset gp) {
    _ensureRailRect();
    final rect = _railRectCache;
    if (rect == null || !rect.contains(gp)) return null;
    final local = gp - rect.topLeft;
    final yInItems = local.dy - _railPaddingV - _railHeaderHeight - 8;
    if (yInItems < 0) return null;
    final segmentSpan = _segHeight + _segSpacing;
    int idx = (yInItems ~/ segmentSpan).clamp(0, _dropOptions.length - 1);
    return idx;
  }

  // フォールバックで選ぶデフォルトのインデックス（優先: 1時間後 → 10分後）
  int _defaultDropIndex() {
    final oneHourIdx = _dropOptions.indexWhere((o) => o.label.contains('1時間'));
    if (oneHourIdx != -1) return oneHourIdx;
    return 0;
  }

  Future<bool> _canSetReminder() async {
    final tier = ref.read(subscriptionProvider);
    if (tier == SubscriptionTier.pro) return true;
    final isar = await ref.read(isarProvider.future);
    final now = DateTime.now().toUtc();
    final monthStart = DateTime.utc(now.year, now.month, 1);
    final nextMonth = DateTime.utc(now.year, now.month + 1, 1);
    final count = await isar.memos
        .filter()
        .reminderAtIsNotNull()
        .and()
        .reminderAtGreaterThan(monthStart, include: true)
        .and()
        .reminderAtLessThan(nextMonth, include: false)
        .count();
    if (count >= 5) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('今月のリマインダー上限（5件）に達しました')),
      );
      return false;
    }
    return true;
  }

  List<String> _extractInlineTags(String text) {
    final reg = RegExp(r'(^|\s)#([A-Za-z0-9_\-]+)');
    final found = <String>{};
    for (final m in reg.allMatches(text)) {
      if (m.groupCount >= 2) {
        final tag = m.group(2)!;
        if (tag.isNotEmpty) found.add(tag.toLowerCase());
      }
    }
    return found.toList()..sort();
  }

  // Removed unused _stickyChip to satisfy analyzer (unused_element)

  Widget _successChip(String label) {
    return Transform.rotate(
      angle: -0.06,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.greenAccent[400],
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, size: 16, color: Colors.black87),
            const SizedBox(width: 6),
            Text(
              '$label で保存',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _railChip({
    required IconData icon,
    required String label,
    required Color color,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        width: double.infinity,
        height: _segHeight,
        decoration: BoxDecoration(
          color: selected ? Colors.amber[500] : color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Colors.black54 : Colors.transparent, width: 1),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(icon, size: 18, color: Colors.black87),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoverPreview() {
    _ensureRailRect();
    final rect = _railRectCache;
    if (rect == null) return const SizedBox.shrink();
    final segmentSpan = _segHeight + _segSpacing;
    final rawIdx = (_hoverTargetIndex ?? _latchedDropIndex) ?? 0;
    final idx = rawIdx.clamp(0, _dropOptions.length - 1);
    final centerY = rect.top + _railPaddingV + _railHeaderHeight + 8 + idx * segmentSpan + _segHeight / 2;

    return Positioned(
      right: (MediaQuery.of(context).size.width - rect.left) + 10,
      top: centerY - 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _dropOptions[idx].label,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ).animate().fadeIn(duration: 120.ms),
    );
  }
}

class _GripDot extends StatelessWidget {
  const _GripDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _DropOption {
  final String label;
  final int? minutes;
  final IconData icon;
  final DateTime Function()? whenBuilder;
  const _DropOption({
    required this.label,
    this.minutes,
    required this.icon,
    this.whenBuilder,
  });
}
