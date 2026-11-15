# ENGLISH MASTER — joylash (deploy) yo‘riqnomasi

```
english-master-site/
├─ src/                  # sayt manbasi (index.html, privacy.html, manifest, service-worker, ikonlar, _headers, robots, sitemap)
├─ build.js              # .env / hosting env dan kalitlarni joylab dist/ yasaydi
├─ database.sql          # Supabase bazasi (jadvallar, xavfsizlik qoidalari, funksiyalar)
├─ .env.example          # kerakli env o‘zgaruvchilar (nusxa: .env)
├─ netlify.toml  package.json  capacitor.config.json
```

## 0. Env nima va nima uchun
Kalitlar kodga yozilmaydi. `build.js` ularni `.env` (kompyuteringizda) yoki hosting “Environment variables” (internetda) dan oladi.
| O‘zgaruvchi | Qayerdan | Eslatma |
|---|---|---|
| `SUPABASE_URL` | Supabase → Project Settings → API | ochiq bo‘lishi normal |
| `SUPABASE_ANON_KEY` | o‘sha yerdagi **anon public** | brauzerga baribir tushadi; himoyani bazadagi RLS beradi. **service_role / secret kalitni hech qayerga qo‘ymang** — `build.js` uni rad etadi |
| `SITE_URL` | hosting bergan manzil | Google uchun |
| `CONTACT_EMAIL` | o‘zingizniki | maxfiylik sahifasida |
| `GOOGLE_SITE_VERIFICATION` | Search Console | ixtiyoriy |

Haqiqiy sirlar (Gmail “App password”) faqat **Supabase sozlamalarida** turadi, bu loyihada umuman yo‘q.

## 1. Supabase (baza + emailga kod)
1. supabase.com → New project (bepul).
2. **SQL Editor** → `database.sql` ni to‘liq joylab **Run**.
3. **Authentication → Providers → Email**: “Confirm email” **yoqilgan**; **“Email OTP Expiration” = `120`** (2 daqiqa). Sayt ham 2 daqiqadan keyin kodni rad etadi, lekin asosiy qoida serverda.
4. **Authentication → SMTP Settings** (kod *sizning nomingizdan* borishi uchun):
   - Google akkauntingizda 2-bosqichli tasdiqlashni yoqing → myaccount.google.com → Security → **App passwords** → 16 belgili parol yarating.
   - Host `smtp.gmail.com`, Port `465`, Username `akbaralisobirjonov74@gmail.com`, Password = shu 16 belgili parol.
   - Sender email `akbaralisobirjonov74@gmail.com`, Sender name `ENGLISH MASTER — Akbarali Sobirjonov`.
5. **Authentication → Email Templates**: “Confirm signup” va “Magic Link” matniga `Tasdiqlash kodi: {{ .Token }}` yozing (havola emas, kod bo‘lsin).
6. **Authentication → URL Configuration**: Site URL = `SITE_URL`.
7. Saytda `akbaralisobirjonov74@gmail.com` bilan ro‘yxatdan o‘ting, so‘ng SQL Editor’da:
   `update public.em_profiles set role='owner' where email='akbaralisobirjonov74@gmail.com';`

Gmail kuniga ~500 ta xat yuboradi. Foydalanuvchilar ko‘paysa, Resend/Brevo (bepul tarif) kabi xizmatga o‘ting — o‘sha SMTP bo‘limiga yoziladi.

## 2. Bepul hosting (Cloudflare Pages yoki Netlify)
1. Papkani GitHub’ga yuklang (`.env` yuklanmaydi).
2. **Netlify**: Add new site → Import from Git → build command `node build.js`, publish `dist`. **Site settings → Environment variables** ga yuqoridagi 5 ta o‘zgaruvchini kiriting.
   **Cloudflare Pages** ham xuddi shunday (build command `node build.js`, output `dist`).
3. Birinchi deploydan keyin manzil chiqadi (`xxx.netlify.app`) — uni `SITE_URL` ga yozib qayta deploy qiling va Supabase URL Configuration’ga ham qo‘ying.
4. Mahalliy sinash: `.env` yarating → `node build.js` → `npx serve dist`.

## 3. Google qidiruvida chiqishi
Sayt tayyor: sarlavha, tavsif, `sitemap.xml`, `robots.txt`, structured data, HTTPS. Siz qilasiz:
1. search.google.com/search-console → “URL prefix” → sayt manzili → tasdiqlash (HTML tag usuli: kodni `GOOGLE_SITE_VERIFICATION` ga yozing, qayta deploy).
2. Sitemaps → `sitemap.xml` ni yuboring; URL Inspection → “Request indexing”.
3. Kutish: indekslanish kunlar–haftalar oladi. **Qidiruvda yuqori o‘rin kafolatlanmaydi**; ko‘proq sahifa/kontent va tashqi havolalar (Telegram kanal, ijtimoiy tarmoqlar) yordam beradi.

## 4. Play Market (Android)
- Bir martalik **$25** to‘lov (Google Play Console). Shaxsiy yangi akkauntlar ishlab chiqarishga chiqishdan oldin **12 ta sinovchi bilan 14 kun yopiq test** o‘tkazishi shart.
- Eng oson yo‘l: **pwabuilder.com** → sayt manzilini kiriting → “Package for stores → Android” → AAB fayl. Keyin Play Console’ga yuklang.
- Do‘kon talab qiladi (tayyor): Maxfiylik siyosati (`/privacy.html`), akkauntni ilovadan o‘chirish (Profil’da bor), “Data safety” formasini to‘ldirish (ism, email, hudud, o‘qish natijalari; sotilmaydi).
- Digital Asset Links (`/.well-known/assetlinks.json`) — PWABuilder beradi, `src/.well-known/` ga qo‘ying.

## 5. App Store (iPhone)
- **Yillik $99** (Apple Developer Program) va **Mac + Xcode** kerak — bepul emas.
- `npm i @capacitor/core @capacitor/cli @capacitor/ios` → `node build.js` → `npx cap add ios` → `npx cap sync` → Xcode’da arxivlab App Store Connect’ga yuboring.
- Diqqat: Apple faqat “sayt o‘rami” bo‘lgan ilovalarni (4.2-band) rad etishi mumkin. Shuning uchun avval **PWA** (Safari → Ulashish → “Bosh ekranga qo‘shish”) bilan ishga tushiring, do‘kon uchun keyinroq mahalliy imkoniyatlar (bildirishnoma va h.k.) qo‘shing.

## 6. Maxfiylik: kim nimani ko‘radi
| Kim | Nimani ko‘radi |
|---|---|
| Oddiy foydalanuvchi | faqat o‘z profilini; reytingda boshqalarning **username, hudud, XP** (ism/email/rasm YO‘Q) |
| O‘qituvchi | o‘quvchilar: **username, XP, darslar soni** (ism/email/rasm/joy YO‘Q) |
| Administrator | foydalanuvchilar ro‘yxati va profillari (boshqarish uchun) |
| Ega (siz) | hammasi; rol berish va akkaunt o‘chirish faqat sizda |

Bu qoidalar bazaning o‘zida (RLS va funksiyalar) majburlanadi, faqat ekranda yashirilmagan. Foydalanuvchi o‘z akkauntini butunlay o‘chira oladi.

## 7. O‘qituvchi qo‘shish
Ega sifatida kiring → **👑 Boshqaruv → Jamoa** → foydalanuvchi yonidagi ro‘yxatdan **O‘qituvchi** ni tanlang. O‘qituvchi o‘z akkaunti bilan kirganda “🎓 Ustoz” bo‘limini ko‘radi: dars qo‘shish va o‘quvchilar natijalari.
(O‘qituvchi avval oddiy foydalanuvchi sifatida o‘z emaili bilan ro‘yxatdan o‘tishi kerak.)

## 8. C2 (pullik) va oylik ro‘yxat
- **C2 darajasi** yopiq (💎). Ega: Boshqaruv → Foydalanuvchilar → foydalanuvchini tanlang → **🎁 C2 ni tekin ochish** (doimiy) yoki **💎 +30 kun** (to‘lov qabul qilinganda) yoki **C2 ni yopish**. Ega, administrator va o‘qituvchilarga C2 doim ochiq.
- To‘lovni sayt o‘zi qabul qilmaydi: odam siz bilan bog‘lanadi (CONTACT_EMAIL), siz to‘lovni qabul qilib, tugma bilan ochasiz. Avtomatik to‘lov (Stripe/Click/Payme) keyin qo‘shiladi.
- **Boshqaruv → Oylik**: oy tanlanadi, shu oy qo‘shilgan foydalanuvchilar ro‘yxati va CSV.
- Eslatma: C2 devori ilova ichida; dars matni sayt fayliga kiritilgan, shuning uchun texnik bilimli odam uni aylanib o‘tishi mumkin. To‘liq himoya uchun C2 darslarini serverdan berish kerak.

## 9. Ma’lum cheklovlar
- XP va test ballari brauzerda hisoblanadi — sinchkov foydalanuvchi uni soxtalashtirishi mumkin (reyting uchun jiddiy bo‘lsa, XP ni serverga ko‘chirish kerak).
- Kontent hozircha 7 daraja × 3 dars; qolganini Boshqaruv → Darslar orqali qo‘shasiz.
- Brauzerning ovoz tanish funksiyasi ishlashi qurilmaga bog‘liq.
