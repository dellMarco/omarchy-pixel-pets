.pragma library

// Pet behaviour. Pure logic, no QML: Service.qml calls tick() ~30x a second.
// Positions are the sprite's top-left in logical px; bounds = { w: max x, floor: resting y }.

// Must match the row order / frame counts in tools/make_sprites.py
var ANIMS = {
  idle:   { row: 0, frames: 4, fps: 3 },
  walk:   { row: 1, frames: 6, fps: 10 },
  sit:    { row: 2, frames: 2, fps: 2 },
  sleep:  { row: 3, frames: 4, fps: 2 },
  petted: { row: 4, frames: 4, fps: 6 },
  held:   { row: 5, frames: 2, fps: 6 },
  fall:   { row: 6, frames: 2, fps: 8 }
}

var SPEED = 60      // px/s walking
var GRAVITY = 1800  // px/s^2

function create(x, y) {
  return { mode: "idle", x: x, y: y, dir: 1, t: 0, until: 2, vy: 0, targetX: x }
}

function setMode(s, mode, duration) {
  s.mode = mode
  s.t = 0
  s.until = duration
}

function next(s, b, rand) {
  if (s.mode === "petted") return setMode(s, "sit", 3 + rand() * 5)
  if (s.mode === "walk" || s.mode === "sleep") return setMode(s, "idle", 1 + rand() * 3)
  var r = rand()
  if (r < 0.5) {
    s.targetX = rand() * b.w
    s.dir = s.targetX < s.x ? -1 : 1
    setMode(s, "walk", Infinity)
  } else if (r < 0.75) setMode(s, "sit", 3 + rand() * 5)
  else if (r < 0.85) setMode(s, "sleep", 20 + rand() * 40)
  else setMode(s, "idle", 1 + rand() * 3)
}

function tick(s, dt, b, rand) {
  if (s.mode === "held") return s
  if (s.mode === "fall") {
    s.vy += GRAVITY * dt
    s.y += s.vy * dt
    if (s.y >= b.floor) {
      s.y = b.floor
      setMode(s, "idle", 1)
    }
  } else {
    s.y = b.floor
    s.t += dt
    if (s.mode === "walk") {
      s.x += s.dir * SPEED * dt
      if ((s.targetX - s.x) * s.dir <= 0) s.t = s.until = 0
    }
    if (s.t >= s.until) next(s, b, rand)
  }
  s.x = Math.max(0, Math.min(b.w, s.x))
  return s
}

function pet(s) {
  if (s.mode !== "held" && s.mode !== "fall") setMode(s, "petted", 1.5)
}

function grab(s) {
  setMode(s, "held", Infinity)
}

function drop(s) {
  s.vy = 0
  setMode(s, "fall", Infinity)
}
