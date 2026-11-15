-- =====================================================================
-- ENGLISH MASTER (english-master.html) uchun baza.
-- Supabase SQL Editor'da BUTUNLAY ishga tushiring. Qayta ishga tushirish xavfsiz (eski versiyani yangilaydi).
-- Faqat shu fayl kerak (database.sql — katta ko'p-fayl loyiha uchun, ikkalasini aralashtirmang).
-- =====================================================================

create table if not exists public.em_profiles(
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9_]{3,20}$'),
  name text not null,
  email text,
  prov text, city text,
  photo text not null default '' check (length(photo) < 80000),
  role text not null default 'student',
  banned boolean not null default false,
  xp int not null default 0 check (xp >= 0),
  streak int not null default 0,
  last_day text not null default '',
  secs int not null default 0,
  done jsonb not null default '{}',
  scores jsonb not null default '{}',
  saved jsonb not null default '[]',
  writing jsonb not null default '{}',
  log jsonb not null default '{}',
  created_at timestamptz not null default now()
);
-- eski versiyadan yangilash
alter table public.em_profiles add column if not exists premium_until timestamptz;
alter table public.em_profiles add column if not exists free_pass boolean not null default false;
alter table public.em_profiles add column if not exists banned boolean not null default false;
alter table public.em_profiles add column if not exists start_lv text not null default 'pre-a1';
alter table public.em_profiles drop constraint if exists em_profiles_start_lv_check;
alter table public.em_profiles add constraint em_profiles_start_lv_check check (start_lv in ('pre-a1','a1','a2','b1','b2','c1','c2'));
alter table public.em_profiles drop constraint if exists em_profiles_role_check;
alter table public.em_profiles add constraint em_profiles_role_check check (role in ('owner','admin','teacher','student'));
-- Faqat BITTA ega bo'la oladi
create unique index if not exists em_one_owner on public.em_profiles(role) where role = 'owner';

alter table public.em_profiles enable row level security;

create or replace function public.em_is_owner() returns boolean language sql stable security definer set search_path = public as
$$ select exists(select 1 from public.em_profiles where id = auth.uid() and role = 'owner' and not banned) $$;
create or replace function public.em_is_staff() returns boolean language sql stable security definer set search_path = public as
$$ select exists(select 1 from public.em_profiles where id = auth.uid() and role in ('owner','admin') and not banned) $$;

drop policy if exists em_select_own on public.em_profiles;
drop policy if exists em_update_own on public.em_profiles;
drop policy if exists em_delete_owner on public.em_profiles;
create or replace function public.em_can_teach() returns boolean language sql stable security definer set search_path = public as
$$ select exists(select 1 from public.em_profiles where id = auth.uid() and role in ('owner','admin','teacher') and not banned) $$;

create policy em_select_own on public.em_profiles for select to authenticated using (id = auth.uid() or public.em_is_staff());
create policy em_update_own on public.em_profiles for update to authenticated using (id = auth.uid() or public.em_is_staff()) with check (id = auth.uid() or public.em_is_staff());
create policy em_delete_owner on public.em_profiles for delete to authenticated using (public.em_is_owner() and role <> 'owner');
-- INSERT siyosati yo'q: profil faqat quyidagi trigger orqali yaratiladi.

-- Rol, email, username o'zgarmaydi; "banned" ni faqat ega/administrator o'zgartira oladi
create or replace function public.em_protect() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if current_setting('app.bypass', true) = '1' or auth.uid() is null then return new; end if;
  new.id := old.id; new.role := old.role; new.email := old.email; new.username := old.username;
  if not public.em_is_staff() then new.banned := old.banned; end if;
  if not public.em_is_owner() then new.premium_until := old.premium_until; new.free_pass := old.free_pass; end if;
  return new;
end $$;
drop trigger if exists em_protect_trg on public.em_profiles;
create trigger em_protect_trg before update on public.em_profiles for each row execute function public.em_protect();

-- Administrator tayinlash/olish — FAQAT ega
create or replace function public.em_set_role(target text, new_role text) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.em_is_owner() then raise exception 'Faqat ega rol bera oladi'; end if;
  if new_role not in ('admin','teacher','student') then raise exception 'Noto''g''ri rol'; end if;
  perform set_config('app.bypass', '1', true);
  update public.em_profiles set role = new_role where username = target and role <> 'owner';
end $$;
grant execute on function public.em_set_role(text, text) to authenticated;

-- Ro'yxatdan o'tganda profil avtomatik yaratiladi (rol har doim 'student')
create or replace function public.em_new_user() returns trigger language plpgsql security definer set search_path = public as $$
declare un text; m jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  un := left(lower(regexp_replace(coalesce(m->>'username', split_part(new.email,'@',1)), '[^a-zA-Z0-9_]', '', 'g')), 20);
  if length(un) < 3 then un := 'user' || substr(md5(random()::text), 1, 6); end if;
  if exists(select 1 from public.em_profiles where username = un) then un := left(un, 14) || substr(md5(random()::text), 1, 5); end if;
  insert into public.em_profiles(id, username, name, email, prov, city, start_lv)
  values (new.id, un, left(coalesce(nullif(m->>'name',''), un), 100), new.email, left(m->>'prov', 50), left(m->>'city', 50),
    case when m->>'lv' in ('pre-a1','a1','a2','b1','b2','c1','c2') then m->>'lv' else 'pre-a1' end);
  return new;
end $$;
drop trigger if exists em_on_auth_user_created on auth.users;
create trigger em_on_auth_user_created after insert on auth.users for each row execute function public.em_new_user();

-- REYTING (MAXFIYLIK): faqat username, hudud va XP. Ism, email, rasm, jurnal YUBORILMAYDI.
-- Faqat talabalar, bloklanmaganlar. Haftalik/oylik XP serverda hisoblanadi.
drop function if exists public.em_board();
create or replace function public.em_board() returns table(username text, prov text, city text, xp int, wxp int, mxp int, role text)
language sql stable security definer set search_path = public as $$
  select p.username, p.prov, p.city, p.xp,
    coalesce((select sum(case when e.value ~ '^[0-9]{1,6}$' then e.value::int else 0 end) from jsonb_each_text(p.log) e
              where e.key >= to_char(current_date - 7, 'YYYY-MM-DD')), 0)::int,
    coalesce((select sum(case when e.value ~ '^[0-9]{1,6}$' then e.value::int else 0 end) from jsonb_each_text(p.log) e
              where e.key >= to_char(current_date - 30, 'YYYY-MM-DD')), 0)::int,
    p.role
  from public.em_profiles p where p.role = 'student' and not p.banned order by p.xp desc limit 300
$$;
grant execute on function public.em_board() to authenticated;

-- O'qituvchi o'quvchilarini ko'radi: FAQAT username va natijalar (ism/email/rasm/joy YO'Q)
create or replace function public.em_students() returns table(username text, xp int, streak int, last_day text, lessons_done int)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.em_can_teach() then raise exception 'Ruxsat yo''q'; end if;
  return query select p.username, p.xp, p.streak, p.last_day,
    (select count(*) from jsonb_object_keys(p.done))::int
  from public.em_profiles p where p.role = 'student' and not p.banned order by p.xp desc limit 500;
end $$;
grant execute on function public.em_students() to authenticated;

-- Foydalanuvchi o'z akkaunti va barcha ma'lumotlarini o'chiradi (App Store / Play Market talabi)
create or replace function public.em_delete_me() returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Avval kiring'; end if;
  if public.em_is_owner() then raise exception 'Egani o''chirib bo''lmaydi'; end if;
  delete from auth.users where id = auth.uid();   -- em_profiles cascade bilan o'chadi
end $$;
grant execute on function public.em_delete_me() to authenticated;

-- Foydalanuvchi o'z akkauntini va BARCHA ma'lumotlarini o'chirishi (App Store / Google Play talabi)
create or replace function public.em_delete_me() returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Avval kiring'; end if;
  if public.em_is_owner() then raise exception 'Egani o''chirib bo''lmaydi'; end if;
  delete from auth.users where id = auth.uid();
end $$;
grant execute on function public.em_delete_me() to authenticated;

create or replace function public.em_username_taken(u text) returns boolean language sql stable security definer set search_path = public as
$$ select exists(select 1 from public.em_profiles where username = lower(u)) $$;
grant execute on function public.em_username_taken(text) to anon, authenticated;

-- E'lonlar
create table if not exists public.em_announcements(
  id uuid primary key default gen_random_uuid(),
  text text not null check (length(text) between 1 and 500),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.em_announcements enable row level security;
drop policy if exists em_ann_read on public.em_announcements;
drop policy if exists em_ann_write on public.em_announcements;
create policy em_ann_read on public.em_announcements for select to authenticated using (active or public.em_is_staff());
create policy em_ann_write on public.em_announcements for all to authenticated using (public.em_is_staff()) with check (public.em_is_staff());

-- Qo'shimcha darslar (ega/administrator qo'shadi)
create table if not exists public.em_lessons(
  id uuid primary key default gen_random_uuid(),
  level text not null check (level in ('pre-a1','a1','a2','b1','b2','c1','c2')),
  data jsonb not null,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);
alter table public.em_lessons add column if not exists created_by uuid default auth.uid();
alter table public.em_lessons enable row level security;
drop policy if exists em_les_read on public.em_lessons;
drop policy if exists em_les_write on public.em_lessons;
create policy em_les_read on public.em_lessons for select to authenticated using (true);
create policy em_les_write on public.em_lessons for all to authenticated
  using (public.em_is_staff() or (public.em_can_teach() and created_by = auth.uid()))
  with check (public.em_is_staff() or (public.em_can_teach() and created_by = auth.uid()));


-- Video bo'limi (multfilm / musiqa / film / ta'lim): hamma ko'radi, faqat o'qituvchi va staff qo'shadi
create table if not exists public.em_videos(
  id uuid primary key default gen_random_uuid(),
  yt text not null check (yt ~ '^[A-Za-z0-9_-]{11}$'),
  cat text not null check (cat in ('cartoon','music','movie','learn')),
  title text not null check (char_length(title) between 1 and 120),
  lv text not null default 'a1' check (lv in ('pre-a1','a1','a2','b1','b2','c1','c2')),
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);
alter table public.em_videos enable row level security;
drop policy if exists em_vid_read on public.em_videos;
drop policy if exists em_vid_write on public.em_videos;
create policy em_vid_read on public.em_videos for select to authenticated using (true);
create policy em_vid_write on public.em_videos for all to authenticated
  using (public.em_is_staff() or (public.em_can_teach() and created_by = auth.uid()))
  with check (public.em_is_staff() or (public.em_can_teach() and created_by = auth.uid()));

-- =====================================================================
-- EGANI TAYINLASH: avval saytda o'z emailingiz bilan ro'yxatdan o'ting, keyin shu qatorni ishga tushiring:
update public.em_profiles set role = 'owner' where email = 'akbaralisobirjonov74@gmail.com';
-- =====================================================================
