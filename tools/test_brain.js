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
for (const m of ["idle", "walk", "sit", "sleep"]) assert(seen.has(m), "never entered " + m)

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

// Hanging from a window edge
const win = { id: "0xabc", x: 200, y: 38, w: 900 }
const wb = { w: 1824, floor: 984, size: 96, grip: 6, ledges: [win] }
let hung = false
for (let i = 0; i < 30 * 60 * 30 && !hung; i++) {
  const was = s.mode
  B.tick(s, 1 / 30, wb, rand)
  assert(!(was === "jump" && s.mode === "fall"), "jumped at a spot outside the window")
  assert(B.ANIMS[s.mode], "no animation for mode " + s.mode)
  hung = s.mode === "hang"
}
assert(hung, "never hung from the window")
assert.strictEqual(s.y, win.y - wb.grip, "hangs with her paws on the edge")
assert(s.x >= win.x && s.x + wb.size <= win.x + win.w, "hangs within the window")

wb.ledges = [] // window closes
for (let i = 0; i < 90 && s.mode !== "idle"; i++) B.tick(s, 1 / 30, wb, rand)
assert.strictEqual(s.mode, "idle", "falls when the window goes away")
assert.strictEqual(s.y, wb.floor)

wb.ledges = [win] // lets go by herself after a while
while (s.mode !== "hang") B.tick(s, 1 / 30, wb, rand)
for (let i = 0; i < 30 * 20 && s.mode === "hang"; i++) B.tick(s, 1 / 30, wb, rand)
assert.strictEqual(s.mode, "fall", "lets go after hanging")
while (s.mode !== "hang") B.tick(s, 1 / 30, wb, rand)
B.pet(s)
assert.strictEqual(s.mode, "fall", "petting a hanging cat makes her let go")

console.log("brain ok")
