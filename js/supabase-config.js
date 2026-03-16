// ============================================
// Supabase 設定
// ============================================

var SUPABASE_URL = 'https://ilfsrjgxmvkxlgjmjvyd.supabase.co';
var SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlsZnNyamd4bXZreGxnam1qdnlkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMyMTY4NzUsImV4cCI6MjA4ODc5Mjg3NX0.RhCN9JMB-VHOmORyEyL2eeQoLQD0vfDXFCR03Zwy4is';

var isSupabaseConfigured = SUPABASE_URL !== '' && SUPABASE_ANON_KEY !== '';

// Supabase クライアント
var supabaseClient = null;

if (isSupabaseConfigured && window.supabase && window.supabase.createClient) {
  try {
    supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  } catch (e) {
    console.error('Supabase初期化エラー:', e.message);
  }
}

// ============================================
// ユーザー識別 (Voter ID)
// ============================================

function getVoterId() {
  var id = localStorage.getItem('voter_id');
  // UUID形式かチェック (例: 550e8400-e29b-41d4-a716-446655440000)
  var uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  
  if (!id || !uuidRegex.test(id)) {
    if (crypto.randomUUID) {
      id = crypto.randomUUID();
    } else {
      id = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
      });
    }
    localStorage.setItem('voter_id', id);
    console.log('New Voter ID generated:', id);
  }
  return id;
}

// プロフィールを自動作成（初回のみ）
async function ensureProfile() {
  if (!supabaseClient) return;
  var voterId = getVoterId();
  var { data, error } = await supabaseClient
    .from('profiles')
    .select('id')
    .eq('id', voterId)
    .maybeSingle();
  
  if (!data && !error) {
    await supabaseClient.from('profiles').insert([{ id: voterId, pts: 0 }]);
  }
}

// 起動時にプロフィール確認
if (supabaseClient) {
  ensureProfile();
}

// ============================================
// API 関数
// ============================================

async function fetchArticles() {
  if (!supabaseClient) return [];

  var { data, error } = await supabaseClient
    .from('articles')
    .select('*')
    .order('published_at', { ascending: false });

  if (error) {
    console.error('articles取得エラー:', error.message);
    return [];
  }
  return data;
}

async function fetchArticleBySlug(slug) {
  if (!supabaseClient) return null;

  var { data, error } = await supabaseClient
    .from('articles')
    .select('*')
    .eq('slug', slug)
    .single();

  if (error) {
    console.error('記事取得エラー:', error.message);
    return null;
  }
  return data;
}

async function fetchAiCommentary(articleId) {
  if (!supabaseClient) return [];

  var { data, error } = await supabaseClient
    .from('ai_commentary')
    .select('speaker, body')
    .eq('article_id', articleId)
    .order('seq', { ascending: true });

  if (error || !data) {
    console.error('AI解説取得エラー:', error ? error.message : '');
    return [];
  }

  return data.map(function(row) {
    return { char: row.speaker, text: row.body };
  });
}

async function fetchReactions(articleId) {
  if (!supabaseClient) return { red: 0, blue: 0, yellow: 0 };

  var { data, error } = await supabaseClient
    .from('reaction_stats')
    .select('*')
    .eq('article_id', articleId)
    .maybeSingle();

  if (error) {
    console.error('勢力図取得エラー:', error.message);
    return { red: 0, blue: 0, yellow: 0 };
  }
  if (!data) return { red: 0, blue: 0, yellow: 0 };
  return { red: Number(data.red), blue: Number(data.blue), yellow: Number(data.yellow) };
}

async function postReaction(articleId, color) {
  if (!supabaseClient) return { ok: false, error: 'Supabase未接続' };

  var { error } = await supabaseClient
    .from('reactions')
    .insert([{ article_id: articleId, color: color }]);

  if (error) {
    console.error('勢力図投票エラー:', error.message);
    return { ok: false, error: error.message };
  }
  return { ok: true };
}

async function fetchComments(articleId) {
  if (!supabaseClient) return [];

  var { data, error } = await supabaseClient
    .from('article_comments')
    .select('*')
    .eq('article_id', articleId)
    .limit(100);

  if (error) {
    console.error('コメント取得エラー:', error.message);
    return [];
  }
  return data;
}

async function postComment(articleId, color, comment) {
  if (!supabaseClient) return { ok: false, error: 'Supabase未接続' };

  // 確実にプロフィールが存在するようにする
  await ensureProfile();

  var voterId = getVoterId();
  var { data, error } = await supabaseClient
    .from('comments')
    .insert([{
      article_id: articleId,
      color: color,
      comment: comment,
      voter_id: voterId
    }])
    .select()
    .single();

  if (error) {
    console.error('コメント投稿エラー:', error.message);
    return { ok: false, error: error.message };
  }

  // 投稿完了で +3pt 付与
  await addPoints(3);

  return { ok: true, data: data };
}

async function voteComment(commentId, voteType) {
  if (!supabaseClient) return { ok: false, error: 'Supabase未接続' };

  var voterId = getVoterId();
  var { error } = await supabaseClient
    .rpc('vote_comment', { 
      p_comment_id: commentId, 
      p_voter_id: voterId,
      p_vote_type: voteType 
    });

  if (error) {
    console.error('投票エラー:', error.message);
    return { ok: false, error: error.message };
  }
  return { ok: true };
}

// ============================================
// コメントAI検閲
// ============================================

async function moderateComment(text) {
  // 1文字以下は即ブロック（API呼び出し不要）
  if (text.trim().length <= 1) {
    return { ok: false, reason: 'コメントが短すぎます' };
  }
  if (!supabaseClient) {
    console.warn('AI検閲: supabaseClient未接続のためブロック');
    return { ok: false, reason: '検閲サービスに接続できません' };
  }

  try {
    var { data, error } = await supabaseClient.functions.invoke('moderate-comment', {
      body: { text: text }
    });
    console.log('AI検閲レスポンス:', { data: data, error: error });
    if (error) {
      console.error('AI検閲エラー:', error);
      return { ok: false, reason: '検閲サービスでエラーが発生しました' };
    }
    // dataが文字列の場合はパースする
    if (typeof data === 'string') {
      try {
        data = JSON.parse(data);
      } catch (e) {
        console.error('AI検閲: レスポンスのパースに失敗:', data);
        return { ok: false, reason: '検閲結果の取得に失敗しました' };
      }
    }
    if (data && typeof data.ok !== 'undefined') {
      return data;
    }
    console.warn('AI検閲: 想定外のレスポンス形式:', data);
    return { ok: false, reason: '検閲結果の取得に失敗しました' };
  } catch (e) {
    console.error('AI検閲エラー:', e);
    return { ok: false, reason: '検閲サービスに接続できません' };
  }
}

// ============================================
// ポイント関連
// ============================================

async function fetchUserPoints() {
  if (!supabaseClient) return 0;
  var voterId = getVoterId();
  var { data, error } = await supabaseClient
    .from('profiles')
    .select('pts')
    .eq('id', voterId)
    .maybeSingle();

  if (error || !data) return 0;
  return data.pts;
}

async function addPoints(amount) {
  if (!supabaseClient) return;
  var voterId = getVoterId();
  var { error } = await supabaseClient
    .rpc('add_points', { 
      p_user_id: voterId, 
      p_amount: amount 
    });

  if (error) {
    console.error('ポイント付与エラー:', error.message);
  }
}

async function resetPoints() {
  if (!supabaseClient) return;
  var voterId = getVoterId();
  var { error } = await supabaseClient
    .rpc('reset_points', { 
      p_user_id: voterId
    });

  if (error) {
    console.error('ポイントリセットエラー:', error.message);
  }
}
