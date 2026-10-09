# Privacy

Hamlet Kart is made for classrooms, so here is exactly what it does and
doesn't do with data. In short: **the game collects and stores nothing.**
No accounts, no names, no sign-in, no analytics, no ads, no cookies, no
tracking, and no saved scores or answers. When the page closes, nothing
about the player remains.

What the internet itself involves is listed below, so a school can judge it.

## Solo play (browser or download)

- **The downloads** (Windows, Mac, Linux) work offline and never connect to
  anything.
- **The browser version** is a set of files served by **GitHub Pages**. Like
  any website host, GitHub sees each visitor's IP address and browser type
  when the files are downloaded (see GitHub's privacy statement). The game
  loads nothing from any other site: fonts, music, the class-race library,
  everything is served from the same place.
- Questions are answered inside the game; the answers are not recorded or
  sent anywhere.

## Class races (browser version only)

A class race connects the players' browsers to each other. To do that:

- **The race code** is made up on the spot (5 random letters and numbers)
  and forgotten when the race ends.
- **Matchmaking:** the host's and players' browsers register the code with
  the free public **PeerJS** server (0.peerjs.com), which introduces them.
  It sees their IP addresses and the code, nothing else.
- **Finding each other:** while connecting, browsers ask **Google's STUN
  server** (stun.l.google.com) for their public address, the standard way
  web video calls connect. Google sees the IP address in that request.
- **If a network blocks a direct link** (some school networks do), the race
  can run through a **PeerJS relay server** (in the EU or US). The relay
  passes along encrypted game traffic it can't read.
- **What travels between players:** each player's chosen character, their
  controller presses, and the race as the host's screen sees it (kart
  positions, items, the question on screen). No names or personal details.
  Connections between browsers are encrypted (WebRTC, as in video calls).
- **The host sees the players' IP addresses** while the race runs, as with
  any direct browser-to-browser connection. On a school network these are
  usually the school's own addresses.

Nothing from a race is stored, by the game or by us. No one, including the
game's author, can see who played or what they answered.

## For a stricter setup

- Use the **downloads** for solo play: no connections at all.
- A school can host the browser version on its own web server (it's a
  folder of static files, `build/web`), so GitHub isn't involved.
- The matchmaking and relay servers can be replaced by a school's own
  (PeerJS's server is open source); ask and we'll make that a setting.

Questions: open an issue on the GitHub repository.
