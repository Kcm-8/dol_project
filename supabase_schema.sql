-- ============================================================
-- 돌려쓰기 : Supabase 스키마
-- Supabase 대시보드 > SQL Editor 에 전체를 붙여넣고 실행하세요.
-- ============================================================

create extension if not exists "pgcrypto";

-- 회원 프로필 (실명 + 익명용 별칭 + 운영자 여부)
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  anon_alias text not null,
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

-- 읽기 자료 (운영자만 추가 가능)
create table articles (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  added_by uuid references profiles(id),
  added_by_name text not null,
  created_at timestamptz not null default now()
);

-- 학생 게시글 (요약문/의견문 + 질문)
create table posts (
  id uuid primary key default gen_random_uuid(),
  article_id uuid not null references articles(id) on delete cascade,
  author_id uuid not null references profiles(id),
  author_name text not null,
  author_alias text not null,
  is_anonymous boolean not null default false,
  type text not null check (type in ('요약문','의견문')),
  content text not null,
  questions text[] not null,
  created_at timestamptz not null default now(),
  last_edit_at timestamptz
);

-- 수정 이력 (수정 전 버전 보관)
create table post_revisions (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts(id) on delete cascade,
  content text not null,
  questions text[] not null,
  created_at timestamptz not null default now()
);

-- 동료 평가 / 자기 평가
create table grades (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts(id) on delete cascade,
  grader_id uuid not null references profiles(id),
  grader_name text not null,
  grader_alias text not null,
  is_anonymous boolean not null default false,
  is_self boolean not null default false,
  scores jsonb not null,
  feedback text not null default '',
  created_at timestamptz not null default now(),
  unique (post_id, grader_id, is_self)
);

-- 토론 댓글
create table discussions (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts(id) on delete cascade,
  author_id uuid not null references profiles(id),
  author_name text not null,
  author_alias text not null,
  is_anonymous boolean not null default false,
  message text not null,
  created_at timestamptz not null default now()
);

-- ============================================================
-- Row Level Security
-- ============================================================
alter table profiles enable row level security;
alter table articles enable row level security;
alter table posts enable row level security;
alter table post_revisions enable row level security;
alter table grades enable row level security;
alter table discussions enable row level security;

-- profiles: 로그인한 사람은 누구나 읽을 수 있고(표시 이름 등 필요), 본인 행만 생성/수정
create policy "profiles_select_all" on profiles for select using (auth.role() = 'authenticated');
create policy "profiles_insert_self" on profiles for insert with check (auth.uid() = id);
create policy "profiles_update_self" on profiles for update using (auth.uid() = id);

-- articles: 누구나 읽기 가능, 운영자(is_admin=true)만 추가 가능
create policy "articles_select_all" on articles for select using (auth.role() = 'authenticated');
create policy "articles_insert_admin" on articles for insert with check (
  exists (select 1 from profiles where id = auth.uid() and is_admin = true)
);

-- posts: 누구나 읽기, 본인 글만 작성/수정
create policy "posts_select_all" on posts for select using (auth.role() = 'authenticated');
create policy "posts_insert_self" on posts for insert with check (auth.uid() = author_id);
create policy "posts_update_self" on posts for update using (auth.uid() = author_id);

-- post_revisions: 누구나 읽기, 글 작성자만 이력 추가
create policy "revisions_select_all" on post_revisions for select using (auth.role() = 'authenticated');
create policy "revisions_insert_owner" on post_revisions for insert with check (
  exists (select 1 from posts where posts.id = post_id and posts.author_id = auth.uid())
);

-- grades: 누구나 읽기, 본인이 매긴 평가만 작성/수정
create policy "grades_select_all" on grades for select using (auth.role() = 'authenticated');
create policy "grades_insert_self" on grades for insert with check (auth.uid() = grader_id);
create policy "grades_update_self" on grades for update using (auth.uid() = grader_id);

-- discussions: 누구나 읽기, 본인 댓글만 작성
create policy "discussions_select_all" on discussions for select using (auth.role() = 'authenticated');
create policy "discussions_insert_self" on discussions for insert with check (auth.uid() = author_id);

-- ============================================================
-- 운영자 지정 (김청모)
-- 1) 먼저 앱에서 '김청모' 본인이 아이디로 회원가입을 1회 완료하세요.
-- 2) 그 아이디로 아래 문장의 'YOUR_LOGIN_ID' 를 바꿔서 실행하세요.
--    (앱의 로그인 아이디는 내부적으로 'YOUR_LOGIN_ID@dolgyu.local' 이메일로 저장됩니다)
-- ============================================================
-- update profiles set is_admin = true
-- where id = (select id from auth.users where email = 'YOUR_LOGIN_ID@dolgyu.local');
