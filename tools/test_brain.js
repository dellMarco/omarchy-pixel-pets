// Self-check for Brain.js: node tools/test_brain.js
const fs = require("fs"), path = require("path"), vm = require("vm"), assert = require("assert")

const src = fs.readFileSync(path.join(__dirname, "..", "Brain.js"), "utf8").replace(".pragma library", "")
const B = {}
vm.runInNewContext(src, B)

let seed = 42
const rand = () => (seed = (seed * 1664525 + 1013904223) % 4294967296) / 4294967296
const bounds = { w: 1824, floor: 984 }
const s = B.create(100, bounds.floor)
const seen = new Set()

for (let i = 0; i < 30 * 60 * 30; i++) { // 30 simulated minutes
  B.tick(s, 1 / 30, bounds, rand)
  seen.add(s.mode)
  assert(s.x >= 0 && s.x <= bounds.w, "x out of bounds: " + s.x)
  assert.strictEqual(s.y, bounds.floor)
  assert(B.ANIMS[s.mode], "no animation for mode " + s.mode)
}
for (const m of ["idle", "walk", "sit", "sleep", "groom", "yawn", "stretch"]) assert(seen.has(m), "never entered " + m)

B.pet(s)
assert.strictEqual(s.mode, "petted")
B.grab(s); s.x = -500; s.y = 100
B.tick(s, 1 / 30, bounds, rand)
assert.strictEqual(s.y, 100, "held pet must not move on its own")
B.pet(s)
assert.strictEqual(s.mode, "held", "cannot pet while held")
B.drop(s)
for (let i = 0; i < 90 && s.mode === "fall"; i++) B.tick(s, 1 / 30, bounds, rand)
assert.strictEqual(s.mode, "idle")
assert.strictEqual(s.y, bounds.floor)
assert.strictEqual(s.x, 0, "dropped off-screen pet is clamped back")

// Climbing up behind a window and peeking over its top edge
const win = { id: "0xabc", x: 200, y: 38, w: 900 }
const wb = { w: 1824, floor: 984, size: 96, peek: 30, ledges: [win] }
const until = (mode, max = 30 * 60 * 30) => {
  for (let i = 0; i < max && s.mode !== mode; i++) {
    const was = s.mode
    B.tick(s, 1 / 30, wb, rand)
    assert(B.ANIMS[s.mode], "no animation for mode " + s.mode)
    assert(!(B.ON_LEDGE[was] && s.mode === "fall" && wb.ledges.length), "fell off a window that is still there")
    if (s.mode === "climb" || s.mode === "descend") assert(s.y <= wb.floor && s.y >= win.y - wb.size - 1, "stays between the floor and just over the edge")
    if (B.PEEKING[s.mode]) assert(s.clipBottom === win.y && s.clipTop === -Infinity, "only the part above the edge shows")
    else if (B.ON_LEDGE[s.mode]) assert(s.clipTop === win.y && s.clipBottom === Infinity, "only the part below the edge shows")
    else assert(s.clipTop === -Infinity && s.clipBottom === Infinity, "fully visible off the window")
  }
  assert.strictEqual(s.mode, mode, "never reached " + mode)
}
until("climb")
assert(s.x >= win.x && s.x + wb.size <= win.x + win.w, "climbs within the window")
let climbTicks = 0
while (s.mode === "climb") { B.tick(s, 1 / 30, wb, rand); climbTicks++ }
assert(climbTicks / 30 > 8, "the climb should take a while, took " + (climbTicks / 30).toFixed(1) + "s")
until("peek")
assert.strictEqual(s.y, win.y - wb.peek, "peeks with her ears and eyes above the edge")
until("descend")
assert(s.y + wb.size <= win.y + 5, "comes back over the edge from behind it")
until("idle", 30 * 20)
assert.strictEqual(s.y, wb.floor, "back on the floor")

until("peek")
B.pet(s)
assert.strictEqual(s.mode, "peekdown", "petting her while she peeks makes her duck")

until("peek")
wb.ledges = [] // window closes
for (let i = 0; i < 90 && s.mode !== "idle"; i++) B.tick(s, 1 / 30, wb, rand)
assert.strictEqual(s.mode, "idle", "falls when the window goes away")
assert.strictEqual(s.y, wb.floor)
assert(s.clipTop === -Infinity && s.clipBottom === Infinity)

// Chasing the mouse
const cb = { w: 1824, floor: 984, size: 96, peek: 30, ledges: [], ballSize: 36, cursor: null }
const c = B.create(500, cb.floor)
let crouched = false, pounced = false, bored = false
for (let i = 0; i < 30 * 60; i++) {
  cb.cursor = { x: 800 + 30 * Math.sin(i / 3), y: cb.floor + 60 }   // wiggling near the floor
  B.tick(c, 1 / 30, cb, rand)
  crouched = crouched || c.mode === "crouch"
  if (c.mode === "pounce") {
    pounced = true
    assert(c.y <= cb.floor && c.y >= cb.floor - 60, "pounce arc out of range: " + c.y)
  }
  bored = bored || c.bored > 0
  assert(c.x >= 0 && c.x <= cb.w)
}
assert(crouched && pounced, "never stalked and pounced the mouse")
assert(bored, "never got bored of the mouse")

const far = B.create(500, cb.floor)
for (let i = 0; i < 30 * 60 * 5; i++) {
  cb.cursor = { x: 800 + 30 * Math.sin(i / 3), y: 100 }   // moving, but high up the screen
  B.tick(far, 1 / 30, cb, rand)
  assert(far.mode !== "crouch" && far.mode !== "pounce", "chased a mouse that was nowhere near the floor")
}

// Yarn ball
cb.cursor = null
const k = B.create(300, cb.floor)
B.spawnBall(k, cb)
let bats = 0
for (let i = 0; i < 30 * 45; i++) {
  const was = k.mode
  B.tick(k, 1 / 30, cb, rand)
  if (k.mode === "bat" && was !== "bat") bats++
  if (k.ball) {
    assert(k.ball.x >= 0 && k.ball.x <= cb.w + cb.size - cb.ballSize, "ball left the screen")
    assert(k.ball.y >= 0 && k.ball.y <= cb.floor + cb.size - cb.ballSize, "ball fell through the floor")
    assert(B.yarnFrame(k.ball, cb.ballSize) >= 0 && B.yarnFrame(k.ball, cb.ballSize) < B.YARN_FRAMES)
  }
}
assert(bats >= 3, "batted the ball only " + bats + " times")
assert.strictEqual(k.ball, null, "ball should go away after a while")
assert.notStrictEqual(k.mode, "run", "stops chasing once the ball is gone")

// Adaptive tick rate: slow while still, full rate while moving, and the pet still lives a normal life
assert.strictEqual(B.tickInterval("run", false), 33)
assert.strictEqual(B.tickInterval("climb", false), 33)
assert.strictEqual(B.tickInterval("sleep", true), 33, "a ball in play always gets the full rate")
assert(B.tickInterval("sleep", false) > B.tickInterval("sit", false) && B.tickInterval("sit", false) > 33)
const ab = { ...cb, ledges: [win], ballSize: 36 }
const a = B.create(500, ab.floor)
const seenA = new Set()
let simulated = 0, ticks = 0
while (simulated < 30 * 60) {
  const dt = B.tickInterval(a.mode, !!a.ball) / 1000
  B.tick(a, dt, ab, rand)
  simulated += dt; ticks++
  seenA.add(a.mode)
  assert(a.x >= 0 && a.x <= ab.w)
  if (!B.ON_LEDGE[a.mode] && a.mode !== "fall") assert.strictEqual(a.y, ab.floor)
}
for (const m of ["idle", "walk", "sit", "sleep", "climb", "peek", "descend"]) assert(seenA.has(m), "adaptive: never entered " + m)
assert(ticks / simulated < 18, "should tick well under 30/s on average, did " + (ticks / simulated).toFixed(1) + "/s")

// Care reminders: she sits and asks, ignores the mouse meanwhile, and a click serves it
const tick30 = (c, bb, n) => { for (let i = 0; i < n; i++) { B.tick(c, 1 / 30, bb, rand); assert(B.ANIMS[c.mode], "no animation for " + c.mode) } }
const rb = { ...cb, ledges: [], ballSize: 36, cursor: { x: 1500, y: cb.floor + 40 } }
const r = B.create(300, rb.floor)
B.want(r, "water")
assert.strictEqual(r.mode, "ask")
for (let i = 0; i < 30 * 200; i++) {   // a wiggling mouse right next to her doesn't distract her
  rb.cursor = { x: r.x + 60 + (i % 2) * 20, y: rb.floor + 40 }
  B.tick(r, 1 / 30, rb, rand)
  assert.strictEqual(r.mode, "ask", "keeps asking, was " + r.mode)
}
B.pet(r, rb)
assert.strictEqual(r.mode, "drink")
assert.strictEqual(r.want, null)
tick30(r, rb, 30 * 4.1)
assert.strictEqual(r.mode, "petted", "happy after a drink")
B.want(r, "food"); B.pet(r, rb)
assert.strictEqual(r.mode, "eat")
B.want(r, "break"); B.pet(r, rb)
assert(r.ball && r.want === null, "a break brings out the ball")
tick30(r, rb, 30 * 3)
assert.strictEqual(r.mode, "run", "and she plays with it")
B.want(r, null)

// Ignored for NAG_AFTER: she walks over to the mouse, bubble bouncing, and asks there
const n = B.create(100, rb.floor)
rb.cursor = { x: 1200, y: rb.floor + 40 }
B.want(n, "food")
tick30(n, rb, 30 * (B.NAG_AFTER + 1))
assert(n.nag && n.mode === "walk", "goes to nag, was " + n.mode)
for (let i = 0; i < 30 * 30; i++) {   // the mouse wiggles; she's on a mission, not hunting
  rb.cursor = { x: 1200 + (i % 2) * 10, y: rb.floor + 40 }
  B.tick(n, 1 / 30, rb, rand)
  assert(n.mode === "walk" || n.mode === "ask", "got distracted into " + n.mode)
}
assert.strictEqual(n.mode, "ask")
assert(Math.abs(n.x + rb.size / 2 - 1200) < 5, "asks right by the mouse")
B.want(n, null)
assert(n.mode !== "ask" && !n.nag, "cancelled reminder stops the asking")

// Asked while up on a window: finishes the trip, then asks on the floor
const w2 = B.create(500, ab.floor)
for (let i = 0; i < 30 * 60 * 30 && w2.mode !== "climb"; i++) B.tick(w2, 1 / 30, ab, rand)
assert.strictEqual(w2.mode, "climb")
B.want(w2, "water")
assert.strictEqual(w2.mode, "climb", "doesn't let go of the window")
for (let i = 0; i < 30 * 120 && w2.mode !== "ask"; i++) B.tick(w2, 1 / 30, ab, rand)
assert.strictEqual(w2.mode, "ask")
assert.strictEqual(w2.y, ab.floor)

// Energy: a lazy cat sleeps more than a playful one
function sleepShare(energy) {
  const eb = { w: 1824, floor: 984, size: 96, peek: 30, ledges: [], ballSize: 36, cursor: null, energy }
  const e = B.create(500, eb.floor)
  let asleep = 0
  const ticks = 30 * 60 * 60
  for (let i = 0; i < ticks; i++) {
    B.tick(e, 1 / 30, eb, rand)
    if (e.mode === "sleep") asleep++
  }
  return asleep / ticks
}
const lazy = sleepShare(0), playful = sleepShare(1)
assert(lazy > playful * 2, `lazy cat should sleep much more: lazy ${lazy.toFixed(2)} playful ${playful.toFixed(2)}`)

// Time of day
assert(B.timeEnergy(3) < 0.1 && B.timeEnergy(10) > 0.8 && B.timeEnergy(20) < 0.35, "day curve shape")
assert(B.timeEnergy(6) < B.timeEnergy(9), "sleeps in, then wakes up")
assert(Math.abs(B.timeEnergy(24) - B.timeEnergy(0)) < 1e-9 && Math.abs(B.timeEnergy(-1) - B.timeEnergy(23)) < 1e-9)
for (let h = 0; h < 24; h += 0.25) {
  for (const base of [0, 0.5, 1]) {
    const e = B.effectiveEnergy(base, h)
    assert(e >= 0 && e <= 1, "energy out of range at " + h)
  }
  assert(B.dayPhase(h).length > 0)
}
assert(B.effectiveEnergy(1, 2) > B.effectiveEnergy(0, 2), "a playful cat is livelier at night than a lazy one")
const night = sleepShare(B.effectiveEnergy(0.5, 2)), morning = sleepShare(B.effectiveEnergy(0.5, 10))
assert(night > 0.5, "should sleep most of the night, slept " + night.toFixed(2))
assert(night > morning * 3, `sleeps far more at night: night ${night.toFixed(2)} morning ${morning.toFixed(2)}`)

console.log("brain ok")
