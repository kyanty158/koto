# GitHub Pages 公開手順

このドキュメントでは、GitHubリポジトリの作成からGitHub Pagesでの公開までの手順を説明します。

## 1. GitHubリポジトリの作成

1. [GitHub](https://github.com)にログイン
2. 右上の「+」→「New repository」をクリック
3. 以下の設定を行います：
   - **Repository name**: `koto`
   - **Description**: 「秒メモ – メモ & リマインダー」
   - **Public/Private**: 任意（Public推奨）
   - **README、.gitignore、ライセンス**: 既存ファイルがあるためチェックを外す
4. 「Create repository」をクリック

## 2. ローカルリポジトリをGitHubにプッシュ

```bash
# プロジェクトディレクトリに移動
cd /Users/satoukanta/development/koto

# Gitリポジトリが初期化されていない場合
git init

# リモートリポジトリを追加（YOUR_USERNAMEを実際のGitHubユーザー名に置き換え）
git remote add origin https://github.com/YOUR_USERNAME/koto.git

# ファイルをステージング
git add .

# 初回コミット
git commit -m "Initial commit: Koto iOS app with GitHub Pages setup"

# mainブランチにプッシュ
git branch -M main
git push -u origin main
```

## 3. GitHub Pagesの設定

1. GitHubリポジトリのページで「Settings」タブをクリック
2. 左メニューから「Pages」を選択
3. 「Source」セクションで以下を設定：
   - **Deploy from a branch**: を選択
   - **Branch**: `main` を選択
   - **Folder**: `/docs` を選択
4. 「Save」をクリック

## 4. 公開確認

1. 数分待つ（初回のビルドには数分かかる場合があります）
2. 以下のURLにアクセスして確認：
   - ホーム: `https://YOUR_USERNAME.github.io/koto/`
   - サポート: `https://YOUR_USERNAME.github.io/koto/support`
   - プライバシーポリシー: `https://YOUR_USERNAME.github.io/koto/privacy`

## 5. アプリ内URLの更新

公開後、アプリ内で使用しているURLを更新してください：

- `Info.plist`内のURL
- アプリ内のリンクや設定画面のURL

既存のドキュメント（`docs/index.md`、`docs/support.md`）には `https://kyanty158.github.io/koto/` が記載されています。ユーザー名が異なる場合は、これらのファイル内のURLも更新してください。

## ファイル構成

GitHub Pagesで使用されるファイル：

```
docs/
├── _config.yml          # Jekyll設定ファイル
├── _layouts/
│   └── default.html     # レイアウトテンプレート
├── index.md             # ホームページ
├── support.md           # サポートページ
└── privacy.md           # プライバシーポリシーページ
```

## 更新方法

サイトを更新するには：

1. `docs/`ディレクトリ内のMarkdownファイルを編集
2. 変更をコミットしてプッシュ：
   ```bash
   git add docs/
   git commit -m "Update documentation"
   git push
   ```
3. 数分後に自動的にサイトが更新されます

## トラブルシューティング

### サイトが表示されない
- GitHub Pagesの設定で「Source」が正しく設定されているか確認
- ビルドエラーがないか「Settings」→「Pages」→「Deployments」で確認
- 数分待ってから再度アクセス

### スタイルが適用されない
- `_config.yml`と`_layouts/default.html`が正しく配置されているか確認
- ブラウザのキャッシュをクリア

### リンクが正しく動作しない
- Jekyllでは`support.md`は`/support.html`または`/support/`として公開されます
- 相対パスを使用する場合は`{{ site.baseurl }}/support`のように記述

