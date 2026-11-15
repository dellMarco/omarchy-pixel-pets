import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "Brain.js" as Brain

Item {
  id: root

  property int pixelScale: 3
  readonly property int size: 32 * pixelScale

  PanelWindow {
    id: win

    // Brain state; created once the window has a size.
    property var cat: null
    readonly property var bounds: ({
      w: width - root.size,
      floor: height - root.size,
      size: root.size,
      grip: 2 * root.pixelScale,
      ledges: ledges
    })

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
    Connections {
      target: Hyprland
      function onRawEvent(event) { Hyprland.refreshToplevels() }
    }
    Timer {
      interval: 1000
      running: true
      repeat: true
      triggeredOnStart: true
      onTriggered: { Hyprland.refreshToplevels(); win.refreshLedges() }
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "pixel-pets"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Only the pet takes input; everything else clicks through to the apps below.
    mask: Region { item: pet }

    function sync() {
      pet.x = Math.round(cat.x)
      pet.y = Math.round(cat.y)
      pet.dir = cat.dir
      pet.mode = cat.mode
    }

    Timer {
      interval: 33
      running: win.width > 0 && win.height > 0
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
      property int dir: 1
      readonly property var anim: Brain.ANIMS[mode]

      width: root.size
      height: root.size

      AnimatedSprite {
        anchors.fill: parent
        source: Qt.resolvedUrl("sprites/cat.png")
        frameWidth: 32
        frameHeight: 32
        frameX: 0
        frameY: pet.anim.row * 32
        frameCount: pet.anim.frames
        frameRate: pet.anim.fps
        interpolate: false
        smooth: false
        transform: Scale { origin.x: root.size / 2; xScale: pet.dir }
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
          if (win.cat.mode === "held") Brain.drop(win.cat)
          else Brain.pet(win.cat)
          win.sync()
        }
      }
    }
  }
}
