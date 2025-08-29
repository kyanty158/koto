
import 'package:isar/isar.dart';

part 'memo.g.dart'; // Isarが自動生成するファイル

@collection
class Memo {
  Id id = Isar.autoIncrement; // 自動インクリメントされるID

  @Index(caseSensitive: false)
  String text; // メモの本文

  @Index()
  DateTime createdAt; // 作成日時（UTC推奨）

  @Index()
  DateTime updatedAt; // 更新日時（UTC推奨）

  @Index()
  DateTime? reminderAt; // リマインダー設定時刻（null許容, UTC推奨）

  bool isDone; // 完了フラグ

  // インライン #タグを抽出して保持（将来の検索最適化用）
  @Index(type: IndexType.hash, caseSensitive: false)
  List<String> inlineTags = [];

  Memo({
    required this.text,
    required this.createdAt,
    DateTime? updatedAtParam,
    this.reminderAt,
    this.isDone = false,
  }) : updatedAt = updatedAtParam ?? createdAt;
}
