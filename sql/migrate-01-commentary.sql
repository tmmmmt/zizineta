-- ============================================
-- マイグレーション: ai_commentary テーブル作成 + データ投入
-- 既存の articles テーブルがある環境で実行してください
-- ============================================

-- 1. ai_commentary テーブル作成
create table if not exists ai_commentary (
  id uuid primary key default uuid_generate_v4(),
  article_id uuid not null references articles(id) on delete cascade,
  seq integer not null,
  speaker text not null check (speaker in ('A', 'B')),
  body text not null,
  created_at timestamp default now(),
  unique(article_id, seq)
);

alter table ai_commentary enable row level security;

-- ポリシーが既に存在する場合のエラーを防ぐ
do $$
begin
  if not exists (
    select 1 from pg_policies where tablename = 'ai_commentary' and policyname = 'allow_read_ai_commentary'
  ) then
    create policy "allow_read_ai_commentary"
    on ai_commentary for select to anon
    using (true);
  end if;
end
$$;

-- 2. alibaba-cloud-japan-expansion 記事を追加（未投入の場合）
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

-- 3. ai_commentary データ投入（全8記事分）

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
where a.slug = 'alibaba-cloud-japan-expansion'
on conflict (article_id, seq) do nothing;

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
where a.slug = 'chatgpt-5-released'
on conflict (article_id, seq) do nothing;

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
where a.slug = 'google-ai-search-japan'
on conflict (article_id, seq) do nothing;

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
where a.slug = 'nintendo-switch-successor'
on conflict (article_id, seq) do nothing;

-- anime-movie-10billion
insert into ai_commentary (article_id, seq, speaker, body)
select a.id, v.seq, v.speaker, v.body
from articles a
cross join lateral (values
  (0, 'A', '3週間で100億円はすごい記録だね！'),
  (1, 'B', 'SNSの口コミの力は本当に大きいよ。特にTikTokでの拡散が効いてるみたい。')
) as v(seq, speaker, body)
where a.slug = 'anime-movie-10billion'
on conflict (article_id, seq) do nothing;

-- apple-foldable-iphone
insert into ai_commentary (article_id, seq, speaker, body)
select a.id, v.seq, v.speaker, v.body
from articles a
cross join lateral (values
  (0, 'A', 'Appleもついに折りたたみに参入するんだね！'),
  (1, 'B', '後発だけど、Appleらしく完成度の高いものを出してきそうだね。')
) as v(seq, speaker, body)
where a.slug = 'apple-foldable-iphone'
on conflict (article_id, seq) do nothing;

-- threads-japan-growth
insert into ai_commentary (article_id, seq, speaker, body)
select a.id, v.seq, v.speaker, v.body
from articles a
cross join lateral (values
  (0, 'A', 'Threadsが日本でも人気出てきたんだ！'),
  (1, 'B', '独自機能で差別化できたのが大きいね。クリエイター向けの収益化も魅力的。')
) as v(seq, speaker, body)
where a.slug = 'threads-japan-growth'
on conflict (article_id, seq) do nothing;

-- remote-work-record
insert into ai_commentary (article_id, seq, speaker, body)
select a.id, v.seq, v.speaker, v.body
from articles a
cross join lateral (values
  (0, 'A', 'リモートワークがすっかり定着したんだね。'),
  (1, 'B', '柔軟な働き方が当たり前になってきた感じだね。通勤のストレスが減るのは大きいよ。')
) as v(seq, speaker, body)
where a.slug = 'remote-work-record'
on conflict (article_id, seq) do nothing;

-- 4. LATEST_NEWS 記事をarticlesテーブルに投入
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
