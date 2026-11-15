.pragma library

// Pet behaviour. Pure logic, no QML: Service.qml calls tick() ~30x a second.
// Positions are the sprite's top-left in logical px.
// bounds = { w: max x, floor: resting y, size: sprite size,
//            grip: how far above a window edge the sprite top sits when hanging,
//            ledges: [{ id, x, y, w }] window top edges she may hang from }

// Must match the row order / frame counts in tools/make_sprites.py
var ANIMS = {
  idle:   { row: 0, frames: 4, fps: 3 },
  walk:   { row: 1, frames: 6, fps: 10 },
  sit:    { row: 2, frames: 2, fps: 2 },
  sleep:  { row: 3, frames: 4, fps: 2 },
  petted: { row: 4, frames: 4, fps: 6 },
  held:   { row: 5, frames: 2, fps: 6 },
  fall:   { row: 6, frames: 2, fps: 8 },
  jump:   { row: 7, frames: 2, fps: 8 },
  hang:   { row: 8, frames: 4, fps: 3 }
}

var SPEED = 60          // px/s walking
var GRAVITY = 1800      // px/s^2
var JUMP_SPEED = 1400   // px/s leaping up to a window edge
var HANG_CHANCE = 0.15  // share of idle decisions that go for a window

function create(x, y) {
  return { mode: "idle", x: x, y: y, dir: 1, t: 0, until: 2, vy: 0, targetX: x, goal: null }
}

function setMode(s, mode, duration) {
  s.mode = mode
  s.t = 0
  s.until = duration
  if (mode !== "jump" && mode !== "hang") s.goal = null
}

function walkTo(s, x) {
  s.targetX = x
  s.dir = x < s.x ? -1 : 1
  setMode(s, "walk", Infinity)
}

// The ledge she is heading for / hanging from, if it still exists and still spans her.
function ledge(s, b) {
  var ls = b.ledges || []
  for (var i = 0; i < ls.length; i++)
    if (ls[i].id === s.goal && ls[i].x <= s.x && s.x + b.size <= ls[i].x + ls[i].w) return ls[i]
  return null
}

function next(s, b, rand) {
  if (s.mode === "petted") return setMode(s, "sit", 3 + rand() * 5)
  if (s.mode === "walk" && s.goal !== null) {
    var goal = s.goal
    setMode(s, "jump", Infinity)
    s.goal = goal
    return
  }
  if (s.mode === "walk" || s.mode === "sleep") return setMode(s, "idle", 1 + rand() * 3)
  var ls = b.ledges || []
  if (ls.length && rand() < HANG_CHANCE) {
    var l = ls[Math.floor(rand() * ls.length)]
    walkTo(s, l.x + rand() * (l.w - b.size))
    s.goal = l.id
    return
  }
  var r = rand()
  if (r < 0.5) walkTo(s, rand() * b.w)
  else if (r < 0.75) setMode(s, "sit", 3 + rand() * 5)
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
  } else if (s.mode === "jump" || s.mode === "hang") {
    var l = ledge(s, b)
    if (!l) drop(s)   // window closed, moved away, or went fullscreen
    else if (s.mode === "jump") {
      s.y -= JUMP_SPEED * dt
      if (s.y <= l.y - b.grip) {
        s.y = l.y - b.grip
        setMode(s, "hang", 5 + rand() * 10)
        s.goal = l.id
      }
    } else {
      s.y = l.y - b.grip
      s.t += dt
      if (s.t >= s.until) drop(s)
    }
  } else {
    s.y = b.floor
    s.t += dt
    if (s.mode === "walk") {
      s.x += s.dir * SPEED * dt
      if ((s.targetX - s.x) * s.dir <= 0) {
        s.x = s.targetX   // no overshoot: a hang spot must stay inside its window
        s.t = s.until = 0
      }
    }
    if (s.t >= s.until) next(s, b, rand)
  }
  s.x = Math.max(0, Math.min(b.w, s.x))
  return s
}

function pet(s) {
  if (s.mode === "jump" || s.mode === "hang") drop(s)   // startled: lets go
  else if (s.mode !== "held" && s.mode !== "fall") setMode(s, "petted", 1.5)
}

function grab(s) {
  setMode(s, "held", Infinity)
}

function drop(s) {
  s.vy = 0
  setMode(s, "fall", Infinity)
}
