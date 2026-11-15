#!/usr/bin/env node
/* ENGLISH MASTER — build: src/ → dist/, %%O'ZGARUVCHI%% larni .env yoki hosting "Environment variables" dan joylaydi.
   Ishlatish:  node build.js            (kalitlar kodga yozilmaydi, git'ga tushmaydi) */
const fs = require('fs'), path = require('path');
const root = __dirname, src = path.join(root, 'src'), dist = path.join(root, 'dist');

// .env faylini o'qish (hosting'da env bevosita beriladi, .env shart emas)
const envFile = path.join(root, '.env');
if (fs.existsSync(envFile)) {
  for (const line of fs.readFileSync(envFile, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
    if (m && !(m[1] in process.env)) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}
const env = k => (process.env[k] || '').trim();
const vars = {
  SUPABASE_URL: env('SUPABASE_URL').replace(/\/+$/, ''),
  SUPABASE_ANON_KEY: env('SUPABASE_ANON_KEY'),
  SITE_URL: env('SITE_URL').replace(/\/+$/, ''),
  CONTACT_EMAIL: env('CONTACT_EMAIL'),
  GOOGLE_SITE_VERIFICATION: env('GOOGLE_SITE_VERIFICATION'),
};

// XAVFSIZLIK: service_role kalitini frontendga joylashni rad etish
function jwtRole(t) { try { return JSON.parse(Buffer.from(t.split('.')[1], 'base64url').toString()).role; } catch { return null; } }
if (/^sb_secret_/.test(vars.SUPABASE_ANON_KEY) || jwtRole(vars.SUPABASE_ANON_KEY) === 'service_role') {
  console.error('❌ TO‘XTATILDI: SUPABASE_ANON_KEY ga SECRET / service_role kalit berilgan. Faqat "anon public" (publishable) kalit kerak!');
  process.exit(1);
}
if (vars.SUPABASE_URL && !/^https:\/\/[a-z0-9-]+\.supabase\.co$/.test(vars.SUPABASE_URL)) console.warn('⚠️  SUPABASE_URL odatda https://xxxx.supabase.co ko‘rinishida bo‘ladi');

const TEXT = /\.(html|txt|xml|json|webmanifest|js)$|(^|\/)_headers$/;
function copy(from, to) {
  fs.mkdirSync(to, { recursive: true });
  for (const e of fs.readdirSync(from, { withFileTypes: true })) {
    const a = path.join(from, e.name), b = path.join(to, e.name);
    if (e.isDirectory()) { copy(a, b); continue; }
    if (TEXT.test(a)) {
      let t = fs.readFileSync(a, 'utf8');
      if (!vars.GOOGLE_SITE_VERIFICATION) t = t.replace(/<!--GSV-->.*\r?\n?/g, '');
      t = t.replace(/%%([A-Z_]+)%%/g, (_, k) => (k in vars ? vars[k] : ''));
      fs.writeFileSync(b, t);
    } else fs.copyFileSync(a, b);
  }
}
fs.rmSync(dist, { recursive: true, force: true });
copy(src, dist);

console.log('✅ dist/ tayyor');
console.log('   Baza:        ', vars.SUPABASE_URL && vars.SUPABASE_ANON_KEY ? 'ulangan (' + vars.SUPABASE_URL + ')' : '⚠️  ulanmagan → sayt MAHALLIY rejimda ishlaydi (SUPABASE_URL va SUPABASE_ANON_KEY ni bering)');
console.log('   Sayt manzili:', vars.SITE_URL || '⚠️  SITE_URL berilmagan (Google uchun sitemap/canonical to‘g‘ri bo‘lmaydi)');
console.log('   Aloqa email: ', vars.CONTACT_EMAIL || '⚠️  CONTACT_EMAIL berilmagan (maxfiylik sahifasida kerak)');
