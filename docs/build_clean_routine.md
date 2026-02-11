# Swift開発 ビルド・クリーンルーティン

このドキュメントでは、KOTOプロジェクトでのSwift開発におけるビルドとクリーンのルーティン（作業手順）を説明します。

## プロジェクト構成

このプロジェクトは2層構造になっています：

1. **Swift Package** (`ios-native/`)
   - ライブラリパッケージ（KotoKit）
   - コアデータ、ビジネスロジック、ユニットテストを含む

2. **Xcodeプロジェクト** (`KotoApp/`)
   - iOSアプリ本体
   - Swift Packageを依存関係として使用
   - UIテストを含む

---

## ビルドルーティン

### 1. Xcodeからビルド（推奨）

#### 基本的なビルド

1. Xcodeで `KotoApp/KotoApp.xcodeproj` を開く
2. スキームで「KotoApp」を選択
3. **⌘ + B** でビルド
   - またはメニューから `Product > Build`

#### シミュレータで実行

1. シミュレータを選択（例：iPhone 15）
2. **⌘ + R** で実行
   - またはメニューから `Product > Run`

### 2. コマンドラインからビルド

#### Xcodeプロジェクトのビルド

```bash
cd /Users/satoukanta/development/koto

# クリーンビルド
xcodebuild \
  -project KotoApp/KotoApp.xcodeproj \
  -scheme KotoApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  clean build

# 通常ビルド（クリーンなし）
xcodebuild \
  -project KotoApp/KotoApp.xcodeproj \
  -scheme KotoApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
```

#### Swift Packageのビルド

```bash
cd ios-native

# ビルド
swift build

# リリースビルド（最適化）
swift build -c release
```

---

## クリーンルーティン

### 1. Xcodeからクリーン

#### 基本的なクリーン

1. Xcodeでプロジェクトを開く
2. メニューから `Product > Clean Build Folder` (**⇧⌘K**)
   - ビルドフォルダ全体を削除

#### 派生データのクリーン

1. メニューから `Product > Clean Build Folder` (**⇧⌘K**)
2. さらに完全にクリーンしたい場合：
   - Xcodeを終了
   - 以下を削除（ターミナルから）：
     ```bash
     rm -rf ~/Library/Developer/Xcode/DerivedData/KotoApp-*
     ```

### 2. コマンドラインからクリーン

#### Xcodeプロジェクトのクリーン

```bash
cd /Users/satoukanta/development/koto

# クリーン
xcodebuild \
  -project KotoApp/KotoApp.xcodeproj \
  -scheme KotoApp \
  clean

# より完全なクリーン（派生データも削除）
rm -rf ~/Library/Developer/Xcode/DerivedData/KotoApp-*
rm -rf KotoApp/build
```

#### Swift Packageのクリーン

```bash
cd ios-native

# ビルド成果物をクリーン
swift package clean

# より完全なクリーン（キャッシュも削除）
rm -rf .build
rm -rf .swiftpm
```

---

## 完全クリーンルーティン（トラブルシューティング時）

問題が発生した場合の完全クリーン手順：

```bash
cd /Users/satoukanta/development/koto

# 1. Xcodeプロジェクトのクリーン
rm -rf ~/Library/Developer/Xcode/DerivedData/KotoApp-*
rm -rf KotoApp/build
rm -rf KotoApp/KotoApp.xcodeproj/xcuserdata

# 2. Swift Packageのクリーン
cd ios-native
rm -rf .build
rm -rf .swiftpm
cd ..

# 3. Xcodeのキャッシュクリーン（オプション）
rm -rf ~/Library/Caches/com.apple.dt.Xcode
rm -rf ~/Library/Developer/Xcode/DerivedData

# 4. 再ビルド
cd ios-native
swift package resolve
cd ..
xcodebuild -project KotoApp/KotoApp.xcodeproj -scheme KotoApp clean
```

---

## テストルーティン

### Swift Packageのテスト

```bash
cd ios-native

SWIFT_MODULECACHE_PATH=.build/swift-module-cache \
CLANG_MODULE_CACHE_PATH=.build/clang-module-cache \
swift test
```

### Xcodeプロジェクトのテスト

#### Xcodeから
1. **⌘ + U** でテスト実行
   - またはメニューから `Product > Test`

#### コマンドラインから
```bash
xcodebuild \
  -project KotoApp/KotoApp.xcodeproj \
  -scheme KotoApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  test
```

---

## 日常的な開発ルーティン

### 通常の開発サイクル

1. **コード変更**
2. **⌘ + B** でビルド確認
3. **⌘ + R** でシミュレータ実行
4. **⌘ + U** でテスト実行（必要に応じて）

### 問題が発生した場合

1. **⇧⌘K** でクリーン
2. **⌘ + B** で再ビルド
3. それでも解決しない場合は「完全クリーンルーティン」を実行

### 依存関係を更新した場合

```bash
# Swift Packageの依存関係を解決
cd ios-native
swift package resolve

# Xcodeプロジェクトを開き直す（自動的に反映される）
```

---

## 便利なコマンドエイリアス（オプション）

`.zshrc` や `.bashrc` に追加すると便利：

```bash
# KOTOプロジェクトのクリーンビルド
alias koto-clean-build='cd /Users/satoukanta/development/koto && xcodebuild -project KotoApp/KotoApp.xcodeproj -scheme KotoApp -destination "platform=iOS Simulator,name=iPhone 15" clean build'

# Swift Packageのテスト
alias koto-test='cd /Users/satoukanta/development/koto/ios-native && SWIFT_MODULECACHE_PATH=.build/swift-module-cache CLANG_MODULE_CACHE_PATH=.build/clang-module-cache swift test'

# 完全クリーン
alias koto-clean-all='cd /Users/satoukanta/development/koto && rm -rf ~/Library/Developer/Xcode/DerivedData/KotoApp-* && rm -rf KotoApp/build && cd ios-native && rm -rf .build && cd ..'
```

---

## トラブルシューティング

### ビルドエラーが解決しない場合

1. 完全クリーンを実行
2. Xcodeを再起動
3. プロジェクトを再オープン
4. Swift Packageの依存関係を再解決

### シミュレータが起動しない場合

```bash
# シミュレータをリセット
xcrun simctl shutdown all
xcrun simctl erase all
```

### キャッシュの問題

```bash
# Swift Package Managerのキャッシュをクリア
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/Library/org.swift.swiftpm
```

---

## 参考情報

- [Apple Developer Documentation: Building Your App](https://developer.apple.com/documentation/xcode/building-your-app)
- [Swift Package Manager Documentation](https://www.swift.org/package-manager/)
- プロジェクトのREADME: `/Users/satoukanta/development/koto/README.md`




















