import "jsr:@supabase/functions-js/edge-runtime.d.ts"

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')!;

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const PROMPT_TEMPLATE = `あなたはニュースサイトのコメント検閲AIです。以下のコメントがサイトに投稿可能かを厳密に判定してください。

## 判定基準（1つでも該当すればNG）

### 確実にNG
- 暴言・罵倒: 「死ね」「消えろ」「ゴミ」「カス」「クズ」「きもい」「うざい」「氏ね」「タヒね」「しね」等（伏字・当て字・変換回避も含む）
- 個人攻撃: 特定の人物・ユーザーへの侮辱、人格否定
- 差別: 人種・民族・性別・障害・国籍・職業・容姿への差別や蔑視
- 脅迫・犯罪予告: 暴力の示唆、殺害予告、犯罪の教唆や助長
- 性的表現: 露骨な性的内容、セクハラ的発言
- スパム: 同じ文字・単語の無意味な繰り返し、宣伝URL、意味不明な文字列の羅列
- 煽り・荒らし: 他人を故意に不快にさせる目的の投稿、過度な挑発

### OKとするもの
- ネットスラング・ネタ: 「草」「ワロタ」「それな」「www」「笑」「ｗ」等の反応
- 顔文字・絵文字
- 批判・反対意見: 政策や出来事への批判（人格攻撃を伴わないもの）
- 皮肉・風刺: 社会的な皮肉（特定個人への攻撃でないもの）
- 短い感想: 一言コメントでも意味があればOK

## 重要な注意
- 「バカ」「アホ」等は文脈次第。特定個人への攻撃ならNG、独り言・自虐・ツッコミならOK
- 伏字（〇ね、し○等）や当て字で暴言を回避しようとしているものもNG
- 判定に迷った場合はOKにすること

## 回答形式
JSON形式のみ。他のテキストは絶対に含めないこと。
{"ok": true}
{"ok": false, "reason": "15文字以内の理由"}

## コメント:
`;

function jsonResponse(data: unknown) {
  return Response.json(data, { headers: CORS_HEADERS });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  try {
    const rawBody = new TextDecoder('utf-8').decode(await req.arrayBuffer());
    const { text } = JSON.parse(rawBody);

    if (!text || typeof text !== 'string') {
      return jsonResponse({ ok: false, reason: 'コメントが空です' });
    }
    if (text.trim().length <= 1) {
      return jsonResponse({ ok: false, reason: 'コメントが短すぎます' });
    }

    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: PROMPT_TEMPLATE + text }] }],
          generationConfig: { temperature: 0.1, maxOutputTokens: 100 },
        }),
      }
    );
    const data = await res.json();
    const responseText = data.candidates?.[0]?.content?.parts?.[0]?.text?.trim();

    if (!responseText) {
      return jsonResponse({ ok: false, reason: '検閲AIから応答がありませんでした' });
    }

    const jsonMatch = responseText.match(/\{[\s\S]*?\}/);
    if (jsonMatch) {
      return jsonResponse(JSON.parse(jsonMatch[0]));
    }
    return jsonResponse({ ok: false, reason: '検閲結果の解析に失敗しました' });
  } catch (e) {
    console.error('Moderation error:', e);
    return jsonResponse({ ok: false, reason: '検閲サービスでエラーが発生しました' });
  }
});
