// Some browsers (Firefox on Linux, for one) report controllers in their raw
// Linux layout instead of the "standard" one the game understands: the
// D-pad and triggers come as axes, and the buttons in kernel order. This
// remaps those pads to the standard layout before the game reads them.
(() => {
  const raw = navigator.getGamepads.bind(navigator);
  const btn = (v) => ({ pressed: v > 0.5, touched: v > 0.05, value: v });
  const val = (b) => (b ? (typeof b === "object" ? b.value : b) : 0);
  function remap(p) {
    const b = p.buttons, a = p.axes;
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
  navigator.getGamepads = () => Array.from(raw(), (p) => (p && p.mapping !== "standard" ? remap(p) : p));
})();
