# moti app

Two home-screen web apps for one person: a Chinese university student (her boyfriend 安仁 / Arhum built it for her). They are static HTML files hosted on GitHub Pages and added to an iPhone home screen from Safari. Nothing else uses them, so build for her, not for generic users.

- `index.html`: **学习闯关 (Study Quest)**. A weekly study planner played like a game: XP, levels, streaks, badges, a coach character who reminds and rewards her, and a pet room (feed / pat / hug / hit the character).
- `stress.html`: **解压室 (Stress Room)**. Couple mode (feed, dress up, kiss the boyfriend character) and enemy mode (punch, slap, cut hair, pie the boss character), with a breathing exercise at the end.
- `img/anren/*.webp`: the 3D cartoon of 安仁 (curly hair, white tee with brown collar), one picture per mood: idle, happy, eat, hurt, sulk, blush, hungry, sleepy, remind, kiss, chubby, left, right. All share one crop frame so he stays the same size when the pose changes. `img/stickers/*.webp`: his sticker pack, unlocked by level on the 奖励 tab. `img/boss/*.webp`: the fictional 3D cartoon office boss for enemy mode (smug, hurt, dizzy, slapped, bald, pie, wet, laugh, cry, sorry), base job b00dfdb4-3fad-423c-9242-3024dd572385, cropped to the same 466:760 frame. `img/xiaochun/*.webp` + `img/xiaochun-avatar.webp` + `img/stickers/xc-*.webp`: 小春 / Xiao Chun, her own 3D vinyl doll (idle, happy, eat, blush, kiss, pout, chubby, hungry); she approved it being on the public site. Character names: 安仁/Anren and 小春/Xiao Chun are the defaults by language; she can rename both. Source PNGs live in `private/drafts/`, `private/drafts/boss/` and `private/xiaochun/`.
- `sw.js`, `study.webmanifest`, `stress.webmanifest`, `icons/`: home-screen app setup and offline cache. The study icon is his face.
- `private/`: **never commit or publish.** Holds her schedule backup (`her-schedule.json`), his reference photo, and anything personal. Listed in `.gitignore`.

## Hard rules

- **Single files, no build step.** Each app is one HTML file with inline CSS and JS. No frameworks, no npm.
- **No external hosts at runtime.** She is in mainland China: Google Fonts, Google APIs and many CDNs are blocked, and a blocked stylesheet can freeze the page. Use system font stacks and inline everything. Images live in the repo next to the HTML.
- **Her personal data never goes into the public code.** `seedTasks()` returns `[]` on purpose. Her timetable and nicknames reach her phone through the backup import. The coach name defaults to 安仁 (`COACH_DEFAULT`) and can be changed in settings or the backup (settings → paste backup text or import file). To change her schedule, edit `private/her-schedule.json` and send her the new text.
- **Chinese first.** Default language is `zh`; every UI string exists in both `zh` and `en` in the i18n objects (`I18N`, `COACH`, `PET` in index.html; `T` and `LINES` in stress.html). Add new strings to both.
- **Phone first.** Designed for iPhone widths 375–430px: no horizontal scroll, tap targets ≥ 44px, inputs ≥ 16px font (stops iOS zoom), respect `env(safe-area-inset-*)`, bottom tab bar.
- **Colors are tokens.** Every color is a CSS custom property on `:root`, redefined for dark mode in both `@media (prefers-color-scheme:dark){:root:not([data-theme="light"])…}` and `:root[data-theme="dark"]`.
- **Design direction (current):** game-like, in the spirit of Talking Tom. index.html home = HUD (her photo, level, XP, streak) + a sky-blue room with 安仁 standing on a warm floor, round action buttons on both sides (喂饭 / 抱抱 / 摸摸头 / 亲亲 / 打他 / 解压), and one task card with a big 完成 button; four round tabs 主页 / 任务 / 奖励 / 统计. Candy buttons (`.c3d`) sink into a darker edge when pressed. stress.html couple mode uses the 3D pictures (feed him chubby, lipstick kisses, accessories); enemy mode uses the 3D boss (tools: punch, kick, slap, haircut, doodle, pie, water, tickle; she can rename him). Both apps show a first-time how-to guide and pick the language from the phone on first open.
- **New poses:** generate with Higgsfield `gpt_image_2_5` using `private/drafts/curly-m.png` (job fb10ab39-898c-4b66-a46a-2153dc7acf94) as the reference, transparent background, 2:3; then crop with the same union frame as the others before converting to webp. Avoid generic "AI design" looks (purple gradients, gradient text, emoji as section headers, identical soft-shadow cards everywhere).

## Data model (index.html)

- State lives in `localStorage` key `studyQuest.v1`.
- A task: `{id, title, titleZh, cat, start:'HH:MM', end:'HH:MM'|'', repeat:[0-6 weekdays, 0=Sun], date:'YYYY-MM-DD'|null, diff:1|2|3, notes}`. Weekly tasks use `repeat`; one-off tasks use `date`. Times cannot cross midnight (use a note instead).
- Completion: `state.done['<taskId>|YYYY-MM-DD'] = xpEarned`. XP, level, streak and badges are all derived from `done`.
- `SEED_VER` / `mergeSeeds()` exist for adding built-in tasks to existing saves; currently unused because seeds are empty.

## Releasing a change

1. Edit the HTML. Keep the existing compact template-string style.
2. Check the script parses: `sed -n '/<script>/,/<\/script>/p' index.html | sed '1d;$d' > /tmp/x.js && node --check /tmp/x.js` (same for `stress.html`).
3. Test at phone size: serve with `python -m http.server 8765 --bind 127.0.0.1` and open the page in a 390px-wide frame. `file://` pages can't run the service worker.
4. **Bump `VERSION` in `sw.js`** whenever any cached file changes, so her phone drops the old cache.
5. Commit and push to `main`; GitHub Pages redeploys in about a minute. She gets the update the next time she opens the app online.

## Reminders

Web pages can't push notifications when closed on iPhone without a server. Reminders work two ways: in-app pop-ups while the app is open, and the "把提醒加到手机日历" button, which exports an `.ics` calendar with alarms so her phone's calendar shows them even when the app is closed.
