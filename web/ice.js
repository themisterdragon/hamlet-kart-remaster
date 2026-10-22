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
// The relay login below is for this game's free Metered Open Relay plan (no
// payment details); it's meant to sit in a public page and only lets someone
// use this game's monthly relay allowance.
const RELAY = { username: "788bf03119d001ffb03c1b50", credential: "Ig4fB8roOSuctHZE" };
window.HK_ICE = [
  { urls: "stun:stun.l.google.com:19302" },
  { urls: "stun:stun.relay.metered.ca:80" },
  { urls: "turn:global.relay.metered.ca:80", ...RELAY },
  { urls: "turn:global.relay.metered.ca:80?transport=tcp", ...RELAY },
  { urls: "turn:global.relay.metered.ca:443", ...RELAY },
  { urls: "turns:global.relay.metered.ca:443?transport=tcp", ...RELAY },
];
window.HK_ICE_URL = "";
