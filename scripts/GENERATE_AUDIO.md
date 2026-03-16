# 音声ファイル自動生成タスク

## 概要

ニュース記事の音声読み上げファイル（WAV）を、VOICEVOX Engineを使って生成する。
記事データはすべて `js/data.js` で管理されている。

---

## 記事データの構造（`js/data.js`）

### ARTICLES 配列

すべての記事は `js/data.js` 内の `ARTICLES` 配列に格納されている。

```js
const ARTICLES = [
  {
    id: 1,                          // 記事の一意なID（整数、重複不可）
    slug: 'chatgpt-5-released',     // URL用のスラッグ（英数字とハイフン）
    title: '記事のタイトル',
    summary: '一覧ページに表示する要約文',
    content: `<p>記事本文のHTML</p>
<p>複数段落OK。HTMLタグが使える。</p>`,
    category: 'ai',                 // カテゴリ（下記参照）
    published_at: '2026-03-11',     // 公開日（YYYY-MM-DD）
    ai_commentary: [                // AI解説（チャット形式）
      { char: 'A', text: 'ずんだもんのセリフ' },
      { char: 'B', text: '東北きりたんのセリフ' },
      { char: 'A', text: 'ずんだもんの返答' },
      { char: 'B', text: '東北きりたんの返答' },
    ],
    reactions: { red: 40, blue: 35, yellow: 25 },  // 勢力図の初期値
  },
  // ... 次の記事
];
```

### カテゴリ一覧

| category値 | 表示名 | 用途 |
|---|---|---|
| `ai` | AI | AI関連ニュース |
| `tech` | テクノロジー | 技術全般 |
| `game` | ゲーム | ゲーム関連 |
| `entame` | エンタメ | エンタメ・芸能 |
| `internet` | ネット話題 | SNS・バイラル |
| `society` | 社会 | 社会・ビジネス |

### AI解説のキャラクター

| char値 | キャラクター名 | 役割 | VOICEVOX speaker ID |
|---|---|---|---|
| `A` | ずんだもん | 質問・感想を担当（カジュアル寄り） | 3 |
| `B` | 東北きりたん | 解説・補足を担当（知識寄り） | 8 |

AI解説は `A` → `B` → `A` → `B` の交互が基本。2〜6往復程度が目安。

### 記事を新規追加する手順

1. `js/data.js` の `ARTICLES` 配列の先頭に新しいオブジェクトを追加する
2. `id` は既存の最大値+1にする
3. `slug` は英小文字・数字・ハイフンのみで、URLとして使える文字列にする
4. `content` はHTMLで記述する（`<p>` タグで段落を分ける）
5. `ai_commentary` に `char: 'A'`（ずんだもん）と `char: 'B'`（東北きりたん）のセリフを交互に入れる
6. 音声生成スクリプトを実行する

### 記事追加の例

```js
{
  id: 8,
  slug: 'example-new-article',
  title: '新しい記事のタイトル',
  summary: 'この記事の要約文。一覧ページに表示される。',
  content: `<p>記事の本文1段落目。</p>
<p>記事の本文2段落目。</p>`,
  category: 'tech',
  published_at: '2026-03-12',
  ai_commentary: [
    { char: 'A', text: 'これはすごいニュースだね！' },
    { char: 'B', text: 'そうだね。特に注目すべきポイントは3つあるよ。' },
    { char: 'A', text: '詳しく教えて！' },
    { char: 'B', text: '1つ目は〜、2つ目は〜、3つ目は〜だよ。' },
  ],
  reactions: { red: 0, blue: 0, yellow: 0 },
},
```

追加後に音声を生成：

```bash
node scripts/generate-audio.js example-new-article
```

---

## 前提条件

- VOICEVOX Engine が `http://localhost:50021` で起動していること
- Node.js が使えること

## 実行コマンド

```bash
# サイトルートに移動
cd /path/to/site

# 全記事の音声を一括生成
node scripts/generate-audio.js

# 特定の記事だけ生成する場合（slugを指定）
node scripts/generate-audio.js chatgpt-5-released
```

## 環境変数（任意）

| 変数名 | デフォルト値 | 説明 |
|---|---|---|
| `VOICEVOX_URL` | `http://localhost:50021` | VOICEVOX Engineのエンドポイント |
| `SPEAKER_ZUNKO` | `2` | 東北ずん子のspeaker ID（記事本文の読み上げ） |
| `SPEAKER_ZUNDAMON` | `3` | ずんだもんのspeaker ID（AI解説キャラA） |
| `SPEAKER_KIRITAN` | `8` | 東北きりたんのspeaker ID（AI解説キャラB） |

## 処理の流れ

1. `js/data.js` の `ARTICLES` 配列から記事データを読み込む
2. 各記事について以下の音声ファイルを生成する：
   - `assets/audio/{slug}/article.wav` — 記事タイトル＋本文を東北ずん子の声で合成
   - `assets/audio/{slug}/comment-0.wav` — AI解説の1番目のメッセージ（キャラAならずんだもん、キャラBなら東北きりたん）
   - `assets/audio/{slug}/comment-1.wav` — AI解説の2番目のメッセージ
   - 以降、AI解説の数だけ `comment-{index}.wav` を生成
3. 既に存在するファイルはスキップする（上書きしない）

## 出力先のディレクトリ構造

```
assets/audio/
├── chatgpt-5-released/
│   ├── article.wav
│   ├── comment-0.wav
│   ├── comment-1.wav
│   ├── comment-2.wav
│   └── comment-3.wav
├── google-ai-search-japan/
│   ├── article.wav
│   ├── comment-0.wav
│   └── ...
└── ...
```

## 再生成したい場合

既存のWAVファイルを削除してから再実行する。

```bash
# 特定記事の音声を再生成
rm -rf assets/audio/chatgpt-5-released
node scripts/generate-audio.js chatgpt-5-released

# 全記事の音声を再生成
rm -rf assets/audio
node scripts/generate-audio.js
```

## 記事が追加・更新されたとき

`js/data.js` に新しい記事が追加された場合、そのslugを指定して実行すれば追加分だけ生成される。

```bash
node scripts/generate-audio.js new-article-slug
```

## エラー時の対処

| エラー内容 | 原因 | 対処 |
|---|---|---|
| `VOICEVOX Engineに接続できません` | Engineが起動していない | VOICEVOX Engineを起動してから再実行 |
| `audio_query failed: 400` | テキストが空または不正 | `js/data.js` の該当記事の内容を確認 |
| `synthesis failed` | Engineの処理エラー | Engineを再起動して再実行 |
