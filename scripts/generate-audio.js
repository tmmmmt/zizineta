#!/usr/bin/env node
/**
 * VOICEVOX音声一括生成スクリプト
 *
 * 使い方:
 *   node scripts/generate-audio.js                    # 全記事を生成
 *   node scripts/generate-audio.js chatgpt-5-released # 特定slugのみ
 *
 * 必要:
 *   - VOICEVOX Engine起動済み (デフォルト: http://localhost:50021)
 *
 * 環境変数:
 *   VOICEVOX_URL  - エンドポイント (デフォルト: http://localhost:50021)
 *   SPEAKER_ZUNKO    - 東北ずん子のspeaker ID (デフォルト: 2)
 *   SPEAKER_ZUNDAMON - ずんだもんのspeaker ID (デフォルト: 3)
 *   SPEAKER_KIRITAN  - 東北きりたんのspeaker ID (デフォルト: 8)
 */

const fs = require('fs');
const path = require('path');

// ===== 設定 =====
const VOICEVOX_URL = process.env.VOICEVOX_URL || 'http://localhost:50021';
const SPEAKERS = {
  zunko:    Number(process.env.SPEAKER_ZUNKO)    || 2,
  zundamon: Number(process.env.SPEAKER_ZUNDAMON) || 3,
  kiritan:  Number(process.env.SPEAKER_KIRITAN)  || 8,
};

const SITE_ROOT = path.resolve(__dirname, '..');
const AUDIO_DIR = path.join(SITE_ROOT, 'assets', 'audio');
const DATA_FILE = path.join(SITE_ROOT, 'js', 'data.js');

// ===== data.jsから記事を読み込み =====
function loadArticles() {
  const code = fs.readFileSync(DATA_FILE, 'utf-8');
  // ARTICLES配列を抽出して評価
  const match = code.match(/const ARTICLES\s*=\s*(\[[\s\S]*?\n\];)/);
  if (!match) throw new Error('ARTICLESが見つかりません');

  // テンプレートリテラルのcontentをダミーに置換（evalで問題になるため）
  let arrStr = match[1];
  // contentフィールドはHTML文字列なので、音声には不要 → 簡易パース
  const fn = new Function('return ' + arrStr);
  return fn();
}

// ===== HTMLタグ除去 =====
function stripHtml(html) {
  return html.replace(/<[^>]+>/g, '').replace(/&[a-z]+;/g, ' ').trim();
}

// ===== VOICEVOX API =====
async function synthesize(text, speakerId) {
  // audio_query
  const queryRes = await fetch(
    VOICEVOX_URL + '/audio_query?text=' + encodeURIComponent(text) + '&speaker=' + speakerId,
    { method: 'POST' }
  );
  if (!queryRes.ok) throw new Error('audio_query failed: ' + queryRes.status + ' ' + await queryRes.text());
  const query = await queryRes.json();

  // synthesis
  const synthRes = await fetch(
    VOICEVOX_URL + '/synthesis?speaker=' + speakerId,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(query),
    }
  );
  if (!synthRes.ok) throw new Error('synthesis failed: ' + synthRes.status);

  return Buffer.from(await synthRes.arrayBuffer());
}

// ===== 長文を分割して合成→結合 =====
async function synthesizeLong(text, speakerId) {
  const chunks = text.split(/[。\n]+/).filter(s => s.trim());
  const buffers = [];

  for (const chunk of chunks) {
    console.log('    合成中: ' + chunk.substring(0, 30) + '...');
    const buf = await synthesize(chunk.trim() + '。', speakerId);
    buffers.push(buf);
  }

  // WAVファイルを結合（PCMデータ部分を連結）
  return concatWav(buffers);
}

// ===== WAVファイル結合 =====
function concatWav(buffers) {
  if (buffers.length === 0) return Buffer.alloc(0);
  if (buffers.length === 1) return buffers[0];

  // 最初のWAVからヘッダー情報を取得
  const header = buffers[0].slice(0, 44);
  const pcmChunks = buffers.map(buf => buf.slice(44));
  const totalPcmLen = pcmChunks.reduce((sum, b) => sum + b.length, 0);

  // ヘッダーのサイズを更新
  const newHeader = Buffer.from(header);
  newHeader.writeUInt32LE(36 + totalPcmLen, 4);  // RIFFチャンクサイズ
  newHeader.writeUInt32LE(totalPcmLen, 40);       // dataチャンクサイズ

  return Buffer.concat([newHeader, ...pcmChunks]);
}

// ===== メイン =====
async function main() {
  const targetSlug = process.argv[2]; // 特定slugのみ処理

  // VOICEVOX Engine接続確認
  try {
    const res = await fetch(VOICEVOX_URL + '/version');
    const ver = await res.text();
    console.log('VOICEVOX Engine: ' + ver);
  } catch (e) {
    console.error('エラー: VOICEVOX Engineに接続できません (' + VOICEVOX_URL + ')');
    console.error('VOICEVOX Engineを起動してください。');
    process.exit(1);
  }

  const articles = loadArticles();
  const targets = targetSlug
    ? articles.filter(a => a.slug === targetSlug)
    : articles;

  if (targets.length === 0) {
    console.error('対象記事がありません' + (targetSlug ? ': ' + targetSlug : ''));
    process.exit(1);
  }

  console.log('生成対象: ' + targets.length + '件\n');

  for (const article of targets) {
    const dir = path.join(AUDIO_DIR, article.slug);
    fs.mkdirSync(dir, { recursive: true });

    console.log('=== ' + article.slug + ' ===');

    // 記事音声（東北ずん子）
    const articlePath = path.join(dir, 'article.wav');
    if (!fs.existsSync(articlePath)) {
      console.log('  記事本文を生成中（東北ずん子）...');
      const bodyText = article.title + '。' + stripHtml(article.content);
      const wav = await synthesizeLong(bodyText, SPEAKERS.zunko);
      fs.writeFileSync(articlePath, wav);
      console.log('  → ' + articlePath);
    } else {
      console.log('  記事本文: スキップ（既に存在）');
    }

    // AI解説音声（ずんだもん/東北きりたん）
    if (article.ai_commentary) {
      for (let i = 0; i < article.ai_commentary.length; i++) {
        const commentPath = path.join(dir, 'comment-' + i + '.wav');
        if (!fs.existsSync(commentPath)) {
          const msg = article.ai_commentary[i];
          const speaker = msg.char === 'A' ? SPEAKERS.zundamon : SPEAKERS.kiritan;
          const charName = msg.char === 'A' ? 'ずんだもん' : '東北きりたん';
          console.log('  コメント' + i + 'を生成中（' + charName + '）...');
          const wav = await synthesize(msg.text, speaker);
          fs.writeFileSync(commentPath, wav);
          console.log('  → ' + commentPath);
        } else {
          console.log('  コメント' + i + ': スキップ（既に存在）');
        }
      }
    }

    console.log('');
  }

  console.log('完了！');
}

main().catch(e => {
  console.error('致命的エラー:', e);
  process.exit(1);
});
