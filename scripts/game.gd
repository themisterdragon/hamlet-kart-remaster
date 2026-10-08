extends Node
## What the menus decided, for the race to read.

enum Mode { SOLO, HOST, CLIENT }

var mode := Mode.SOLO
var my_char := 0
var track := 6           # Act III's first track sets the standard
var race_class := 1
var code := ""
# online: who drives which kart. kart_chars[i] = character, kart_peers[i] =
# "" for the host, a peer id for a remote player, null for a CPU
var kart_chars: Array = []
var kart_peers: Array = []
var host_peer := ""      # (players) the host's peer id
var my_kart := 0         # (players) which kart is mine
var players: Array = []  # (host) the lobby: [{peer, ch}], the host is peer ""
