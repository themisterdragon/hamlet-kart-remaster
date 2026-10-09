# Remaster plan

Goal: the N64 game on PC (Windows, Mac, Linux) and in a web browser
(Chromebooks), same content and rules, then a modern 3D look one Act at a
time. The N64 edition stays the source of truth for questions and story text.

Rules that carry over:
- Right answers are turbo, and a wrong answer never stops the race.
- The right answer always shows, with a tick and cross (never colour alone).
- A missed question returns at the player's next item box until it's answered.
- Clean screen: no clutter, no explanatory text during a race.
- Text passes WCAG AA contrast.
- All art and sound are original. No other game's names or assets.

Engine: Godot 4, Compatibility renderer (OpenGL 3 / WebGL 2). That runs on
older school PCs and Chromebooks, and it's lighter on laptops that struggle
with Vulkan.

## Milestone 0: foundation (done)
- Repo, GPL-3.0, privacy check on every commit.
- `tools/import_content.py`: N64 content → `data/content.json`, plus fonts and images.
- Content autoload and a quiz test screen at 1080p.

## Milestone 1: faithful port (done except split screen; demo 0.3)
Same look as the N64 (kart sprites, the same tracks), at high resolution and 60 fps.

Done so far (Act III's "To Be or Not to Be" by default; `-- --track=N` for others):
all 16 layouts imported from the N64 track builder (splits included); road,
curbs, barriers and stand-in scenery; the N64's kart handling, barrier
bounces, hop-drift mini-turbos and kart bumps; 7 CPUs on the N64's racing
line with its rubber band; question boxes, the quiz panel, quiz-as-turbo with
streaks, missed questions coming back; chase camera; lap, time and place HUD.
Test runs: `tools/shot.sh` (software rendering, hidden display).

1. Track geometry: rebuild the 16 track loops from the N64 track data as
   Godot paths (road mesh, barriers, boxes, boost pads, ramps, splits).
2. Kart physics: speed, steering curve, hop-drift with mini-turbo on R,
   rocket start, slipstream, bumps. Tune against the N64 feel.
3. Quiz-as-turbo: item boxes, the D-pad quiz panel, boost and item rewards,
   streaks, auto-drive while answering.
4. Items: the seven-item set.
5. CPU racers, Grand Prix (points), Single Scene, Time Trial, speed classes.
6. Split screen for 1–4 players with gamepads; keyboard for player 1.
7. Menus: title, character select, track select, pause, results, Act review.
8. Saves: best times per track and class (user folder; browser storage on web).
9. Exports: Windows, Mac, Linux, Web.

## Milestone 1.5: online class races (done: PeerJS, join code, up to 8 players)
Students race each other from their own browsers or PCs: one machine hosts
and shows a short join code, up to 8 players enter it and pick characters,
CPUs fill the empty karts. Host-authoritative (the host runs the race,
players send their controls), so every screen shows the same race.
- Godot WebRTC (works in the web build) plus a small signaling server for
  the codes. GitHub Pages can't run one, so it needs a free-tier host.
- Check it on school networks early: some block peer-to-peer traffic, so
  plan a relay fallback (TURN).
- Privacy: no accounts, no names stored; nicknames or teacher-given codes.
- Keep the kart code input-driven (it already takes controls as data each
  frame) so local split screen and online share one path.

## Milestone 2: remaster, one Act at a time
Act III first; it sets the standard.
- 3D cast and karts (scripted Blender models in the Royal Storybook style),
  replacing the sprites.
- Lit tracks with landmarks, a per-Act palette, soft shadows.
- Full-quality orchestral score and sounds (the N64 mixes are 22 kHz).
- Character weight classes shown on character select.

## Open questions
- Lowest PC and Chromebook the game must run on, and the frame-rate target there.
- Whether the web build is the main way teachers get it.
- Whether to publish it, and when (it stays local for now).
