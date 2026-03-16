-- ============================================
-- 投票ロジック 追加スキーマ
-- ============================================

-- 1. ユーザープロフィール（ポイント管理）
create table if not exists profiles (
  id uuid primary key, -- フロントエンドで生成した voter_id
  pts integer default 0,
  created_at timestamp default now()
);

-- RLS設定
alter table profiles enable row level security;
drop policy if exists "allow_anon_insert_profiles" on profiles;
drop policy if exists "allow_anon_read_profiles" on profiles;
drop policy if exists "allow_anon_update_profiles" on profiles;
create policy "allow_anon_insert_profiles" on profiles for insert to anon with check (true);
create policy "allow_anon_read_profiles" on profiles for select to anon using (true);
create policy "allow_anon_update_profiles" on profiles for update to anon using (true);

-- 2. コメントテーブルに投稿者IDを追加
do $$ 
begin 
  if not exists (select 1 from information_schema.columns where table_name='comments' and column_name='voter_id') then
    alter table comments add column voter_id uuid references profiles(id);
  end if;
end $$;

-- 3. 投票履歴テーブル（重複投票防止、重み記録）
create table if not exists votes (
  id uuid primary key default uuid_generate_v4(),
  comment_id uuid references comments(id) on delete cascade,
  voter_id uuid references profiles(id) on delete cascade,
  vote_type text check (vote_type in ('good', 'bad')),
  pts integer not null default 0, -- 投票時の重み
  created_at timestamp default now(),
  unique(comment_id, voter_id)
);

-- RLS設定
alter table votes enable row level security;
drop policy if exists "allow_anon_insert_votes" on votes;
drop policy if exists "allow_anon_read_votes" on votes;
create policy "allow_anon_insert_votes" on votes for insert to anon with check (true);
create policy "allow_anon_read_votes" on votes for select to anon using (true);

-- 4. 投票関数（更新版：ポイント消費制）
-- 古い関数を削除
drop function if exists vote_comment(uuid, uuid, text);

create or replace function vote_comment(
  p_comment_id uuid,
  p_voter_id uuid,
  p_vote_type text
)
returns void
language plpgsql
security definer
as $$
declare
  v_author_id uuid;
  v_voter_pts integer;
begin
  -- 1. 重複投票チェック
  if exists (select 1 from votes where comment_id = p_comment_id and voter_id = p_voter_id) then
    raise exception '既にこのコメントに投票済みです';
  end if;

  -- 2. 投稿者取得
  select voter_id into v_author_id from comments where id = p_comment_id;

  -- 3. 自己投票チェック
  if v_author_id = p_voter_id then
    raise exception '自分のコメントには投票できません';
  end if;

  -- 4. 投票者の保持ポイント取得
  select pts into v_voter_pts from profiles where id = p_voter_id;
  
  if v_voter_pts is null or v_voter_pts <= 0 then
    raise exception '投票にはポイントが必要です';
  end if;

  -- 5. 投票記録（消費ポイントを保存）
  insert into votes (comment_id, voter_id, vote_type, pts)
  values (p_comment_id, p_voter_id, p_vote_type, v_voter_pts);

  -- 6. ポイント消費
  update profiles set pts = 0 where id = p_voter_id;

  -- 7. コメントのカウント更新（ポイント分加算）
  if p_vote_type = 'good' then
    update comments set good = good + v_voter_pts where id = p_comment_id;
    -- 投稿者に1pt付与（おまけ）
    if v_author_id is not null then
      update profiles set pts = pts + 1 where id = v_author_id;
    end if;
  elsif p_vote_type = 'bad' then
    -- Badは一律 +1 ではなく points 分加算する仕様とする（管理の厳格化）
    -- 10 pts で削除であれば、3pt持つ人が投票すれば 3/10 溜まるイメージ
    update comments set bad = bad + v_voter_pts where id = p_comment_id;
  end if;
end;
$$;

-- 5. ポイント付与関数（汎用）
create or replace function add_points(
  p_user_id uuid,
  p_amount integer
)
returns void
language plpgsql
security definer
as $$
begin
  -- プロフィールが存在しない場合は作成（保険）
  insert into profiles (id, pts)
  values (p_user_id, p_amount)
  on conflict (id) do update
  set pts = profiles.pts + p_amount;
end;
$$;

-- 5.5 ポイントリセット関数
create or replace function reset_points(
  p_user_id uuid
)
returns void
language plpgsql
security definer
as $$
begin
  update profiles set pts = 0 where id = p_user_id;
end;
$$;

-- 6. 最新コメントビュー（voter_idを含めるように更新）
drop view if exists article_comments;
create or replace view article_comments as
select
  id,
  article_id,
  color,
  comment,
  good,
  bad,
  voter_id,
  created_at
from comments
order by created_at desc;
