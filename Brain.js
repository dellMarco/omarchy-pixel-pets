.pragma library

// Pet behaviour. Pure logic, no QML: Service.qml calls tick() ~30x a second.
// Positions are the sprite's top-left in logical px.
// bounds = { w: max x, floor: resting y, size: sprite size,
//            grip: how far above a window edge the sprite top sits when hanging,
//            ledges: [{ id, x, y, w }] window top edges she may hang from,
//            ballSize: yarn ball size,
//            cursor: { x, y } mouse position, or null when it is not on this screen }

// Must match the row order / frame counts in tools/make_sprites.py
var ANIMS = {
  idle:    { row: 0, frames: 4, fps: 3 },
  walk:    { row: 1, frames: 6, fps: 10 },
  run:     { row: 1, frames: 6, fps: 16 },
  sit:     { row: 2, frames: 2, fps: 2 },
  sleep:   { row: 3, frames: 4, fps: 2 },
  petted:  { row: 4, frames: 4, fps: 6 },
  held:    { row: 5, frames: 2, fps: 6 },
  fall:    { row: 6, frames: 2, fps: 8 },
  jump:    { row: 7, frames: 2, fps: 8 },
  hang:    { row: 8, frames: 4, fps: 3 },
  crouch:  { row: 9, frames: 2, fps: 6 },
  pounce:  { row: 10, frames: 2, fps: 8 },
  bat:     { row: 11, frames: 2, fps: 6 },
  groom:   { row: 12, frames: 4, fps: 4 },
  stretch: { row: 13, frames: 3, fps: 2 },
  yawn:    { row: 14, frames: 3, fps: 2 }
}
var YARN_ROW = 15
var YARN_FRAMES = 4

var SPEED = 60          // px/s walking
var RUN_SPEED = 150     // px/s chasing the ball
var GRAVITY = 1800      // px/s^2
var JUMP_SPEED = 1400   // px/s leaping up to a window edge
var HANG_CHANCE = 0.15  // share of idle decisions that go for a window

var CURSOR_RANGE = 500  // px: how far away she notices the mouse
var NOTICE_RATE = 0.8   // chance per second of noticing a moving mouse nearby
var POUNCE_TIME = 0.5   // s in the air
var POUNCE_HEIGHT = 50  // px
var POUNCE_REACH = 300  // px: longest single pounce
var MAX_POUNCES = 3     // in a row, then she gets bored for a while

var BALL_LIFE = 40      // s before the yarn ball goes away
var BALL_BOUNCE = 0.45
var BALL_FRICTION = 1.5 // rolling slowdown per second on the floor

// Modes in which something interesting (ball, mouse) can catch her attention.
var REACTIVE = { idle: true, sit: true, walk: true, run: true, groom: true, yawn: true }

function create(x, y) {
  return {
    mode: "idle", x: x, y: y, dir: 1, t: 0, until: 2, vy: 0, targetX: x, goal: null,
    ball: null, lastCursor: null, cursorStill: Infinity, pounces: 0, bored: 0, from: x, to: x
  }
}

// Whether Service.qml needs to keep the mouse position fresh.
function watchesCursor(mode) {
  return !!REACTIVE[mode] || mode === "crouch" || mode === "pounce"
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

// A mouse that moved recently, near the floor, within range.
function cursorNear(s, b) {
  var c = b.cursor
  return !!c && s.cursorStill < 1.5 && c.y >= b.floor - b.size
    && Math.abs(c.x - (s.x + b.size / 2)) < CURSOR_RANGE
}

function pounceAt(s, b) {
  var to = Math.max(0, Math.min(b.w, b.cursor.x - b.size / 2))
  s.from = s.x
  s.to = s.x + Math.max(-POUNCE_REACH, Math.min(POUNCE_REACH, to - s.x))
  if (s.to !== s.x) s.dir = s.to < s.x ? -1 : 1
  setMode(s, "pounce", Infinity)
}

function next(s, b, rand) {
  var m = s.mode
  if (m === "petted") return setMode(s, "sit", 3 + rand() * 5)
  if (m === "walk" && s.goal !== null) {
    var goal = s.goal
    setMode(s, "jump", Infinity)
    s.goal = goal
    return
  }
  if (m === "sleep") return setMode(s, "stretch", 1.5)
  if (m === "crouch") return cursorNear(s, b) ? pounceAt(s, b) : setMode(s, "idle", 1)
  if (m === "bat") return setMode(s, "idle", 0.3)
  if (m !== "idle" && m !== "sit") return setMode(s, "idle", 1 + rand() * 3)
  var ls = b.ledges || []
  if (ls.length && rand() < HANG_CHANCE) {
    var l = ls[Math.floor(rand() * ls.length)]
    walkTo(s, l.x + rand() * (l.w - b.size))
    s.goal = l.id
    return
  }
  // energy 0 = lazy (naps a lot), 1 = playful (walks a lot, short naps)
  var e = b.energy === undefined ? 0.5 : b.energy
  var walk = 0.25 + 0.3 * e
  var sleep = 0.03 + 0.2 * (1 - e)
  var r = rand()
  if (r < walk) walkTo(s, rand() * b.w)
  else if ((r -= walk) < 0.2) setMode(s, "sit", 3 + rand() * 5)
  else if ((r -= 0.2) < 0.12) setMode(s, "groom", 3 + rand() * 3)
  else if ((r -= 0.12) < 0.08) setMode(s, "yawn", 1.5)
  else if ((r -= 0.08) < sleep) setMode(s, "sleep", (20 + rand() * 40) * (1.5 - e))
  else setMode(s, "idle", 1 + rand() * 3)
}

// Ball first, then the mouse. May switch her into run / bat / crouch.
function distract(s, b, rand, dt) {
  if (!REACTIVE[s.mode] || s.goal !== null) return
  var o = s.ball
  if (o) {
    var gap = o.x + b.ballSize / 2 - (s.x + b.size / 2)
    var low = o.y >= b.floor + b.size - b.ballSize - b.size * 0.3
    if (Math.abs(gap) < b.size * 0.5 && low && !o.held) {
      s.dir = gap < 0 ? -1 : 1
      o.vx = s.dir * (250 + rand() * 300)
      o.vy = -(150 + rand() * 350)
      setMode(s, "bat", 0.4)
    } else {
      if (s.mode !== "run") setMode(s, "run", Infinity)
      s.dir = gap < 0 ? -1 : 1
      s.targetX = Math.max(0, Math.min(b.w, s.x + gap - s.dir * b.size * 0.3))
    }
    return
  }
  if (s.mode === "run") return setMode(s, "idle", 1)
  if (s.bored <= 0 && cursorNear(s, b) && rand() < NOTICE_RATE * dt) {
    s.dir = b.cursor.x < s.x + b.size / 2 ? -1 : 1
    s.pounces = 0
    setMode(s, "crouch", 0.8 + rand() * 0.8)
  }
}

function watchCursor(s, b, dt) {
  var c = b.cursor, l = s.lastCursor
  if (c && l && Math.abs(c.x - l.x) + Math.abs(c.y - l.y) > 3) s.cursorStill = 0
  else s.cursorStill += dt
  s.lastCursor = c ? { x: c.x, y: c.y } : null
  if (s.bored > 0) s.bored -= dt
}

function moveBall(s, b, dt) {
  var o = s.ball
  if (!o) return
  o.life -= dt
  if (o.life <= 0) {
    s.ball = null
    return
  }
  if (o.held) return
  var floor = b.floor + b.size - b.ballSize
  var maxX = b.w + b.size - b.ballSize
  o.vy += GRAVITY * dt
  o.x += o.vx * dt
  o.y += o.vy * dt
  o.roll += o.vx * dt
  if (o.y >= floor) {
    o.y = floor
    o.vy = Math.abs(o.vy) > 120 ? -o.vy * BALL_BOUNCE : 0
    o.vx *= Math.exp(-BALL_FRICTION * dt)
  } else if (o.y < 0) {
    o.y = 0
    o.vy = Math.abs(o.vy) * BALL_BOUNCE
  }
  if (o.x < 0) {
    o.x = 0
    o.vx = Math.abs(o.vx) * 0.7
  } else if (o.x > maxX) {
    o.x = maxX
    o.vx = -Math.abs(o.vx) * 0.7
  }
}

function tick(s, dt, b, rand) {
  watchCursor(s, b, dt)
  moveBall(s, b, dt)
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
  } else if (s.mode === "pounce") {
    s.t += dt
    var p = Math.min(1, s.t / POUNCE_TIME)
    s.x = s.from + (s.to - s.from) * p
    s.y = b.floor - 4 * POUNCE_HEIGHT * p * (1 - p)
    if (p >= 1) {
      s.y = b.floor
      s.pounces++
      if (s.pounces < MAX_POUNCES && cursorNear(s, b)) setMode(s, "crouch", 0.4 + rand() * 0.6)
      else {
        s.bored = 15 + rand() * 15
        setMode(s, "sit", 2 + rand() * 3)
      }
    }
  } else {
    s.y = b.floor
    s.t += dt
    distract(s, b, rand, dt)
    if (s.mode === "walk" || s.mode === "run") {
      s.x += s.dir * (s.mode === "run" ? RUN_SPEED : SPEED) * dt
      if ((s.targetX - s.x) * s.dir <= 0) {
        s.x = s.targetX   // no overshoot: a hang spot must stay inside its window
        if (s.mode === "walk") s.t = s.until = 0
      }
    } else if (s.mode === "crouch") {
      if (!cursorNear(s, b)) setMode(s, "idle", 1)   // the mouse got away
      else s.dir = b.cursor.x < s.x + b.size / 2 ? -1 : 1
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

// Drops a yarn ball just in front of her (replacing any existing one).
function spawnBall(s, b) {
  var x = s.x + b.size / 2 + s.dir * b.size * 0.8 - b.ballSize / 2
  s.ball = {
    x: Math.max(0, Math.min(b.w + b.size - b.ballSize, x)),
    y: b.floor + b.size - b.ballSize - 150,
    vx: s.dir * 80, vy: 0, roll: 0, life: BALL_LIFE, held: false
  }
}

function yarnFrame(o, ballSize) {
  var f = Math.floor(o.roll / (ballSize / 2)) % YARN_FRAMES
  return f < 0 ? f + YARN_FRAMES : f
}
