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

console.log("brain ok")
