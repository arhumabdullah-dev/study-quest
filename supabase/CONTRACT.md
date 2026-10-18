# Accounts: how the apps talk to Supabase

Project: `https://uaxmcjuxkuepystatqyn.supabase.co` (region Seoul). Schema: `supabase/schema.sql` (already applied).
Public key (safe in browser, RLS protects data): `sb_publishable_QxMM_jpZLHnA5CAijHwmyQ_9VVs2uR5`.
Never put a secret / service_role key in the repo.

## Rules
- **No supabase-js, no CDN.** Talk to the REST endpoints with `fetch` (she is in mainland China; external scripts can be blocked).
- Every request sends header `apikey: <public key>`; signed-in requests also send `Authorization: Bearer <access_token>`.
- Keep the session in localStorage key `sq.session` = `{access_token, refresh_token, expires_at, user:{id}}`. Both apps share the origin (GitHub Pages), so one login works for index.html, stress.html and partner.html.
- Refresh the token when `expires_at` is less than 60 s away: `POST /auth/v1/token?grant_type=refresh_token` body `{refresh_token}`.
- The app must keep working fully offline / signed out (localStorage stays the source of truth on the phone). Accounts are an add-on.

## Login (username + password)
- Username: lowercase `a-z 0-9 _`, 3–20 chars. Email used for Supabase Auth: `<username>@study-quest.app` (never mailed).
- Sign up: `POST /auth/v1/signup` body `{email, password, data:{username, display_name, role:'her'|'him'}}`. Password min 6.
  The trigger creates `profiles` row. If the response has no `access_token`, email confirmation is still on in the dashboard: show "账号已创建，请稍后再登录 / Account created; sign-in will work once setup is finished".
- Sign in: `POST /auth/v1/token?grant_type=password` body `{email, password}`.
- Sign out: `POST /auth/v1/logout`, then clear `sq.session`.
- Errors to show in zh/en: wrong password, username taken (`User already registered`), network down (China / offline): "连不上服务器，先离线使用 / Can't reach the server, keep using offline".

## Data
- `GET /rest/v1/profiles?select=*` → my row and my partner's row (RLS).
- Pairing: she (role her) calls `POST /rest/v1/rpc/create_pair_code` → `"482913"` (valid 30 min). He calls `POST /rest/v1/rpc/join_pair` body `{code}` → `{partner_id, username, display_name, role}`. `POST /rest/v1/rpc/unpair` to unlink.
- Her state: table `app_state(user_id, data jsonb, updated_at, updated_by)`. `data` = the exact `studyQuest.v1` JSON **minus `profile.avatar`** (photos stay on the phone).
  - Her app upserts after changes (debounced ~3 s, and on `visibilitychange` hidden): `POST /rest/v1/app_state` header `Prefer: resolution=merge-duplicates,return=minimal` body `{user_id, data, updated_at: new Date().toISOString(), updated_by: user_id}`.
  - Her app pulls on open / sign-in / becoming visible: `GET /rest/v1/app_state?user_id=eq.<me>&select=*`. If `updated_by` is her partner and `updated_at` is newer than her last push (`sq.lastPush`), take **`tasks` from the server** (he edited the schedule), union `done` and `badges` (keep both), keep everything else local, save, re-render, toast "{him} 更新了你的课表 / {him} updated your schedule". First sign-in on a phone with an empty local state: take the whole server copy. First sign-in with local data and no server row: push local.
  - His page reads `GET /rest/v1/app_state?user_id=eq.<partner>`; to edit her schedule it re-reads, changes only `data.tasks`, and upserts with `updated_by: <me>`.
- Messages: `POST /rest/v1/messages` body `{from_id: me, to_id: partner, kind:'kiss'|'hug'|'gift'|'reward'|'note', emoji, body}`.
  Her app fetches unread on open and every 60 s while visible: `GET /rest/v1/messages?to_id=eq.<me>&read_at=is.null&order=created_at.asc`, shows each as a pop-up from him (with his 3D picture: kiss→kiss.webp, hug→blush, gift/reward→happy, note→remind), then `PATCH /rest/v1/messages?id=eq.<id>` body `{read_at: now}`. Messages don't change XP; XP stays derived from finished tasks.
