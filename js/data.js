// カテゴリ表示名マッピング
const CATEGORY_MAP = {
  ai: { label: 'AI', tagClass: 'tag-ai' },
  tech: { label: 'テクノロジー', tagClass: 'tag-tech' },
  game: { label: 'ゲーム', tagClass: 'tag-game' },
  entame: { label: 'エンタメ', tagClass: 'tag-entame' },
  internet: { label: 'ネット話題', tagClass: 'tag-internet' },
  society: { label: '社会', tagClass: 'tag-society' },
};

// ユーティリティ
function formatDate(dateStr) {
  const d = new Date(dateStr);
  return `${d.getFullYear()}.${String(d.getMonth() + 1).padStart(2, '0')}.${String(d.getDate()).padStart(2, '0')}`;
}

function getCategoryTag(category) {
  const cat = CATEGORY_MAP[category];
  if (!cat) return '';
  return `<span class="article-category ${cat.tagClass}">${cat.label}</span>`;
}
