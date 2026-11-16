import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "Brain.js" as Brain

Item {
  id: root

  // Settings, edited from the bar panel (Panel.qml) and saved to disk.
  readonly property alias settings: store
  readonly property string spriteUrl: Qt.resolvedUrl("sprites/cat-" + store.coat + ".png")
  readonly property int pixelScale: ({ small: 2, medium: 3, large: 4 })[store.size] || 3
  readonly property int size: 32 * pixelScale
  readonly property int ballSize: 12 * pixelScale

  // Local time as a fractional hour, refreshed every minute, for the day cycle.
  property real hour: 0
  function updateHour() {
    var d = new Date()
    hour = d.getHours() + d.getMinutes() / 60
  }
  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: { root.updateHour(); root.remind() }
  }

  // Care reminders: when a need is overdue she sits and asks for it until you click her.
  property var lastServed: ({ water: Date.now(), food: Date.now(), break: Date.now() })
  function remind() {
    var cat = win.cat
    if (!store.reminders || !store.shown || idle.isIdle || !cat || cat.want) return
    var mins = { water: store.waterMinutes, food: store.foodMinutes, break: store.breakMinutes }
    var now = Date.now(), due = null, most = 0
    for (var k in mins) {
      var over = now - lastServed[k] - mins[k] * 60000
      if (over >= 0 && over >= most) { due = k; most = over }
    }
    if (due) Brain.want(cat, due)
  }
  function forget() {
    var now = Date.now()
    lastServed = { water: now, food: now, break: now }
    if (win.cat) Brain.want(win.cat, null)
  }
  // Away for 5+ minutes (idle, locked, asleep): start counting again from when you're back.
  IdleMonitor {
    id: idle
    timeout: 300
    onIsIdleChanged: if (!isIdle) root.forget()
  }

  function giveBall() {
    if (!win.cat || !store.shown) return
    Brain.spawnBall(win.cat, win.bounds)
    win.sync()
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
      property string coat: "orange"
      property string size: "medium"
      property real energy: 0.5
      property bool shown: true
      property bool chaseMouse: true
      property bool hangOnWindows: true
      property bool dayCycle: true
      property bool reminders: true
      property int waterMinutes: 45
      property int foodMinutes: 240
      property int breakMinutes: 60
      onRemindersChanged: if (!reminders) root.forget()
    }
  }

  PanelWindow {
    id: win

    // Brain state; created once the window has a size.
    property var cat: null
    readonly property var bounds: ({
      w: width - root.size,
      floor: height - root.size,
      size: root.size,
      peek: 10 * root.pixelScale,   // rows of the peek frame above the edge (PEEK_EDGE in make_sprites.py)
      ledges: store.hangOnWindows ? ledges : [],
      ballSize: root.ballSize,
      cursor: store.chaseMouse ? cursor : null,
      energy: store.dayCycle ? Brain.effectiveEnergy(store.energy, root.hour) : store.energy
    })

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
      // Only while she could react to it.
      running: win.cat !== null && store.shown && store.chaseMouse && Brain.watchesCursor(pet.mode)
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
          if (o.size[0] < root.size || o.size[1] < root.size * 1.5) continue
          out.push({ id: o.address, x: o.at[0] - mon.x, y: o.at[1] - mon.y, w: o.size[0] })
        }
      }
      ledges = out
    }

    // Hyprland sends no event when a tile is resized, so poll as well as listen.
    // Only while windows matter: a shown cat that may climb.
    readonly property bool climbing: store.shown && store.hangOnWindows
    onClimbingChanged: if (!climbing) ledges = []
    Connections {
      target: Hyprland
      enabled: win.climbing
      function onRawEvent(event) { Hyprland.refreshToplevels() }
    }
    Timer {
      interval: 1000
      running: win.climbing
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
    // Only the pet takes input; everything else clicks through to the apps below.
    // Only her visible part takes clicks. Explicit geometry rather than `item:` a child of pet:
    // a Region only follows its own item's x/y, so a nested item leaves the region behind when she walks.
    mask: Region {
      x: pet.x
      y: pet.y + pet.shownTop
      width: pet.shownHeight > 0 ? pet.width : 0
      height: pet.shownHeight
      Region { item: ball }
    }

    function sync() {
      pet.x = Math.round(cat.x)
      pet.y = Math.round(cat.y)
      pet.dir = cat.dir
      pet.mode = cat.mode
      pet.want = cat.want || ""
      pet.nag = cat.nag
      // On a window, the top edge hides whatever part of her is on the far side of it.
      var top = Math.max(0, Math.min(root.size, Math.round(cat.clipTop - cat.y)))
      var bottom = Math.max(top, Math.min(root.size, Math.round(cat.clipBottom - cat.y)))
      pet.shownTop = top
      pet.shownHeight = bottom - top
      if (cat.ball) {
        ball.x = Math.round(cat.ball.x)
        ball.y = Math.round(cat.ball.y)
        ball.frame = Brain.yarnFrame(cat.ball, root.ballSize)
      }
      ball.shown = cat.ball !== null
    }

    Timer {
      interval: Brain.tickInterval(pet.mode, ball.shown)
      running: store.shown && win.width > 0 && win.height > 0
      repeat: true
      onTriggered: {
        if (!win.cat) win.cat = Brain.create(win.bounds.w / 2, win.bounds.floor)
        // Windows can vanish under her at any moment, so recheck every tick while she is on one.
        if (win.cat.goal !== null) win.refreshLedges()
        Brain.tick(win.cat, interval / 1000, win.bounds, Math.random)
        win.sync()
      }
    }

    Item {
      id: pet

      property string mode: "idle"
      property string want: ""
      property bool nag: false
      property int dir: 1
      property int shownTop: 0
      property int shownHeight: root.size
      readonly property var anim: Brain.ANIMS[mode]

      width: root.size
      height: root.size

      // The visible part of her, which is also all that takes clicks.
      Item {
        id: shownPart
        y: pet.shownTop
        width: root.size
        height: pet.shownHeight
        clip: true
        // See-through while climbing over a window, so she doesn't distract from what's on it.
        opacity: pet.mode === "climb" || pet.mode === "descend" ? 0.4 : 1

        Behavior on opacity {
          NumberAnimation { duration: 600; easing.type: Easing.InOutQuad }
        }

        // The whole sheet, slid behind a one-frame window. Not AnimatedSprite: that one makes
        // Qt redraw this full-screen layer every vsync; this only repaints when the frame changes.
        Item {
          y: -pet.shownTop
          width: root.size
          height: root.size
          clip: true
          transform: Scale { origin.x: root.size / 2; xScale: pet.dir }

          Image {
            x: -pet.frame * root.size
            y: -pet.anim.row * root.size
            width: implicitWidth * root.pixelScale
            height: implicitHeight * root.pixelScale
            source: root.spriteUrl
            smooth: false
          }
        }
      }

      property int frame: 0
      onModeChanged: frame = 0
      Timer {
        interval: 1000 / pet.anim.fps
        running: store.shown
        repeat: true
        onTriggered: pet.frame = (pet.frame + 1) % pet.anim.frames
      }

      MouseArea {
        property real grabX: 0
        property real grabY: 0

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => { grabX = mouse.x; grabY = mouse.y }
        onPositionChanged: mouse => {
          if (!win.cat) return
          if (win.cat.mode !== "held") {
            if (Math.abs(mouse.x - grabX) + Math.abs(mouse.y - grabY) < 6) return
            Brain.grab(win.cat)
          }
          win.cat.x = pet.x + mouse.x - grabX
          win.cat.y = pet.y + mouse.y - grabY
          win.sync()
        }
        onReleased: {
          if (!win.cat) return
          var w = win.cat.want
          if (win.cat.mode === "held") Brain.drop(win.cat)
          else Brain.pet(win.cat, win.bounds)
          if (w && !win.cat.want) root.lastServed[w] = Date.now()
          win.sync()
        }
        onDoubleClicked: {
          if (!win.cat) return
          Brain.spawnBall(win.cat, win.bounds)
          win.sync()
        }
      }
    }

    // Name tag, shown while she is being petted. Not in the input mask, so it never blocks clicks.
    Rectangle {
      visible: pet.mode === "petted" && store.name !== ""
      x: Math.round(pet.x + (root.size - width) / 2)
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
        text: store.name
        color: "#fff6e8"
        font.pixelSize: 13
        font.bold: true
      }
    }

    // Speech bubble by her head while she asks for something; bounces once she has been ignored.
    // Not in the input mask: clicking her is how you serve it.
    Item {
      id: bubble
      property int bob: 0
      visible: pet.want !== "" && (pet.mode === "ask" || pet.mode === "walk")
      width: 16 * root.pixelScale
      height: 14 * root.pixelScale
      x: pet.dir > 0 ? pet.x + 21 * root.pixelScale : pet.x + root.size - 37 * root.pixelScale
      y: pet.y - (9 + bob) * root.pixelScale
      transform: Scale { origin.x: bubble.width / 2; xScale: pet.dir }

      Image {
        anchors.fill: parent
        source: root.spriteUrl
        sourceClipRect: Qt.rect((Brain.BUBBLES[pet.want] || 0) * 32, Brain.BUBBLE_ROW * 32, 16, 14)
        smooth: false
      }

      Timer {
        interval: 333
        running: bubble.visible && pet.nag
        repeat: true
        onTriggered: bubble.bob = 1 - bubble.bob
        onRunningChanged: if (!running) bubble.bob = 0
      }
    }

    Item {
      id: ball

      property bool shown: false
      property int frame: 0

      visible: shown
      // Zero size when hidden so it drops out of the input mask.
      width: shown ? root.ballSize : 0
      height: width

      Image {
        anchors.fill: parent
        source: root.spriteUrl
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
          if (!win.cat || !win.cat.ball) return
          grabX = mouse.x; grabY = mouse.y
          vx = vy = 0
          lastT = Date.now()
          win.cat.ball.held = true
        }
        onPositionChanged: mouse => {
          var o = win.cat ? win.cat.ball : null
          if (!o || !o.held) return
          var now = Date.now(), dt = Math.max(1, now - lastT) / 1000
          var nx = ball.x + mouse.x - grabX, ny = ball.y + mouse.y - grabY
          vx = (nx - o.x) / dt; vy = (ny - o.y) / dt
          lastT = now
          o.x = nx; o.y = ny
          win.sync()
        }
        onReleased: {
          var o = win.cat ? win.cat.ball : null
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
