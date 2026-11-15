import QtQuick
import Quickshell
import Quickshell.Wayland
import "Brain.js" as Brain

Item {
  id: root

  property int pixelScale: 3
  readonly property int size: 32 * pixelScale

  PanelWindow {
    id: win

    // Brain state; created once the window has a size.
    property var cat: null
    readonly property var bounds: ({ w: width - root.size, floor: height - root.size })

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
