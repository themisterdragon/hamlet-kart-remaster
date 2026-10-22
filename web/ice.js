// How class-race browsers reach each other (WebRTC "ICE servers").
// STUN tells a browser its public address; that's enough at home, but school
// Wi-Fi usually keeps devices from talking directly, so a TURN relay carries
// the race instead. PeerJS's own free relays (eu-0/us-0.turn.peerjs.com) were
// shut down, so this file names the relay to use. See PRIVACY.md.
//
// Either list the servers here, or set HK_ICE_URL to an address that returns
// fresh relay logins as JSON (an array of servers, or {iceServers: [...]}),
// the way TURN services hand them out (Metered's free Open Relay:
// https://<app>.metered.live/api/v1/turn/credentials?apiKey=<key>; that key
// only lets someone use this game's free relay allowance). If the address
// can't be reached the list below is used.
window.HK_ICE = [
  { urls: "stun:stun.l.google.com:19302" },
];
window.HK_ICE_URL = "";
