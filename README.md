# Hamlet Kart Remaster

*To Kart, or Not to Kart*, rebuilt for PC in [Godot 4](https://godotengine.org).

A kart racer that teaches *Hamlet* without trying: right answers are turbo.
Sixteen tracks across the five Acts, 1–4 players in split screen, and 160
review questions written for grades 9–12 who read the play in a modern
translation. This is a remaster of the Nintendo 64 homebrew edition, with the
same content, the same rules and a modern look.

**Play the demo in your browser:**
https://themisterdragon.github.io/hamlet-kart-remaster/ (keyboard or gamepad),
or download it for Windows, Mac or Linux from
[Releases](https://github.com/themisterdragon/hamlet-kart-remaster/releases).

**Status: early demo (0.1).** Races on all 16 tracks against 7 CPUs, with
question boxes, quiz-as-turbo, drifting and a results screen. Not in yet:
items, menus, character select, split screen, sound. See
[docs/PLAN.md](docs/PLAN.md).

Controls: left stick or arrow keys steer, A or X gas, B or Z brake, R1 or
Shift drift (hold, lean, let go for a mini-turbo), D-pad or arrow keys
answer while a question is up, Start or Esc pauses.

## Run it

1. Install Godot 4.5 or newer (the standard build, not .NET).
2. Open `project.godot` in the editor and press Play (F5).

Builds: Project > Export in the editor (presets for Windows, Mac, Linux and
web are included), after installing Godot's export templates.

## Where things come from

`tools/import_content.py` reads the N64 edition's `tools/content.py` and writes
`data/content.json`, then copies its fonts and images into `assets/`. Edit the
questions in the N64 edition and re-import, so both editions stay the same.

## Privacy check

`.githooks/pre-commit` runs `tools/check_privacy.py` on every commit. It
refuses home-folder paths, personal email addresses and any word listed in
`.git/info/banned-words` (a local list that is never committed). Set it up in
a fresh clone with:

    git config core.hooksPath .githooks

## License

GPL-3.0 (see `LICENSE`). Fonts are under the SIL Open Font License; see
`THIRD_PARTY_NOTICES.md`.
