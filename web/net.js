// Online class races: PeerJS (free public matchmaking) introduces the
// browsers, then they talk directly or through the relay named in ice.js.
// The PeerJS library is bundled (peerjs.min.js, MIT), so nothing outside this
// site is contacted until a race is hosted or joined. See PRIVACY.md. Godot
// polls hk.poll() each frame; no names or accounts, only a random race code.
window.hk = (() => {
  const PREFIX = "hamlet-kart-remaster-";
  const LINK_WAIT = 20000;  // ms a player waits for the link to the host to open
  let peer = null, conns = {}, events = [], gen = 0, linkTimer = 0;
  const push = (e) => events.push(e);
  function wire(c) {
    c.on("open", () => { clearTimeout(linkTimer); conns[c.peer] = c; push({ t: "conn", peer: c.peer }); });
    c.on("data", (d) => push({ t: "data", peer: c.peer, msg: d }));
    c.on("close", () => { delete conns[c.peer]; push({ t: "close", peer: c.peer }); });
    c.on("error", (e) => push({ t: "error", msg: e.type || String(e) }));
  }
  // relay logins from HK_ICE_URL if set (fresh ones each time), else ice.js's list
  async function ice() {
    const url = window.HK_ICE_URL;
    if (url) {
      try {
        const r = await fetch(url, { cache: "no-store", signal: AbortSignal.timeout(5000) });
        const j = await r.json();
        const list = Array.isArray(j) ? j : j.iceServers;
        if (Array.isArray(list) && list.length) return list;
      } catch (e) { console.warn("class races: relay logins unavailable", e); }
    }
    return window.HK_ICE || [{ urls: "stun:stun.l.google.com:19302" }];
  }
  async function make(id) {
    const my = ++gen;
    const config = { iceServers: await ice() };
    if (my !== gen) return null;  // closed (or started again) while fetching
    peer = id ? new Peer(PREFIX + id, { config }) : new Peer({ config });
    peer.on("error", (e) => push({ t: "error", msg: e.type || String(e) }));
    peer.on("disconnected", () => push({ t: "error", msg: "disconnected" }));
    return peer;
  }
  return {
    ready: () => typeof Peer !== "undefined",
    code: "",
    async host(code) {
      this.code = code;  // (tests read it here)
      if (!(await make(code))) return;
      peer.on("open", () => push({ t: "open", id: code }));
      peer.on("connection", wire);
    },
    async join(code) {
      if (!(await make(null))) return;
      peer.on("open", () => {
        push({ t: "open", id: peer.id });
        wire(peer.connect(PREFIX + code, { reliable: true }));
        // the race exists but no link opened: the network kept the two apart
        linkTimer = setTimeout(() => { if (!Object.keys(conns).length) push({ t: "error", msg: "no-link" }); }, LINK_WAIT);
      });
    },
    send(to, msg) { const c = conns[to]; if (c && c.open) c.send(msg); },
    broadcast(msg) { for (const k in conns) if (conns[k].open) conns[k].send(msg); },
    poll() { const e = JSON.stringify(events); events = []; return e; },
    close() { gen++; clearTimeout(linkTimer); if (peer) peer.destroy(); peer = null; conns = {}; },
  };
})();
