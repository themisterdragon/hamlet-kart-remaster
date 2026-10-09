// Some browsers report controllers they don't know without calling them
// "standard": Firefox on Linux gives the raw Linux layout (D-pad and
// triggers as axes, buttons in kernel order), which this remaps; Chrome on
// Android (the AYN Thor, say) already uses the standard order and only
// needs the label.
(() => {
  const raw = navigator.getGamepads.bind(navigator);
  const btn = (v) => ({ pressed: v > 0.5, touched: v > 0.05, value: v });
  const val = (b) => (b ? (typeof b === "object" ? b.value : b) : 0);
  const android = /Android/i.test(navigator.userAgent);
  function remap(p) {
    const b = p.buttons, a = p.axes;
    if (android) {
      // Chrome on Android lays out every pad in the standard order (D-pad on
      // 12-15, as on the AYN Thor); it just doesn't call it "standard"
      return {
        id: p.id, index: p.index, connected: p.connected, timestamp: p.timestamp, mapping: "standard",
        buttons: Array.from(b, (x) => btn(val(x))), axes: Array.from(a).slice(0, 4),
        vibrationActuator: p.vibrationActuator, hapticActuators: p.hapticActuators,
      };
    }
    const sony = /054c|sony|playstation|dualsense|dualshock/i.test(p.id);
    // Linux orders face buttons south, east, north, west; Sony's driver puts
    // Triangle on north and Square on west, Xbox's driver the other way round
    const left = sony ? 3 : 2, top = sony ? 2 : 3;
    const trig = (i, bi) => (a.length > 5 ? (a[i] + 1) / 2 : val(b[bi]));  // -1..1 axis -> 0..1
    const hasHat = a.length >= 8;
    const out = [
      val(b[0]), val(b[1]), val(b[left]), val(b[top]),   // A/Cross, B/Circle, X/Square, Y/Triangle
      val(b[4]), val(b[5]), trig(2, 6), trig(5, 7),      // LB, RB, LT, RT
      val(b[8]), val(b[9]), val(b[11]), val(b[12]),      // Back/Create, Start/Options, sticks
      hasHat ? +(a[7] < -0.5) : val(b[13]), hasHat ? +(a[7] > 0.5) : val(b[14]),   // D-pad up, down
      hasHat ? +(a[6] < -0.5) : val(b[15]), hasHat ? +(a[6] > 0.5) : val(b[16]),   // D-pad left, right
      val(b[10]),                                        // the logo button
    ];
    return {
      id: p.id, index: p.index, connected: p.connected, timestamp: p.timestamp, mapping: "standard",
      buttons: out.map(btn), axes: [a[0] || 0, a[1] || 0, a[3] || 0, a[4] || 0],
      vibrationActuator: p.vibrationActuator, hapticActuators: p.hapticActuators,
    };
  }
  const fix = (p) => (p && p.mapping !== "standard" ? remap(p) : p);
  navigator.getGamepads = () => Array.from(raw(), fix);
  // The game also learns a pad's layout from the "gamepadconnected" event,
  // from the browser's raw pad: hand it the fixed one there too (else pads
  // like the AYN Thor's get their shoulder buttons read as Back and Guide).
  const addListener = window.addEventListener.bind(window);
  window.addEventListener = function (type, fn, opts) {
    if (type === "gamepadconnected" && typeof fn === "function") {
      return addListener(type, (e) => fn({ type: e.type, gamepad: fix(e.gamepad) }), opts);
    }
    return addListener(type, fn, opts);
  };
})();
