-- migrate-02-extra-colors.sql
-- コメント・リアクションテーブルに新色（green, purple, pink）を許可する
-- + votes テーブルの pts カラム追加（既存テーブルに不足している場合）

-- votes テーブルに pts カラムが無ければ追加
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'votes' AND column_name = 'pts'
  ) THEN
    ALTER TABLE votes ADD COLUMN pts integer NOT NULL DEFAULT 0;
  END IF;
END $$;

-- comments テーブルの color 制約を更新
ALTER TABLE comments DROP CONSTRAINT IF EXISTS comments_color_check;
ALTER TABLE comments ADD CONSTRAINT comments_color_check
  CHECK (color IN ('red', 'blue', 'yellow', 'green', 'purple', 'pink'));

-- reactions テーブルの color 制約を更新
ALTER TABLE reactions DROP CONSTRAINT IF EXISTS reactions_color_check;
ALTER TABLE reactions ADD CONSTRAINT reactions_color_check
  CHECK (color IN ('red', 'blue', 'yellow', 'green', 'purple', 'pink'));
