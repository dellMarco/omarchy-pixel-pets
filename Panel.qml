import QtQuick
import qs.Commons
import qs.Ui
import "Brain.js" as Brain

// Bar button + settings panel. Settings live on the pet service (Service.qml),
// which saves them; this file only reads and writes them.
Panel {
  id: root
  moduleName: "skrilexxx.pixel-pets"

  // Per species: the settings that hold its name and coat, its coats (sheets in sprites/) and toy.
  readonly property var species: ({
    cat: {
      label: "Cat", nameKey: "name", coatKey: "coat", toy: "Give yarn ball",
      coats: [
        { value: "orange", label: "Orange" },
        { value: "grey", label: "Grey" },
        { value: "black", label: "Tuxedo" },
        { value: "white", label: "White" },
        { value: "cream", label: "Cream" }
      ]
    },
    dog: {
      label: "Dog", nameKey: "dogName", coatKey: "dogCoat", toy: "Throw tennis ball",
      coats: [
        { value: "golden", label: "Golden" },
        { value: "shiba", label: "Shiba" },
        { value: "husky", label: "Husky" },
        { value: "dalmatian", label: "Dalmatian" },
        { value: "chocolate", label: "Choco" }
      ]
    }
  })
  // The species that are out: one of them, or both.
  readonly property var out: Object.keys(species).filter(function(k) {
    return store && (store.species === k || store.species === "both")
  })
  // nf-md-cat, nf-md-dog, or nf-md-paw for both
  readonly property int icon: out.length > 1 ? 0xF03E9 : out[0] === "dog" ? 0xF0A43 : 0xF011B

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
    text: String.fromCodePoint(root.icon)
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

        Section {
          title: "PETS"
          ButtonGroup {
            width: parent.width
            options: [
              { value: "cat", label: "Cat" },
              { value: "dog", label: "Dog" },
              { value: "both", label: "Both" }
            ]
            value: root.store ? root.store.species : ""
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            fontSize: Style.font.bodySmall
            onChanged: function(v) { root.set("species", v) }
          }
          Hint { text: "With both out they visit each other, play, nap side by side, and the dog sometimes chases the cat." }
        }

        // ---------- Per pet: live preview · name · coat ----------
        Repeater {
          model: root.out

          Column {
            id: card
            required property string modelData
            readonly property var kind: root.species[modelData]

            width: column.width
            spacing: Style.space(8)

            PanelSeparator { foreground: root.bar.foreground }

            Item {
              width: parent.width
              implicitHeight: preview.height

              AnimatedSprite {
                id: preview
                width: 64
                height: 64
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                source: root.pet ? root.pet.spriteUrlOf(card.modelData) : ""
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
                  text: card.kind.label.toUpperCase() + "'S NAME"
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                }

                TextField {
                  width: parent.width
                  text: root.store ? root.store[card.kind.nameKey] : ""
                  maximumLength: 24
                  placeholderText: "Give your pet a name"
                  foreground: root.bar.foreground
                  font.family: root.bar.fontFamily
                  onEditingFinished: root.set(card.kind.nameKey, text.trim())
                }
              }
            }

            ButtonGroup {
              width: parent.width
              options: card.kind.coats
              value: root.pet ? root.pet.coatOf(card.modelData) : ""
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              fontSize: Style.font.bodySmall
              onChanged: function(v) { root.set(card.kind.coatKey, v) }
            }
          }
        }

        PanelSeparator { visible: !!root.store; foreground: root.bar.foreground }

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
          Hint { text: "Sets both. The dog is always one step bigger than the cat." }
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
          Hint {
            text: "How much they walk and play instead of sleeping, and how often they do things on their own: "
              + "visits, the dog chasing the cat (not when lazy), zoomies (only near playful). "
              + "Toys they bring on their own (dog four times a day, cat once) and how often they "
              + "wander off screen don't depend on it."
          }
        }

        PanelSeparator { visible: !!root.store; foreground: root.bar.foreground }

        Column {
          visible: !!root.store
          width: parent.width
          spacing: Style.space(6)

          Toggle {
            width: parent.width
            label: "Show pets"
            description: "Hides or shows whoever is picked above. Right-click the bar icon does the same"
            checked: root.store ? root.store.shown : false
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            onClicked: root.set("shown", !checked)
          }
          Toggle {
            width: parent.width
            label: "Follow time of day"
            description: root.store && root.store.dayCycle && root.pet ? Brain.dayPhase(root.pet.hour)
              : "Off: energy stays where the slider is, all day. On: lively mornings, sleepy evenings and nights around it"
            checked: root.store ? root.store.dayCycle : false
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            onClicked: root.set("dayCycle", !checked)
          }
          Toggle {
            width: parent.width
            label: "Camera shy"
            description: "Both run off screen while the screen or a window is shared or recorded, and come back about 15 seconds after it stops"
            checked: root.store ? root.store.cameraShy : false
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            onClicked: root.set("cameraShy", !checked)
          }
          Toggle {
            width: parent.width
            label: "Stalk the pointer"
            description: "They crouch and pounce at the pointer when it moves near the bottom edge. Off: they ignore it, and a toy they bring is dropped anywhere, not below the pointer"
            checked: root.store ? root.store.chaseMouse : false
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            onClicked: root.set("chaseMouse", !checked)
          }
          Toggle {
            visible: root.out.some(function(k) { return Brain.traits({ species: k }).climbs })
            width: parent.width
            label: "Cat climbs windows"
            description: "She climbs a window and peeks over its top edge, on her own and to escape when the dog chases her. Off: she stays on the floor and escapes by running off screen"
            checked: root.store ? root.store.hangOnWindows : false
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            onClicked: root.set("hangOnWindows", !checked)
          }
        }

        Repeater {
          model: root.out

          Button {
            required property string modelData
            width: column.width
            iconText: String.fromCodePoint(0xF03E9)   // nf-md-paw
            text: root.species[modelData].toy
            bordered: true
            enabled: root.store ? root.store.shown : false
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            onClicked: if (root.pet) root.pet.giveBall(modelData)
          }
        }
      }
    }
  }

  // A line of small print under a control, saying what it reaches.
  component Hint: Text {
    width: parent.width
    wrapMode: Text.WordWrap
    color: Qt.darker(root.bar.foreground, 1.4)
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.caption
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
