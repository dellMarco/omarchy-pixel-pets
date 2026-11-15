import QtQuick
import qs.Commons
import qs.Ui
import "Brain.js" as Brain

// Bar button + settings panel. Settings live on the pet service (Service.qml),
// which saves them; this file only reads and writes them.
Panel {
  id: root
  moduleName: "skrilexxx.pixel-pets"

  readonly property var coats: [
    { value: "orange", label: "Orange" },
    { value: "grey", label: "Grey" },
    { value: "black", label: "Tuxedo" },
    { value: "white", label: "White" },
    { value: "cream", label: "Cream" }
  ]

  // The service is created independently of the bar, so look it up when needed.
  property var pet: null
  function findPet() {
    var shell = root.bar ? root.bar.shell : null
    pet = shell && typeof shell.serviceFor === "function" ? shell.serviceFor(root.moduleName) : null
  }
  readonly property var store: pet ? pet.settings : null
  function set(key, value) { if (store) store[key] = value }

  onOpenedChanged: if (opened) findPet()
  Component.onCompleted: findPet()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: String.fromCodePoint(0xF011B)   // nf-md-cat
    tooltipText: ""
    dimmed: root.store ? !root.store.shown : false
    onPressed: function(b) {
      if (b === Qt.RightButton) {
        root.findPet()
        root.set("shown", !(root.store && root.store.shown))
      } else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        Text {
          visible: !root.store
          width: parent.width
          wrapMode: Text.WordWrap
          text: "The pet isn't running. Enable it with: omarchy plugin enable skrilexxx.pixel-pets"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
        }

        // ---------- Hero: live preview · name ----------
        Item {
          visible: !!root.store
          width: parent.width
          implicitHeight: preview.height

          AnimatedSprite {
            id: preview
            width: 64
            height: 64
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            source: root.pet ? root.pet.spriteUrl : ""
            frameWidth: 32
            frameHeight: 32
            frameY: Brain.ANIMS.idle.row * 32
            frameCount: Brain.ANIMS.idle.frames
            frameRate: Brain.ANIMS.idle.fps
            running: root.opened
            interpolate: false
            smooth: false
          }

          Column {
            anchors.left: preview.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            PanelSectionHeader {
              text: "NAME"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
            }

            TextField {
              id: nameField
              width: parent.width
              text: root.store ? root.store.name : ""
              maximumLength: 24
              placeholderText: "Give her a name"
              foreground: root.bar.foreground
              font.family: root.bar.fontFamily
              onEditingFinished: root.set("name", text.trim())
            }
          }
        }

        PanelSeparator { visible: !!root.store; foreground: root.bar.foreground }

        Section {
          title: "COAT"
          ButtonGroup {
            width: parent.width
            options: root.coats
            value: root.store ? root.store.coat : ""
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            fontSize: Style.font.bodySmall
            onChanged: function(v) { root.set("coat", v) }
          }
        }

        Section {
          title: "SIZE"
          ButtonGroup {
            width: parent.width
            options: [
              { value: "small", label: "Small" },
              { value: "medium", label: "Medium" },
              { value: "large", label: "Large" }
            ]
            value: root.store ? root.store.size : ""
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            fontSize: Style.font.bodySmall
            onChanged: function(v) { root.set("size", v) }
          }
        }

        Section {
          title: "ENERGY"
          PanelSlider {
            width: parent.width
            bar: root.bar
            value: root.store ? root.store.energy : 0.5
            minimum: 0
            maximum: 1
            step: 0.1
            onReleased: function(v) { root.set("energy", v) }
          }
          Item {
            width: parent.width
            implicitHeight: lazyLabel.implicitHeight
            Text {
              id: lazyLabel
              text: "Lazy"
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              anchors.right: parent.right
              text: "Playful"
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        PanelSeparator { visible: !!root.store; foreground: root.bar.foreground }

        Column {
          visible: !!root.store
          width: parent.width
          spacing: Style.space(6)

          Toggle {
            width: parent.width
            label: "Show pet"
            description: "Right-click the bar icon to toggle quickly"
            checked: root.store ? root.store.shown : false
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            onClicked: root.set("shown", !checked)
          }
          Toggle {
            width: parent.width
            label: "Chase the mouse"
            checked: root.store ? root.store.chaseMouse : false
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            onClicked: root.set("chaseMouse", !checked)
          }
          Toggle {
            width: parent.width
            label: "Hang from windows"
            checked: root.store ? root.store.hangOnWindows : false
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            onClicked: root.set("hangOnWindows", !checked)
          }
        }

        Button {
          visible: !!root.store
          width: parent.width
          iconText: String.fromCodePoint(0xF03E9)   // nf-md-paw
          text: "Give yarn ball"
          bordered: true
          enabled: root.store ? root.store.shown : false
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          onClicked: if (root.pet) root.pet.giveBall()
        }
      }
    }
  }

  component Section: Column {
    property string title: ""
    visible: !!root.store
    width: parent.width
    spacing: Style.space(8)

    PanelSectionHeader {
      text: parent.title
      foreground: root.bar.foreground
      fontFamily: root.bar.fontFamily
    }
  }
}
