import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:koto/firebase_options.dart';
import 'package:koto/models/memo.dart';
import 'package:koto/views/view_view.dart';
import 'package:koto/views/write_view.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:koto/services/notification_service.dart';
// Removed unused selective import of Flutter types; they live in app_globals.dart
import 'package:koto/app_globals.dart';

// KPIは app_globals に移動

// Isarのインスタンスをグローバルに提供するProvider
final isarProvider = FutureProvider<Isar>((ref) async {
  final dir = await getApplicationDocumentsDirectory();
  // Isarのインスタンスを開く
  final isar = await Isar.open(
    [MemoSchema], // ここにスキーマを追加
    directory: dir.path,
  );
  return isar;
});

// 認証はMVPでは不要のため削除

Future<void> main() async {
  // main関数で非同期処理を呼び出すためのおまじない
  WidgetsFlutterBinding.ensureInitialized();
  final sw = Stopwatch()..start();

  // Firebaseの初期化
  // 一部SDKが自動検出を試みてログを出すため、明示的に最速で初期化する
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    // duplicate などは無視して継続
    debugPrint('Firebase init note: $e');
  }

  // 通知の初期化は初回フレーム描画後に遅延実行して起動をブロックしない
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await NotificationService.instance.initialize();
    } catch (e) {
      debugPrint('Notification init error: $e');
    }
  });

  debugPrint('[KPI] Init took: ${sw.elapsedMilliseconds} ms');
  kpiInitMs.value = sw.elapsedMilliseconds;

  // Sentryは Release かつ DSN が設定されているときのみ有効化
  const dsn = String.fromEnvironment('SENTRY_DSN');
  final enableSentry = kReleaseMode && dsn.isNotEmpty;
  if (enableSentry) {
    await SentryFlutter.init(
      (options) {
        options.dsn = dsn;
        options.tracesSampleRate = 1.0;
      },
      appRunner: () => runApp(const ProviderScope(child: MyApp())),
    );
  } else {
    runApp(const ProviderScope(child: MyApp()));
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // isarProviderの状態を監視
    final isar = ref.watch(isarProvider);

    return MaterialApp(
      title: 'KOTO',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      navigatorKey: navigatorKey,
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            Positioned(
              left: 8,
              top: 8,
              child: ValueListenableBuilder<int?>(
                valueListenable: kpiInitMs,
                builder: (context, val, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (val != null)
                        GestureDetector(
                          onTap: () => kpiInitMs.value = null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              // Cross-version safe: avoid deprecated withOpacity and newer withValues
                              color: const Color.fromRGBO(0, 0, 0, 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('起動: '+val.toString()+' ms',
                                style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ),
                      const SizedBox(height: 4),
                      ValueListenableBuilder<int?>(
                        valueListenable: kpiWarmMs,
                        builder: (context, warm, __) {
                          if (warm == null) return const SizedBox.shrink();
                          return GestureDetector(
                            onTap: () => kpiWarmMs.value = null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(0, 0, 0, 0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('復帰: '+warm.toString()+' ms',
                                  style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
      // isarの初期化状態に応じて表示する画面を切り替える
      home: isar.when(
        data: (_) => const HomeScreen(), // 認証不要で直接ホームへ
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      ),
    );
  }
}


/// ホーム画面（ボトムナビゲーションバーを持つ）
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_LifecycleObserver());
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_LifecycleObserver());
    super.dispose();
  }

  static const List<Widget> _widgetOptions = <Widget>[
    WriteView(),
    ViewView(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // キーボード表示時に body を自動リサイズ
      resizeToAvoidBottomInset: true,
      body: _widgetOptions.elementAt(_selectedIndex),
      // Lift bottom nav above the keyboard so it stays accessible
      bottomNavigationBar: Builder(
        builder: (ctx) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          final hasKeyboard = bottomInset > 0;
          final liftNav = hasKeyboard; // all tabs
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: liftNav ? bottomInset : 0),
            child: BottomNavigationBar(
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.edit),
                  label: '書く',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.view_list),
                  label: '見る',
                ),
              ],
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
            ),
          );
        },
      ),
    );
  }
}

class _LifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WarmKpi.start();
    }
  }
}
