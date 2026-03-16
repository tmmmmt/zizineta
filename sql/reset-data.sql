-- ============================================
-- データのみリセット（スキーマは維持）
-- 外部キー制約の順序に従って削除
-- ============================================

truncate votes, reactions, ai_commentary, comments, articles, profiles
  restart identity cascade;
