# Hamlet Kart Remaster

*To Kart, or Not to Kart*, rebuilt for PC in [Godot 4](https://godotengine.org).

A kart racer that teaches *Hamlet* without trying: right answers are turbo.
Sixteen tracks across the five Acts, 1–4 players in split screen, and 160
review questions written for grades 9–12 who read the play in a modern
translation. This is a remaster of the Nintendo 64 homebrew edition, with the
same content, the same rules and a modern look.

**Status: milestone 0.** The content loads and the quiz card runs. There's no
racing yet. See [docs/PLAN.md](docs/PLAN.md).

## Run it

1. Install Godot 4.5 or newer (the standard build, not .NET).
2. Open `project.godot` in the editor and press Play (F5).

Quiz test screen: arrow keys or D-pad answer, Enter deals the next question,
Page Up / Page Down changes the track.

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
