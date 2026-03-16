-- ============================================
-- 話題ニュース解説サイト Supabase セットアップSQL
-- Supabase SQL Editor で実行してください
-- ============================================

-- UUID拡張を有効化
create extension if not exists "uuid-ossp";

-- ============================================
-- 1. articles テーブル
-- ============================================
create table articles (
  id uuid primary key default uuid_generate_v4(),
  slug text unique not null,
  title text not null,
  summary text,
  content text,
  category text,
  published_at timestamp,
  created_at timestamp default now()
);

-- articlesは誰でも読み取り可能
alter table articles enable row level security;

create policy "allow_read_articles"
on articles for select to anon
using (true);

-- ============================================
-- 2. reactions テーブル（勢力図）
-- ============================================
create table reactions (
  id uuid primary key default uuid_generate_v4(),
  article_id uuid references articles(id) on delete cascade,
  color text not null check (color in ('red', 'blue', 'yellow')),
  created_at timestamp default now()
);

alter table reactions enable row level security;

create policy "allow_insert_reactions"
on reactions for insert to anon
with check (true);

create policy "allow_read_reactions"
on reactions for select to anon
using (true);

-- ============================================
-- 3. comments テーブル
-- ============================================
create table comments (
  id uuid primary key default uuid_generate_v4(),
  article_id uuid references articles(id) on delete cascade,
  color text not null check (color in ('red', 'blue', 'yellow')),
  comment text not null,
  good integer default 0,
  bad integer default 0,
  created_at timestamp default now()
);

alter table comments
add constraint comment_length
check (char_length(comment) <= 200);

alter table comments enable row level security;

create policy "allow_insert_comments"
on comments for insert to anon
with check (true);

create policy "allow_read_comments"
on comments for select to anon
using (true);

-- good/bad更新用ポリシー（anon から update を許可）
create policy "allow_update_comments_votes"
on comments for update to anon
using (true)
with check (true);

-- ============================================
-- 4. good / bad 投票関数
-- ============================================
create or replace function vote_comment(
  comment_uuid uuid,
  vote_type text
)
returns void
language plpgsql
security definer
as $$
begin
  if vote_type = 'good' then
    update comments
    set good = good + 1
    where id = comment_uuid;
  elsif vote_type = 'bad' then
    update comments
    set bad = bad + 1
    where id = comment_uuid;
  end if;
end;
$$;

-- ============================================
-- 5. 勢力図集計ビュー
-- ============================================
create view reaction_stats as
select
  article_id,
  count(*) filter (where color = 'red') as red,
  count(*) filter (where color = 'blue') as blue,
  count(*) filter (where color = 'yellow') as yellow
from reactions
group by article_id;

-- ============================================
-- 6. 最新コメント取得ビュー
-- ============================================
create view article_comments as
select
  id,
  article_id,
  color,
  comment,
  good,
  bad,
  created_at
from comments
order by created_at desc;

-- ============================================
-- 7. サンプル記事データ投入
-- ============================================
-- ============================================
-- 6.5 ai_commentary テーブル（対話式解説）
-- ============================================
create table ai_commentary (
  id uuid primary key default uuid_generate_v4(),
  article_id uuid not null references articles(id) on delete cascade,
  seq integer not null,
  speaker text not null check (speaker in ('A', 'B')),
  body text not null,
  created_at timestamp default now(),
  unique(article_id, seq)
);

alter table ai_commentary enable row level security;

create policy "allow_read_ai_commentary"
on ai_commentary for select to anon
using (true);

-- ============================================
-- 7. サンプル記事データ投入
-- ============================================
insert into articles (slug, title, summary, content, category, published_at) values
(
  'chatgpt-5-released',
  'ChatGPT-5が公開 ― AIの性能が飛躍的に向上、業界に衝撃',
  'OpenAIが最新モデル「GPT-5」を発表。推論能力や多言語対応が大幅に強化され、プログラミング支援や創作分野での活用が一気に広がると注目されている。',
  '<p>OpenAIが最新の大規模言語モデル「GPT-5」を正式に発表しました。</p><p>今回のモデルは従来のGPT-4oと比較して、推論能力が大幅に向上。特に数学的推論、コーディング支援、多言語翻訳の精度が飛躍的に改善されています。</p><p>専門家は「AIの実用性がさらに一段階上がった」と評価しており、企業での導入がさらに加速すると見られています。</p><p>一方で、AIの急速な進化に対する規制議論も再燃。各国政府はAI安全性に関する新たなガイドラインの策定を急いでいます。</p>',
  'ai',
  '2026-03-11'
),
(
  'google-ai-search-japan',
  'Google、新AI検索機能を日本で提供開始',
  '検索結果をAIが要約する新機能が日本語に対応。情報収集の形が変わる。',
  '<p>Googleは、AI検索機能「AI Overviews」を日本市場で正式に提供開始しました。</p><p>この機能は検索クエリに対してAIが関連情報を収集・要約し、検索結果ページの上部に表示するものです。</p><p>日本語の自然な文章生成にも対応しており、質問形式のクエリで特に有効です。</p>',
  'ai',
  '2026-03-11'
),
(
  'nintendo-switch-successor',
  'Nintendo Switch 後継機の発売日が決定',
  '任天堂が次世代機の詳細を公開。ローンチタイトルにも注目が集まる。',
  '<p>任天堂は、Nintendo Switchの後継機となる新型ゲーム機の発売日を正式に発表しました。</p><p>新型機は4Kディスプレイ出力に対応し、処理性能が大幅に向上。後方互換性も備えています。</p><p>ローンチタイトルには大作が複数用意されており、予約開始直後から注文が殺到しています。</p>',
  'game',
  '2026-03-10'
),
(
  'anime-movie-10billion',
  '人気アニメ映画が興収100億円を突破',
  '公開3週間で大台に到達。SNSでの口コミが動員を後押し。',
  '<p>今年最大の話題作となっているアニメ映画が、公開からわずか3週間で興行収入100億円を突破しました。</p><p>SNSでの口コミ効果が大きく、リピーターも多いことが特徴です。</p>',
  'entame',
  '2026-03-09'
),
(
  'apple-foldable-iphone',
  'Apple、折りたたみiPhoneを年内発売か',
  '複数のリーク情報が一致。ディスプレイ技術に新方式を採用との噂。',
  '<p>Appleが折りたたみ式iPhoneを年内に発売する可能性が高まっています。</p><p>複数の信頼できるリーカーからの情報が一致しており、新しい折り目が見えにくいディスプレイ技術を採用するとされています。</p>',
  'tech',
  '2026-03-08'
),
(
  'threads-japan-growth',
  '新SNS「Threads」が日本でユーザー急増',
  '独自機能の追加で差別化に成功。若年層の利用が特に増加。',
  '<p>Metaが運営するSNS「Threads」が日本で急速にユーザー数を伸ばしています。</p><p>独自のアルゴリズムによるおすすめ機能や、クリエイター向けの収益化プログラムの導入により、差別化に成功。</p>',
  'internet',
  '2026-03-07'
),
(
  'remote-work-record',
  'リモートワーク定着率が過去最高を記録',
  '企業の7割以上がハイブリッド勤務を継続。働き方改革が加速。',
  '<p>最新の調査によると、リモートワークの定着率が過去最高を更新しました。</p><p>調査対象企業の7割以上がハイブリッド勤務を継続しており、完全出社に戻す企業は少数派となっています。</p>',
  'society',
  '2026-03-06'
);

-- alibaba-cloud-japan-expansion（setup.sqlには未投入だったので追加）
insert into articles (slug, title, summary, content, category, published_at) values
(
  'alibaba-cloud-japan-expansion',
  'アリババクラウド、日本での人員とパートナーを大幅拡大へ',
  '中国アリババ集団傘下のAlibaba Cloudが、2029年までに日本国内のサービス人員を2.5倍、パートナー企業を100社に増やす方針を発表しました。',
  '<p>日経クロステックの報道によると、中国アリババ集団傘下のクラウドコンピューティング部門である「Alibaba Cloud（アリババクラウド）」は、2026年3月11日、日本市場における事業の大幅な拡大方針を発表しました。</p><p>具体的には、2029年までに日本国内のサービス担当人員を現在の2.5倍に増員し、パートナー企業を100社規模へと拡大する計画です。生成AI（人工知能）の需要が高まる中、アジアを基盤とするクラウドインフラの競争が日本国内でもさらに激化することが予想されます。</p>',
  'tech',
  '2026-03-12'
)
on conflict (slug) do nothing;

-- ============================================
-- 8. ai_commentary データ投入（全8記事分）
-- ============================================

-- alibaba-cloud-japan-expansion
insert into ai_commentary (article_id, seq, speaker, body)
select a.id, v.seq, v.speaker, v.body
from articles a
cross join lateral (values
  (0, 'A', 'アリババクラウドが日本でめちゃくちゃ人を増やすらしいのだ！'),
  (1, 'B', 'AmazonのAWSやMicrosoftのAzureといったアメリカのクラウドサービスに対抗する狙いがありそうですね。'),
  (2, 'A', '中国のクラウドって日本でも使われてるのだ？'),
  (3, 'B', 'はい。特にアジア圏での越境ECや、中国向けにビジネスを展開する日本企業には欠かせないインフラになっていますよ。'),
  (4, 'A', 'なるほどなのだ！AIブームでクラウドの場所の取り合いが激しくなってるのだ！')
) as v(seq, speaker, body)
where a.slug = 'alibaba-cloud-japan-expansion';

-- chatgpt-5-released
insert into ai_commentary (article_id, seq, speaker, body)
select a.id, v.seq, v.speaker, v.body
from articles a
cross join lateral (values
  (0, 'A', '新しいGPT-5が出たね！今回はかなりパワーアップしてるみたい。'),
  (1, 'B', 'そうだね。特に推論能力が上がったのが大きいよ。数学の問題もかなり正確に解けるようになったらしい。'),
  (2, 'A', 'プログラミングの支援もすごく良くなったって聞いたけど、エンジニアの仕事に影響あるのかな？'),
  (3, 'B', 'AIはあくまでツールだから、使いこなせるエンジニアの価値がむしろ上がると思うよ。ただ規制の議論は大事だね。')
) as v(seq, speaker, body)
where a.slug = 'chatgpt-5-released';

-- google-ai-search-japan
insert into ai_commentary (article_id, seq, speaker, body)
select a.id, v.seq, v.speaker, v.body
from articles a
cross join lateral (values
  (0, 'A', 'Google検索がAIで要約してくれるようになったんだ！'),
  (1, 'B', 'うん、日本語にもちゃんと対応してるから使いやすそうだよね。'),
  (2, 'A', 'でもサイトへのアクセスが減っちゃうかも？'),
  (3, 'B', 'それは確かに課題だね。コンテンツ制作者への影響は注視していく必要があるよ。')
) as v(seq, speaker, body)
where a.slug = 'google-ai-search-japan';

-- nintendo-switch-successor
insert into ai_commentary (article_id, seq, speaker, body)
select a.id, v.seq, v.speaker, v.body
from articles a
cross join lateral (values
  (0, 'A', 'ついにSwitch後継機の発売日が決まったね！'),
  (1, 'B', '4K対応で後方互換もあるのはすごいよね。既存ソフトが使えるのは嬉しい。'),
  (2, 'A', 'ローンチタイトルも気になるなぁ。'),
  (3, 'B', '大作が複数あるみたいだから、発売日から楽しめそうだよ。')
) as v(seq, speaker, body)
where a.slug = 'nintendo-switch-successor';

-- anime-movie-10billion
insert into ai_commentary (article_id, seq, speaker, body)
select a.id, v.seq, v.speaker, v.body
from articles a
cross join lateral (values
  (0, 'A', '3週間で100億円はすごい記録だね！'),
  (1, 'B', 'SNSの口コミの力は本当に大きいよ。特にTikTokでの拡散が効いてるみたい。')
) as v(seq, speaker, body)
where a.slug = 'anime-movie-10billion';

-- apple-foldable-iphone
insert into ai_commentary (article_id, seq, speaker, body)
select a.id, v.seq, v.speaker, v.body
from articles a
cross join lateral (values
  (0, 'A', 'Appleもついに折りたたみに参入するんだね！'),
  (1, 'B', '後発だけど、Appleらしく完成度の高いものを出してきそうだね。')
) as v(seq, speaker, body)
where a.slug = 'apple-foldable-iphone';

-- threads-japan-growth
insert into ai_commentary (article_id, seq, speaker, body)
select a.id, v.seq, v.speaker, v.body
from articles a
cross join lateral (values
  (0, 'A', 'Threadsが日本でも人気出てきたんだ！'),
  (1, 'B', '独自機能で差別化できたのが大きいね。クリエイター向けの収益化も魅力的。')
) as v(seq, speaker, body)
where a.slug = 'threads-japan-growth';

-- remote-work-record
insert into ai_commentary (article_id, seq, speaker, body)
select a.id, v.seq, v.speaker, v.body
from articles a
cross join lateral (values
  (0, 'A', 'リモートワークがすっかり定着したんだね。'),
  (1, 'B', '柔軟な働き方が当たり前になってきた感じだね。通勤のストレスが減るのは大きいよ。')
) as v(seq, speaker, body)
where a.slug = 'remote-work-record';

-- ============================================
-- 9. LATEST_NEWS 記事をarticlesテーブルに投入
-- ============================================
insert into articles (slug, title, summary, category, published_at) values
  ('ai-education-future', 'AIと教育の未来 ― 学校現場での活用事例が拡大', '', 'ai', '2026-03-11'),
  ('openworld-rpg-hit', '新作オープンワールドRPGが全世界で大ヒット', '', 'game', '2026-03-10'),
  ('next-gen-battery', '次世代バッテリー技術、EV航続距離が2倍に', '', 'tech', '2026-03-09'),
  ('seiyuu-youtube-5m', '人気声優のYouTubeチャンネル登録者が500万人突破', '', 'entame', '2026-03-08'),
  ('viral-cat-video', 'バズった猫動画の裏側 ― 飼い主に聞いた撮影秘話', '', 'internet', '2026-03-07'),
  ('ai-music-service', 'AI作曲サービスが音楽業界に波紋', '', 'ai', '2026-03-06'),
  ('sidejob-skillshare', '副業解禁企業が増加、スキルシェア市場が拡大', '', 'society', '2026-03-05'),
  ('quantum-computing', '量子コンピュータの実用化に向けた新たな成果', '', 'tech', '2026-03-04'),
  ('esports-japan', 'eスポーツ世界大会、日本チームが準優勝の快挙', '', 'game', '2026-03-03'),
  ('ai-short-film', 'AIで生成した短編映画がSNSで話題に', '', 'internet', '2026-03-02')
on conflict (slug) do nothing;
