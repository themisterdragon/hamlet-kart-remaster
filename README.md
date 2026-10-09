# Hamlet Kart Remaster

*To Kart, or Not to Kart*, rebuilt for PC in [Godot 4](https://godotengine.org).

A kart racer that teaches *Hamlet* without trying: right answers are turbo.
Sixteen scenes across the five Acts, eight racers as 3D clay figures, and 160
review questions written for grades 9–12 who read the play in a modern
translation. A remaster of the Nintendo 64 homebrew edition: the same
content and rules, rebuilt for PCs and browsers.

## Play

**In your browser (no download, Chromebooks too):**
https://themisterdragon.github.io/hamlet-kart-remaster/

**Download for Windows, Mac or Linux:**
[Demo 0.3](https://github.com/themisterdragon/hamlet-kart-remaster/releases/tag/v0.3-demo)

### Class races
Up to 8 students race each other from their own browsers. The teacher (or a
student) chooses **Host a Class Race** and gets a 5-character code; everyone
else chooses **Join a Class Race** and types it in. Computer racers fill any
empty karts. No accounts and no names: the code is the only thing that
travels, through the free [PeerJS](https://peerjs.com) matchmaking service.
Class races are in the browser version; the downloads are for solo play.

**Privacy:** the game collects and stores nothing: no accounts, names,
analytics, cookies or saved answers. See [PRIVACY.md](PRIVACY.md) for exactly
what a class race connects to.

### What's in demo 0.3
- All 16 scenes, all 8 racers, all 160 questions, all 7 items
- The racers as 3D clay figures, and sculpted clay scenery for every scene
  (Elsinore, the chapel, the stage, the pirate ship, the graveyard and more)
- A 3D character select with each racer's speed, pickup, handling and weight
- Question boxes: a right answer is a boost and an item, three in a row a
  long boost; a missed question comes back at your next box
- Drifting with mini-turbos, slipstream, rocket starts, boost pads, ramps
  and moving scenery, with sparks, flames and dust
- The N64 edition's orchestral score, sound effects and character voices
- Full controller support (Xbox and PlayStation, DualSense included) with
  matching button names, rumble, and an on-screen keyboard for the class code
- An automatic light mode for slower computers such as school Chromebooks

Coming next: split screen. See [docs/PLAN.md](docs/PLAN.md).

### Controls
| | Gamepad (Xbox / PlayStation) | Keyboard |
|---|---|---|
| Steer | left stick | arrows or A/D |
| Gas | A / Cross, or RT / R2 | X |
| Brake | B / Circle, or X / Square | Z |
| Drift (hold, lean, let go for a mini-turbo) | RB / R1 | Shift |
| Item (hold the skull; stick back rolls it behind) | LB / L1, or LT / L2 | Space |
| Answer a question | D-pad | arrow keys |
| Pause | Start / Options | Esc |
| Back to the menu (pause or results) | View / Create | M |
| Menus | D-pad or stick, A / Cross picks, B / Circle goes back | arrows, Enter, Esc |

## Run it

1. Install Godot 4.7 or newer (the standard build, not .NET).
2. Open `project.godot` in the editor and press Play (F5).

Builds: Project > Export in the editor (presets for Windows, Mac, Linux and
web are included), after installing Godot's export templates. For the web
build use `tools/build_web.sh`, which also adds the class-race bridge
(`web/net.js`).

## Where things come from

`tools/import_content.py` reads the N64 edition's `tools/content.py` and
track builder and writes `data/content.json` and `data/tracks.json`, then
copies its fonts, images, music and sounds into `assets/`. Edit the questions
in the N64 edition and re-import, so both editions stay the same.

`tools/make_models.py` turns the N64 edition's sculpted characters
(`tools/characters.py` there) into the 3D models in `assets/models/`, with
`tools/sdfmesh` (C, needs gcc with OpenMP).

## Privacy check

`.githooks/pre-commit` runs `tools/check_privacy.py` on every commit. It
refuses home-folder paths, personal email addresses and any word listed in
`.git/info/banned-words` (a local list that is never committed). Set it up in
a fresh clone with:

    git config core.hooksPath .githooks

## License

GPL-3.0 (see `LICENSE`). Fonts are under the SIL Open Font License; see
`THIRD_PARTY_NOTICES.md`.
