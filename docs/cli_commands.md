# CLI操作ガイド - KOTOプロジェクト

このドキュメントでは、ターミナル（CLI）から実行できるすべてのビルド・クリーン・テストコマンドをまとめています。

## 前提条件

プロジェクトのルートディレクトリ：
```bash
cd /Users/satoukanta/development/koto
```

---

## 📦 ビルドコマンド

### 1. Xcodeプロジェクトのビルド

#### 基本的なビルド
```bash
xcodebuild \
  -project KotoApp/KotoApp.xcodeproj \
  -scheme KotoApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
```

#### クリーンビルド（完全にクリーンしてからビルド）
```bash
xcodebuild \
  -project KotoApp/KotoApp.xcodeproj \
  -scheme KotoApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  clean build
```

#### リリースビルド
```bash
xcodebuild \
  -project KotoApp/KotoApp.xcodeproj \
  -scheme KotoApp \
  -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
```

#### Archive作成 & App Store Connectへアップロード（Release）
```bash
# 1. Archive作成
cd /Users/satoukanta/development/koto/KotoApp
xcodebuild \
  -project KotoApp.xcodeproj \
  -scheme KotoApp \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/KotoApp.xcarchive \
  -allowProvisioningUpdates \
  archive

# 2. ExportOptions.plist作成（初回のみ）
cat > ExportOptions.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store-connect</string>
  <key>destination</key>
  <string>upload</string>
  <key>teamID</key>
  <string>WJM784766U</string>
</dict>
</plist>
EOF

# 3. Export & App Store Connectへアップロード
xcodebuild \
  -exportArchive \
  -archivePath build/KotoApp.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/Export \
  -allowProvisioningUpdates
```

#### 利用可能なシミュレータ一覧を確認
```bash
xcrun simctl list devices available
```

#### 特定のシミュレータでビルド（例：iPhone 14）
```bash
xcodebuild \
  -project KotoApp/KotoApp.xcodeproj \
  -scheme KotoApp \
  -destination 'platform=iOS Simulator,name=iPhone 14' \
  build
```

### 2. Swift Packageのビルド

#### 基本ビルド
```bash
cd ios-native
swift build
```

#### リリースビルド（最適化）
```bash
cd ios-native
swift build -c release
```

#### 依存関係の解決とビルド
```bash
cd ios-native
swift package resolve
swift build
```

---

## 🧹 クリーンコマンド

### 1. Xcodeプロジェクトのクリーン

#### 基本的なクリーン
```bash
xcodebuild \
  -project KotoApp/KotoApp.xcodeproj \
  -scheme KotoApp \
  clean
```

#### 派生データの削除
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/KotoApp-*
```

#### プロジェクト固有のビルドフォルダ削除
```bash
rm -rf KotoApp/build
```

#### ユーザーデータの削除
```bash
rm -rf KotoApp/KotoApp.xcodeproj/xcuserdata
```

### 2. Swift Packageのクリーン

#### パッケージのクリーン
```bash
cd ios-native
swift package clean
```

#### ビルド成果物の完全削除
```bash
cd ios-native
rm -rf .build
rm -rf .swiftpm
```

### 3. 完全クリーン（すべてをクリーン）

```bash
# プロジェクトルートに移動
cd /Users/satoukanta/development/koto

# Xcodeプロジェクトのクリーン
xcodebuild -project KotoApp/KotoApp.xcodeproj -scheme KotoApp clean
rm -rf ~/Library/Developer/Xcode/DerivedData/KotoApp-*
rm -rf KotoApp/build
rm -rf KotoApp/KotoApp.xcodeproj/xcuserdata

# Swift Packageのクリーン
cd ios-native
rm -rf .build
rm -rf .swiftpm
cd ..

# オプション: Xcodeの全キャッシュをクリーン（時間がかかります）
# rm -rf ~/Library/Caches/com.apple.dt.Xcode
# rm -rf ~/Library/Developer/Xcode/DerivedData
```

---

## 🧪 テストコマンド

### 1. Swift Packageのテスト

#### 基本テスト
```bash
cd ios-native
swift test
```

#### キャッシュパスを指定したテスト（推奨）
```bash
cd ios-native
SWIFT_MODULECACHE_PATH=.build/swift-module-cache \
CLANG_MODULE_CACHE_PATH=.build/clang-module-cache \
swift test
```

#### 特定のテストのみ実行
```bash
cd ios-native
swift test --filter MemoRepositoryTests
```

#### 詳細出力でテスト実行
```bash
cd ios-native
swift test --verbose
```

### 2. Xcodeプロジェクトのテスト

#### すべてのテストを実行
```bash
xcodebuild \
  -project KotoApp/KotoApp.xcodeproj \
  -scheme KotoApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  test
```

#### クリーンしてからテスト
```bash
xcodebuild \
  -project KotoApp/KotoApp.xcodeproj \
  -scheme KotoApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  clean test
```

#### 特定のテストクラスのみ実行
```bash
xcodebuild \
  -project KotoApp/KotoApp.xcodeproj \
  -scheme KotoApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  test \
  -only-testing:KotoAppTests/テストクラス名
```

#### テスト結果をレポート形式で出力
```bash
xcodebuild \
  -project KotoApp/KotoApp.xcodeproj \
  -scheme KotoApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  test \
  -resultBundlePath ./test-results.xcresult
```

---

## 🚀 実行コマンド

### シミュレータでアプリを起動

#### ビルドして実行
```bash
xcodebuild \
  -project KotoApp/KotoApp.xcodeproj \
  -scheme KotoApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build

# ビルド後、シミュレータでアプリを起動
xcrun simctl boot "iPhone 15" 2>/dev/null || true
xcrun simctl install booted KotoApp/build/Debug-iphonesimulator/KotoApp.app
xcrun simctl launch booted com.yourcompany.KotoApp
```

#### より簡単な方法（xcodebuild run）
```bash
xcodebuild \
  -project KotoApp/KotoApp.xcodeproj \
  -scheme KotoApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build-for-testing

# シミュレータを起動してアプリをインストール
open -a Simulator
xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/KotoApp-*/Build/Products/Debug-iphonesimulator/KotoApp.app
```

---

## 🔍 便利な診断コマンド

### プロジェクト情報の確認

#### スキーム一覧
```bash
xcodebuild -project KotoApp/KotoApp.xcodeproj -list
```

#### ビルド設定の確認
```bash
xcodebuild \
  -project KotoApp/KotoApp.xcodeproj \
  -scheme KotoApp \
  -showBuildSettings
```

#### Swift Packageの依存関係を表示
```bash
cd ios-native
swift package show-dependencies
```

#### Swift Packageの解決済み依存関係を表示
```bash
cd ios-native
swift package describe --type json
```

### シミュレータ管理

#### 利用可能なシミュレータ一覧
```bash
xcrun simctl list devices
```

#### 特定のシミュレータを起動
```bash
xcrun simctl boot "iPhone 15"
open -a Simulator
```

#### すべてのシミュレータをシャットダウン
```bash
xcrun simctl shutdown all
```

#### シミュレータをリセット（データ削除）
```bash
xcrun simctl erase "iPhone 15"
```

#### すべてのシミュレータをリセット
```bash
xcrun simctl shutdown all
xcrun simctl erase all
```

---

## 📝 日常的な開発ワークフロー

### 1. コード変更後の確認フロー

```bash
# 1. ビルドしてエラーがないか確認
xcodebuild \
  -project KotoApp/KotoApp.xcodeproj \
  -scheme KotoApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build

# 2. テストを実行
cd ios-native
swift test

# 3. Xcodeプロジェクトのテストも実行（必要に応じて）
cd ..
xcodebuild \
  -project KotoApp/KotoApp.xcodeproj \
  -scheme KotoApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  test
```

### 2. ビルドエラーが発生した場合

```bash
# 1. クリーン
xcodebuild -project KotoApp/KotoApp.xcodeproj -scheme KotoApp clean

# 2. Swift Packageもクリーン
cd ios-native
swift package clean
cd ..

# 3. 再ビルド
xcodebuild \
  -project KotoApp/KotoApp.xcodeproj \
  -scheme KotoApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
```

### 3. 完全リセットが必要な場合

```bash
cd /Users/satoukanta/development/koto

# 完全クリーン
xcodebuild -project KotoApp/KotoApp.xcodeproj -scheme KotoApp clean
rm -rf ~/Library/Developer/Xcode/DerivedData/KotoApp-*
rm -rf KotoApp/build
cd ios-native
rm -rf .build
rm -rf .swiftpm
cd ..

# 依存関係を再解決
cd ios-native
swift package resolve
cd ..

# 再ビルド
xcodebuild \
  -project KotoApp/KotoApp.xcodeproj \
  -scheme KotoApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
```

---

## 🔧 ワンライナー（よく使うコマンド）

### クリーンビルド
```bash
cd /Users/satoukanta/development/koto && xcodebuild -project KotoApp/KotoApp.xcodeproj -scheme KotoApp -destination 'platform=iOS Simulator,name=iPhone 15' clean build
```

### Swift Packageテスト
```bash
cd /Users/satoukanta/development/koto/ios-native && SWIFT_MODULECACHE_PATH=.build/swift-module-cache CLANG_MODULE_CACHE_PATH=.build/clang-module-cache swift test
```

### 完全クリーン
```bash
cd /Users/satoukanta/development/koto && xcodebuild -project KotoApp/KotoApp.xcodeproj -scheme KotoApp clean && rm -rf ~/Library/Developer/Xcode/DerivedData/KotoApp-* && rm -rf KotoApp/build && cd ios-native && rm -rf .build && cd ..
```

### すべてのテストを実行
```bash
cd /Users/satoukanta/development/koto && (cd ios-native && SWIFT_MODULECACHE_PATH=.build/swift-module-cache CLANG_MODULE_CACHE_PATH=.build/clang-module-cache swift test) && xcodebuild -project KotoApp/KotoApp.xcodeproj -scheme KotoApp -destination 'platform=iOS Simulator,name=iPhone 15' test
```

---

## 🎯 シェル関数（推奨）

`.zshrc` または `.bashrc` に追加すると便利です：

```bash
# KOTOプロジェクト用の関数
koto() {
  local cmd=$1
  local dir="/Users/satoukanta/development/koto"
  
  case $cmd in
    "build")
      cd "$dir" && xcodebuild \
        -project KotoApp/KotoApp.xcodeproj \
        -scheme KotoApp \
        -destination 'platform=iOS Simulator,name=iPhone 15' \
        build
      ;;
    "clean-build")
      cd "$dir" && xcodebuild \
        -project KotoApp/KotoApp.xcodeproj \
        -scheme KotoApp \
        -destination 'platform=iOS Simulator,name=iPhone 15' \
        clean build
      ;;
    "test")
      cd "$dir/ios-native" && \
      SWIFT_MODULECACHE_PATH=.build/swift-module-cache \
      CLANG_MODULE_CACHE_PATH=.build/clang-module-cache \
      swift test
      ;;
    "test-all")
      cd "$dir/ios-native" && \
      SWIFT_MODULECACHE_PATH=.build/swift-module-cache \
      CLANG_MODULE_CACHE_PATH=.build/clang-module-cache \
      swift test && \
      cd .. && \
      xcodebuild \
        -project KotoApp/KotoApp.xcodeproj \
        -scheme KotoApp \
        -destination 'platform=iOS Simulator,name=iPhone 15' \
        test
      ;;
    "clean")
      cd "$dir" && \
      xcodebuild -project KotoApp/KotoApp.xcodeproj -scheme KotoApp clean && \
      rm -rf ~/Library/Developer/Xcode/DerivedData/KotoApp-* && \
      rm -rf KotoApp/build && \
      cd ios-native && \
      rm -rf .build && \
      cd ..
      ;;
    "clean-all")
      cd "$dir" && \
      xcodebuild -project KotoApp/KotoApp.xcodeproj -scheme KotoApp clean && \
      rm -rf ~/Library/Developer/Xcode/DerivedData/KotoApp-* && \
      rm -rf KotoApp/build && \
      rm -rf KotoApp/KotoApp.xcodeproj/xcuserdata && \
      cd ios-native && \
      rm -rf .build && \
      rm -rf .swiftpm && \
      cd ..
      ;;
    *)
      echo "使い方: koto [build|clean-build|test|test-all|clean|clean-all]"
      echo ""
      echo "  build      - 通常ビルド"
      echo "  clean-build - クリーンビルド"
      echo "  test       - Swift Packageのテスト"
      echo "  test-all   - すべてのテスト"
      echo "  clean      - クリーン"
      echo "  clean-all  - 完全クリーン"
      ;;
  esac
}
```

使用例：
```bash
koto build        # ビルド
koto clean-build  # クリーンビルド
koto test         # Swift Packageテスト
koto test-all     # すべてのテスト
koto clean        # クリーン
koto clean-all    # 完全クリーン
```

---

## 📋 クイックリファレンス表

| 操作 | コマンド |
|------|----------|
| ビルド | `xcodebuild -project KotoApp/KotoApp.xcodeproj -scheme KotoApp -destination 'platform=iOS Simulator,name=iPhone 15' build` |
| クリーンビルド | `xcodebuild ... clean build` |
| テスト | `xcodebuild ... test` |
| クリーン | `xcodebuild -project KotoApp/KotoApp.xcodeproj -scheme KotoApp clean` |
| Swift Packageテスト | `cd ios-native && swift test` |
| スキーム一覧 | `xcodebuild -project KotoApp/KotoApp.xcodeproj -list` |
| シミュレータ一覧 | `xcrun simctl list devices` |

---

## 💡 トラブルシューティング

### ビルドが失敗する場合

```bash
# 1. クリーン
koto clean

# 2. 依存関係を再解決
cd ios-native && swift package resolve && cd ..

# 3. 再ビルド
koto build
```

### テストが失敗する場合

```bash
# シミュレータをリセット
xcrun simctl shutdown all
xcrun simctl erase all

# テストを再実行
koto test-all
```

### Xcodeの派生データが問題の場合

```bash
# すべての派生データを削除（全プロジェクトに影響）
rm -rf ~/Library/Developer/Xcode/DerivedData

# または、KOTOプロジェクトのみ
rm -rf ~/Library/Developer/Xcode/DerivedData/KotoApp-*
```

---

## 参考

- [xcodebuild マニュアル](https://www.unix.com/man-page/osx/1/xcodebuild/)
- [Swift Package Manager ドキュメント](https://www.swift.org/package-manager/)
- [シミュレータコマンドリファレンス](https://www.manpagez.com/man/1/simctl/)



















