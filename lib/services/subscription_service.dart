
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:koto/models/memo.dart';
import 'package:isar/isar.dart';

// サブスクリプション状態を表すEnum
enum SubscriptionTier { free, pro }

// サブスクリプションの状態を管理するProvider
final subscriptionProvider = StateProvider<SubscriptionTier>((ref) => SubscriptionTier.free);

class SubscriptionService {
  final Ref _ref;
  final Isar _isar;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  SubscriptionService(this._ref, this._isar);

  // FirestoreとIsarのデータを同期する
  Future<void> syncMemos() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final tier = _ref.read(subscriptionProvider);
    if (tier == SubscriptionTier.pro) {
      // Proユーザーの場合、Firestoreのデータをローカルに同期
      final snapshot = await _firestore.collection('users').doc(user.uid).collection('memos').get();
      final firestoreMemos = snapshot.docs.map((doc) => MemoFirestore.fromFirestore(doc)).toList();

      await _isar.writeTxn(() async {
        for (var memo in firestoreMemos) {
          await _isar.memos.put(memo);
        }
      });
    }
  }

  // メモを保存する（Pro版はFirestoreにも保存）
  Future<void> saveMemo(Memo memo) async {
    final user = _auth.currentUser;
    final tier = _ref.read(subscriptionProvider);

    // ローカルには常に保存
    await _isar.writeTxn(() async {
      await _isar.memos.put(memo);
    });

    // Proユーザーの場合はFirestoreにも保存
    if (tier == SubscriptionTier.pro && user != null) {
      await _firestore.collection('users').doc(user.uid).collection('memos').doc(memo.id.toString()).set(memo.toFirestore());
    }
  }

  // 機能制限をチェックする
  bool canUseFeature({required String feature}) {
    final tier = _ref.read(subscriptionProvider);
    if (tier == SubscriptionTier.pro) {
      return true; // Proは全機能OK
    }

    // 無料版の制限
    switch (feature) {
      case 'reminder':
        // TODO: リマインダー設定回数のカウントと制限ロジックを実装
        return true; // MVPでは一旦true
      case 'view_history':
        // TODO: 閲覧可能なメモ件数の制限ロジックを実装
        return true; // MVPでは一旦true
      default:
        return true;
    }
  }
}

// MemoクラスにFirestore連携用のメソッドを追加
extension MemoFirestore on Memo {
  // FirestoreのドキュメントからMemoオブジェクトを生成
  static Memo fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Memo(
      text: data['text'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAtParam: (data['updatedAt'] as Timestamp?)?.toDate() ?? (data['createdAt'] as Timestamp).toDate(),
      reminderAt: (data['reminderAt'] as Timestamp?)?.toDate(),
      isDone: (data['isDone'] as bool?) ?? false,
    )..id = int.parse(doc.id);
  }

  // MemoオブジェクトをFirestore用のMapに変換
  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'reminderAt': reminderAt != null ? Timestamp.fromDate(reminderAt!) : null,
      'isDone': isDone,
      'inlineTags': inlineTags,
    };
  }
}
