import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koto/main.dart';
import 'package:koto/models/memo.dart';
import 'package:koto/services/notification_service.dart';

class EditView extends ConsumerStatefulWidget {
  final int memoId;
  const EditView({super.key, required this.memoId});

  @override
  ConsumerState<EditView> createState() => _EditViewState();
}

class _EditViewState extends ConsumerState<EditView> {
  final TextEditingController _controller = TextEditingController();
  DateTime? _reminderAt;
  bool _isDone = false;
  bool _loading = true;
  Memo? _loaded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final isar = await ref.read(isarProvider.future);
    final memo = await isar.memos.get(widget.memoId);
    if (!mounted) return;
    setState(() {
      _loaded = memo;
      _controller.text = memo?.text ?? '';
      _reminderAt = memo?.reminderAt?.toLocal();
      _isDone = memo?.isDone ?? false;
      _loading = false;
    });
  }

  String _formatReminder(DateTime? dt) {
    if (dt == null) return 'なし';
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.year}/${local.month}/${local.day} $hh:$mm';
  }

  Future<void> _pickQuickReminder() async {
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
                leading: const Icon(Icons.timelapse),
                title: const Text('10分後'),
                onTap: () => Navigator.of(ctx).pop(now.add(const Duration(minutes: 10))),
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('30分後'),
                onTap: () => Navigator.of(ctx).pop(now.add(const Duration(minutes: 30))),
              ),
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
                    Navigator.of(ctx).pop();
                    return;
                  }
                  final time = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
                  );
                  if (time == null) {
                    Navigator.of(ctx).pop();
                    return;
                  }
                  final selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                  Navigator.of(ctx).pop(selected);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      setState(() {
        _reminderAt = selected;
      });
    }
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
    final list = found.toList();
    list.sort();
    return list;
  }

  Future<void> _save() async {
    if (_loaded == null) return;
    final isar = await ref.read(isarProvider.future);
    final memo = _loaded!;
    final text = _controller.text;
    final hadReminder = memo.reminderAt != null;
    final willHaveReminder = _reminderAt != null;

    await isar.writeTxn(() async {
      memo.text = text;
      memo.inlineTags = _extractInlineTags(text);
      memo.isDone = _isDone;
      memo.reminderAt = _reminderAt?.toUtc();
      memo.updatedAt = DateTime.now().toUtc();
      await isar.memos.put(memo);
    });

    // Notifications: cancel old if changed or removed, schedule new if present
    if (hadReminder && !willHaveReminder) {
      await NotificationService.instance.cancelReminder(memo.id);
    }
    if (willHaveReminder) {
      await NotificationService.instance.scheduleReminder(
        id: memo.id,
        when: _reminderAt!,
        title: 'KOTO リマインダー',
        body: memo.text,
      );
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    if (_loaded == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除しますか？'),
        content: const Text('このメモを削除します。元に戻せません。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('削除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;

    final isar = await ref.read(isarProvider.future);
    await isar.writeTxn(() async {
      await isar.memos.delete(widget.memoId);
    });
    await NotificationService.instance.cancelReminder(widget.memoId);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('メモを編集'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
            tooltip: '削除',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('保存'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '編集...',
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                InkWell(
                  onTap: () => setState(() => _isDone = !_isDone),
                  child: Row(
                    children: [
                      Icon(
                        _isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: _isDone ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      const Text('完了'),
                    ],
                  ),
                ),
                const Spacer(),
                Text('リマインド: ${_formatReminder(_reminderAt)}'),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _pickQuickReminder,
                  icon: const Icon(Icons.edit_notifications),
                  label: const Text('変更'),
                ),
                if (_reminderAt != null)
                  TextButton(
                    onPressed: () => setState(() => _reminderAt = null),
                    child: const Text('解除'),
                  ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_circle, size: 22),
              label: const Text('保存', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
