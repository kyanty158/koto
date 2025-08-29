import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:koto/models/memo.dart';
import 'package:koto/app_globals.dart';
import 'package:koto/views/edit_view.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  // no-op

  Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          'koto_actions',
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain('done', '完了'),
            DarwinNotificationAction.plain('snooze', 'スヌーズ +15分'),
            DarwinNotificationAction.plain('edit', '編集を開く'),
          ],
        ),
      ],
    );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) async {
        await _handleResponse(resp);
      },
    );

    // Timezone database for precise scheduling
    tz.initializeTimeZones();

    // Create a default channel on Android
    if (!kIsWeb && Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'koto_default',
        'KOTO Notifications',
        description: 'General reminders for notes',
        importance: Importance.defaultImportance,
      );
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(channel);
      // Android 13+ permission
      await android?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  Future<void> scheduleReminder({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await initialize();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'koto_default',
        'KOTO Notifications',
        channelDescription: 'General reminders for notes',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction('done', '完了'),
          AndroidNotificationAction('snooze', 'スヌーズ +15分'),
          AndroidNotificationAction('edit', '編集を開く'),
        ],
      ),
      iOS: DarwinNotificationDetails(categoryIdentifier: 'koto_actions'),
    );

    final tzTime = tz.TZDateTime.from(when, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: id.toString(),
    );
  }

  Future<void> cancelReminder(int id) async {
    if (!_initialized) await initialize();
    await _plugin.cancel(id);
  }

  Future<void> _handleResponse(NotificationResponse resp) async {
    try {
      final action = (resp.actionId ?? '').isEmpty ? 'default' : resp.actionId!;
      final payload = resp.payload;
      final memoId = int.tryParse(payload ?? '') ?? -1;
      debugPrint('Notification action=$action id=$memoId');
      if (memoId < 0) return;

      final isar = Isar.getInstance();
      if (isar == null) return;

      if (action == 'done') {
        await isar.writeTxn(() async {
          final memo = await isar.memos.get(memoId);
          if (memo != null) {
            memo.isDone = true;
            memo.updatedAt = DateTime.now().toUtc();
            await isar.memos.put(memo);
          }
        });
        return;
      }

      if (action == 'snooze') {
        final when = DateTime.now().add(const Duration(minutes: 15));
        await isar.writeTxn(() async {
          final memo = await isar.memos.get(memoId);
          if (memo != null) {
            memo.reminderAt = when.toUtc();
            memo.updatedAt = DateTime.now().toUtc();
            await isar.memos.put(memo);
          }
        });
        await cancelReminder(memoId);
        await scheduleReminder(
          id: memoId,
          when: when,
          title: 'KOTO リマインダー',
          body: 'スヌーズ: ${when.toLocal()}',
        );
        return;
      }

      if (action == 'edit' || action == 'default') {
        // Bring UI to edit the memo
        navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => EditView(memoId: memoId),
        ));
        return;
      }
    } catch (e) {
      debugPrint('Notification handle error: $e');
    }
  }
}
