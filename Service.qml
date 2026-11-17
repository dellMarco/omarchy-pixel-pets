import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import "Brain.js" as Brain

Item {
  id: root

  // Settings, edited from the bar panel (Panel.qml) and saved to disk.
  readonly property alias settings: store
  // Screen pixels per sprite pixel. The dog is drawn one step up, so the cat is the smaller of the two
  // and both keep whole, crisp pixels.
  function scaleOf(species) {
    return (({ small: 2, medium: 3, large: 4 })[store.size] || 3) + (species === "dog" ? 1 : 0)
  }

  // store.species is "cat", "dog" or "both". Each species keeps its own coat and name.
  function active(species) { return store.species === species || store.species === "both" }
  function coatOf(species) { return species === "dog" ? store.dogCoat : store.coat }
  function nameOf(species) { return species === "dog" ? store.dogName : store.name }
  function spriteUrlOf(species) { return Qt.resolvedUrl("sprites/" + species + "-" + coatOf(species) + ".png") }

  // Local time as a fractional hour, refreshed every minute, for the day cycle.
  property real hour: 0
  // Changes at midnight; the pets plan their day by it.
  property int day: 0
  function updateHour() {
    var d = new Date()
    hour = d.getHours() + d.getMinutes() / 60
    day = d.getFullYear() * 372 + d.getMonth() * 31 + d.getDate()
  }
  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.updateHour()
  }

  // ---------- What the pets notice about the desktop ----------

  // Something is playing: tails flick faster, the dog spins more.
  readonly property bool music: Mpris.players.values.some(p => p.isPlaying)

  // Running on a low battery makes them sleepy; nearly empty, they sleep. The charger wakes them.
  readonly property real charge: {
    var d = UPower.displayDevice
    return d && d.isPresent && UPower.onBattery ? d.percentage : 1
  }
  readonly property bool lowBattery: charge < 0.2
  onLowBatteryChanged: if (!lowBattery) win.each((brain, b) => Brain.wake(brain, b))
  readonly property real energy: (store.dayCycle ? Brain.effectiveEnergy(store.energy, hour) : store.energy) * (lowBattery ? 0.4 : 1)

  // The screen is being shared or recorded. Hyprland reports a stop as soon as frames pause,
  // so only believe it after a quiet while.
  property bool casting: false
  Timer {
    id: castOver
    interval: 15000
    onTriggered: root.casting = false
  }

  // Nobody at the desk for a few minutes: they nap until the mouse moves again.
  // How long that takes is drawn anew every time, between two and a half and five minutes.
  property int napAfter: 150 + Math.floor(Math.random() * 150)
  IdleMonitor {
    timeout: root.napAfter
    onIsIdleChanged: {
      if (isIdle) win.each(brain => Brain.settle(brain))
      else {
        root.napAfter = 150 + Math.floor(Math.random() * 150)
        // The pointer is where the dog runs to; ask for it once, then greet.
        cursorSocket.connected = true
        greeting.restart()
      }
    }
  }
  Timer {
    id: greeting
    interval: 200
    onTriggered: win.each((brain, b) => Brain.welcome(brain, b, Math.random, win.cursor ? win.cursor.x : null))
  }

  function giveBall(species) {
    var view = species === "dog" ? dogView : catView
    if (!view.brain || !store.shown) return
    Brain.spawnBall(view.brain, win.boundsFor(view))
    view.sync()
  }

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/pixel-pets.json"
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()
    onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter() }

    JsonAdapter {
      id: store
      property string name: "Mochi"
      property string species: "cat"
      property string coat: "orange"
      property string dogName: "Taro"
      property string dogCoat: "golden"
      property string size: "medium"
      property real energy: 0.5
      property bool shown: true
      property bool chaseMouse: true
      property bool hangOnWindows: true
      property bool dayCycle: true
      property bool cameraShy: true
    }
  }

  PanelWindow {
    id: win

    readonly property var views: [catView, dogView]

    // What a pet's brain gets to know about the world, built fresh for each tick.
    function boundsFor(view) {
      var other = view === catView ? dogView : catView
      return {
        w: width - view.size,
        // The sheets leave two empty rows under the feet; stand 1px above the screen edge.
        floor: height - 1 - view.size + 2 * view.px,
        ground: height - 1,
        size: view.size,
        species: view.species,
        friend: other.brain,
        friendSize: other.size,
        peek: 10 * view.px,   // rows of the peek frame above the edge (PEEK_EDGE in make_sprites.py)
        ledges: store.hangOnWindows ? ledges : [],
        ballSize: view.ballSize,
        cursor: store.chaseMouse ? cursor : null,
        energy: root.energy,
        hour: root.hour,
        day: root.day,
        music: root.music,
        hide: store.cameraShy && root.casting,
        exhausted: root.charge < 0.1
      }
    }

    // Calls fn(brain, bounds) for every pet that is out.
    function each(fn) {
      for (var i = 0; i < views.length; i++)
        if (views[i].active && views[i].brain) fn(views[i].brain, boundsFor(views[i]))
    }

    // A window opened or closed over this stretch of the floor: startle whoever stands there.
    function startleAt(x, w) {
      for (var i = 0; i < views.length; i++) {
        var v = views[i]
        if (!v.active || !v.brain) continue
        var mid = v.brain.x + v.size / 2
        if (mid >= x && mid <= x + w) Brain.startle(v.brain, boundsFor(v), Math.random)
      }
    }
    function ledgeOf(address) {
      for (var i = 0; i < ledges.length; i++) if (ledges[i].id === "0x" + address) return ledges[i]
      return null
    }
    property string opened: ""
    property real switchedAt: 0
    function justSwitched() { return Date.now() - switchedAt < 2000 }
    Timer {
      id: openedCheck
      interval: 400   // long enough for Hyprland to report where the new window landed
      onTriggered: {
        if (win.justSwitched()) return
        win.refreshLedges()
        var l = win.ledgeOf(win.opened)
        if (l) win.startleAt(l.x, l.w)
      }
    }

    // Mouse position in this window's coordinates, or null when it is on another screen.
    // Read straight from Hyprland's request socket: no process per poll.
    property var cursor: null
    Socket {
      id: cursorSocket
      path: Hyprland.requestSocketPath
      parser: SplitParser {
        splitMarker: ""
        onRead: data => {
          // Hang up ourselves: if Hyprland closes first, Quickshell logs a warning per poll.
          cursorSocket.connected = false
          var m = /(-?\d+),\s*(-?\d+)/.exec(data)
          var mon = Hyprland.monitorFor(win.screen)
          if (!m || !mon) return
          var x = Number(m[1]) - mon.x, y = Number(m[2]) - mon.y
          win.cursor = x >= 0 && y >= 0 && x < win.width && y < win.height ? { x: x, y: y } : null
        }
      }
      onConnectedChanged: if (connected) { write("cursorpos"); flush() }
    }
    Timer {
      interval: 100
      repeat: true
      // Only while one of them could react to it.
      running: store.shown && store.chaseMouse && (catView.watching || dogView.watching)
      onRunningChanged: if (!running) win.cursor = null
      onTriggered: if (!cursorSocket.connected) cursorSocket.connected = true
    }

    // Top edges of the windows visible on this monitor, in this window's coordinates.
    property var ledges: []
    function refreshLedges() {
      var out = []
      var mon = Hyprland.monitorFor(win.screen)
      var ws = mon ? mon.activeWorkspace : null
      if (ws && !ws.hasFullscreen) {
        var tops = Hyprland.toplevels.values
        for (var i = 0; i < tops.length; i++) {
          var o = tops[i].lastIpcObject
          if (!o || !o.at || !o.size || o.hidden || !o.workspace || o.workspace.id !== ws.id) continue
          if (o.size[1] < catView.size * 1.5) continue
          // Only the part of the top edge that is on this screen counts: she can't walk past the
          // screen edge to reach the rest. Only the cat climbs, so it has to be wide enough for her.
          var left = Math.max(0, o.at[0] - mon.x), right = Math.min(win.width, o.at[0] - mon.x + o.size[0])
          if (right - left < catView.size) continue
          out.push({ id: o.address, x: left, y: o.at[1] - mon.y, w: right - left })
        }
      }
      ledges = out
    }

    // Hyprland sends no event when a tile is resized, so poll as well as listen.
    Connections {
      target: Hyprland
      function onRawEvent(event) {
        Hyprland.refreshToplevels()
        var data = String(event.data || "")
        var name = String(event.name)
        if (name === "workspace" || name === "workspacev2" || name === "focusedmon" || name === "focusedmonv2"
            || name === "activespecial" || name === "activespecialv2" || name === "moveworkspace" || name === "moveworkspacev2") {
          // Switching workspaces swaps every window under them at once, and a workspace switcher
          // may grab thumbnails while it does. Neither is a window popping up or a screen being
          // shared: whatever is reported in the two seconds after a switch is ignored.
          win.switchedAt = Date.now()
          openedCheck.stop()
        } else if (name === "screencast") {
          // "state,owner": a monitor or a single window is being captured (1) or no longer is (0).
          if (data.split(",")[0] !== "1") castOver.restart()
          else if (!win.justSwitched()) {
            castOver.stop()
            root.casting = true
          }
        } else if (win.justSwitched()) {
          return
        } else if (name === "openwindow") {
          win.opened = data.split(",")[0]
          openedCheck.restart()
        } else if (name === "closewindow") {
          var gone = win.ledgeOf(data)
          if (gone) win.startleAt(gone.x, gone.w)
        }
      }
    }
    Timer {
      interval: 1000
      running: true
      repeat: true
      triggeredOnStart: true
      onTriggered: { Hyprland.refreshToplevels(); win.refreshLedges() }
    }

    visible: store.shown
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "pixel-pets"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Only the pets and their toys take input; everything else clicks through to the apps below.
    // Only a pet's visible part takes clicks. Explicit geometry rather than `item:` a child of the pet:
    // a Region only follows its own item's x/y, so a nested item leaves the region behind when she walks.
    mask: Region {
      x: catView.body.x
      y: catView.body.y + catView.body.shownTop
      width: catView.active && catView.body.shownHeight > 0 ? catView.body.width : 0
      height: catView.body.shownHeight
      Region { item: catView.toy }
      Region {
        x: dogView.body.x
        y: dogView.body.y + dogView.body.shownTop
        width: dogView.active && dogView.body.shownHeight > 0 ? dogView.body.width : 0
        height: dogView.body.shownHeight
      }
      Region { item: dogView.toy }
    }

    Timer {
      interval: 33
      running: store.shown && win.width > 0 && win.height > 0
      repeat: true
      onTriggered: {
        var live = win.views.filter(v => v.active)
        for (var i = 0; i < live.length; i++) {
          var b = win.boundsFor(live[i])
          // Two pets start apart, either side of the middle.
          if (!live[i].brain) live[i].brain = Brain.create(b.w * (live.length > 1 ? 0.35 + 0.3 * i : 0.5), b.floor)
        }
        // Windows can vanish under a climber at any moment, so recheck every tick while one is on
        // its way up or sitting on top.
        if (live.some(v => v.brain.goal !== null || v.brain.perch !== null)) win.refreshLedges()
        for (var j = 0; j < live.length; j++) {
          Brain.tick(live[j].brain, interval / 1000, win.boundsFor(live[j]), Math.random)
          live[j].sync()
        }
      }
    }

    PetView { id: catView; species: "cat" }
    PetView { id: dogView; species: "dog" }
  }

  // One pet with its name tag and toy, in the window's coordinates.
  component PetView: Item {
    id: view

    required property string species
    readonly property int px: root.scaleOf(species)
    readonly property int size: 32 * px
    readonly property int ballSize: 12 * px
    readonly property bool active: root.active(species)
    // Brain state; created by the tick once the window has a size, dropped when the pet is switched off.
    property var brain: null
    readonly property bool watching: brain !== null && Brain.watchesCursor(pet.mode)
    readonly property string spriteUrl: root.spriteUrlOf(species)
    readonly property string name: root.nameOf(species)
    // What she is dreaming of right now: "toy", "friend" or nothing.
    property string dream: ""
    readonly property alias body: pet
    readonly property alias toy: ball

    anchors.fill: parent
    visible: active
    onActiveChanged: if (!active) { brain = null; ball.shown = false }

    function sync() {
      pet.x = Math.round(brain.x)
      pet.y = Math.round(brain.y)
      pet.dir = brain.dir
      pet.mode = brain.mode
      // On a window, the top edge hides whatever part of her is on the far side of it.
      var top = Math.max(0, Math.min(view.size, Math.round(brain.clipTop - brain.y)))
      var bottom = Math.max(top, Math.min(view.size, Math.round(brain.clipBottom - brain.y)))
      pet.shownTop = top
      pet.shownHeight = bottom - top
      if (brain.ball) {
        ball.x = Math.round(brain.ball.x)
        ball.y = Math.round(brain.ball.y)
        ball.frame = Brain.yarnFrame(brain.ball, view.ballSize)
      }
      ball.shown = brain.ball !== null
      dream = brain.dream ? brain.dream.what : ""
    }

    Item {
      id: pet

      property string mode: "idle"
      property int dir: 1
      property int shownTop: 0
      property int shownHeight: view.size
      readonly property var anim: Brain.ANIMS[mode]

      width: view.size
      height: view.size

      // The visible part of her, which is also all that takes clicks.
      Item {
        y: pet.shownTop
        width: view.size
        height: pet.shownHeight
        clip: true
        // See-through while climbing over a window, so she doesn't distract from what's on it.
        opacity: pet.mode === "climb" || pet.mode === "descend" ? 0.4 : 1

        Behavior on opacity {
          NumberAnimation { duration: 600; easing.type: Easing.InOutQuad }
        }

        AnimatedSprite {
          y: -pet.shownTop
          width: view.size
          height: view.size
          source: view.spriteUrl
          frameWidth: 32
          frameHeight: 32
          frameX: 0
          frameY: pet.anim.row * 32
          frameCount: pet.anim.frames
          // With music on, a sitting pet's tail keeps a quicker beat.
          frameRate: pet.mode === "sit" && root.music ? pet.anim.fps * 2.5 : pet.anim.fps
          interpolate: false
          smooth: false
          transform: Scale { origin.x: view.size / 2; xScale: pet.dir }
        }
      }

      MouseArea {
        property real grabX: 0
        property real grabY: 0

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => { grabX = mouse.x; grabY = mouse.y }
        onPositionChanged: mouse => {
          if (!view.brain) return
          if (view.brain.mode !== "held") {
            if (Math.abs(mouse.x - grabX) + Math.abs(mouse.y - grabY) < 6) return
            Brain.grab(view.brain)
          }
          view.brain.x = pet.x + mouse.x - grabX
          view.brain.y = pet.y + mouse.y - grabY
          view.sync()
        }
        onReleased: {
          if (!view.brain) return
          if (view.brain.mode === "held") Brain.drop(view.brain)
          else Brain.pet(view.brain)
          view.sync()
        }
      }
    }

    // Name tag, shown while she is being petted. Not in the input mask, so it never blocks clicks.
    Rectangle {
      visible: pet.mode === "petted" && view.name !== ""
      x: Math.round(pet.x + (view.size - width) / 2)
      y: pet.y - height - 4
      width: nameText.implicitWidth + 14
      height: nameText.implicitHeight + 6
      radius: 4
      color: "#e61e1e2e"
      border.color: "#966a3a"
      border.width: 1

      Text {
        id: nameText
        anchors.centerIn: parent
        text: view.name
        color: "#fff6e8"
        font.pixelSize: 13
        font.bold: true
      }
    }

    // Thought bubble over a dreaming pet's head. Not in the input mask either.
    Rectangle {
      id: bubble
      readonly property bool ofFriend: view.dream === "friend"
      visible: view.dream !== ""
      x: Math.round(pet.x + (pet.dir > 0 ? 0.62 : 0.38) * view.size - width / 2)
      y: Math.round(pet.y + view.size * 0.3 - height)
      width: 12 * view.px + 10
      height: width
      radius: width / 2
      color: "#f2fff6e8"
      border.color: "#966a3a"
      border.width: 1

      Image {
        anchors.centerIn: parent
        width: 12 * view.px
        height: width
        // The other pet, sitting, or her own toy.
        source: bubble.ofFriend ? root.spriteUrlOf(view.species === "dog" ? "cat" : "dog") : view.spriteUrl
        sourceClipRect: bubble.ofFriend ? Qt.rect(0, Brain.ANIMS.sit.row * 32, 32, 32) : Qt.rect(0, Brain.YARN_ROW * 32, 12, 12)
        smooth: false
      }
      Rectangle {
        x: parent.width * (pet.dir > 0 ? 0.1 : 0.7)
        y: parent.height + 2
        width: 6
        height: 6
        radius: 3
        color: parent.color
        border.color: parent.border.color
        border.width: 1
      }
    }

    Item {
      id: ball

      property bool shown: false
      property int frame: 0

      visible: shown
      // Zero size when hidden so it drops out of the input mask.
      width: shown ? view.ballSize : 0
      height: width

      Image {
        anchors.fill: parent
        source: view.spriteUrl
        sourceClipRect: Qt.rect(ball.frame * 32, Brain.YARN_ROW * 32, 12, 12)
        smooth: false
      }

      // Pick the ball up and throw it.
      MouseArea {
        property real grabX: 0
        property real grabY: 0
        property real vx: 0
        property real vy: 0
        property real lastT: 0

        anchors.fill: parent
        cursorShape: Qt.OpenHandCursor
        onPressed: mouse => {
          if (!view.brain || !view.brain.ball) return
          grabX = mouse.x; grabY = mouse.y
          vx = vy = 0
          lastT = Date.now()
          view.brain.ball.held = true
        }
        onPositionChanged: mouse => {
          var o = view.brain ? view.brain.ball : null
          if (!o || !o.held) return
          var now = Date.now(), dt = Math.max(1, now - lastT) / 1000
          var nx = ball.x + mouse.x - grabX, ny = ball.y + mouse.y - grabY
          vx = (nx - o.x) / dt; vy = (ny - o.y) / dt
          lastT = now
          o.x = nx; o.y = ny
          view.sync()
        }
        onReleased: {
          var o = view.brain ? view.brain.ball : null
          if (!o) return
          var fresh = Date.now() - lastT < 100   // a throw, not a let-go after holding still
          o.vx = fresh ? Math.max(-1500, Math.min(1500, vx)) : 0
          o.vy = fresh ? Math.max(-1500, Math.min(1500, vy)) : 0
          o.life = Brain.BALL_LIFE
          o.held = false
        }
      }
    }
  }
}
