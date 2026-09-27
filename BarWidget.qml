import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Calculator.js" as Calculator

Panel {
  id: root
  moduleName: "io.github.enobale.kneadra"
  // `qs -p /usr/share/omarchy/shell ipc call io.github.enobale.kneadra toggle`
  // — lets a Hyprland keybind open the calculator.
  ipcTarget: "io.github.enobale.kneadra"

  // Display units only: all state below stays in inches / °F / oz/in².
  property bool metric: false

  // ---- dough balls ----
  property int ballCount: 4
  property string shape: "round" // round | pan
  // Real, not int: a size typed in cm (30 cm = 11.81") is kept exactly.
  property real sizeIn: 12 // round diameter, inches
  property real panWidthIn: 12 // pan/rectangular, inches
  property real panLengthIn: 16
  property string thickness: "medium" // thin | medium | thick | custom
  property real thicknessFactorOz: Calculator.thicknessFactorOzFor("medium") // TF, oz/in² — advanced override
  property bool advancedOpen: false
  property int ballWeight: Calculator.suggestedWeightFromArea(
    Calculator.roundAreaIn2(12), Calculator.thicknessFactorOzFor("medium"))

  readonly property real areaIn2: root.shape === "pan"
    ? Calculator.panAreaIn2(root.panWidthIn, root.panLengthIn)
    : Calculator.roundAreaIn2(root.sizeIn)

  // ---- baker's percentages (of flour weight) ----
  property real hydrationPct: 65
  property real saltPct: 2.5
  property real oilPct: 2
  property real sugarPct: 1
  // Diastatic malt powder: optional, only for extra browning in a home oven.
  property real maltPct: 0

  // ---- fermentation ----
  property real fermentTempF: 70
  property real fermentHours: 4
  property string yeastType: "idy" // idy | ady | fresh

  readonly property real idyPct: Calculator.idyPercentForHours(root.fermentHours, root.fermentTempF)
  readonly property string fermentNote: Calculator.fermentRangeNote(root.fermentHours, root.fermentTempF, root.metric)
  readonly property var recipe: Calculator.computeRecipe({
    ballWeight: root.ballWeight,
    ballCount: root.ballCount,
    hydrationPct: root.hydrationPct,
    saltPct: root.saltPct,
    oilPct: root.oilPct,
    sugarPct: root.sugarPct,
    maltPct: root.maltPct,
    idyPct: root.idyPct,
    yeastType: root.yeastType
  })

  function recomputeBallWeight() {
    root.ballWeight = Calculator.suggestedWeightFromArea(root.areaIn2, root.thicknessFactorOz)
  }

  function selectShape(value) {
    root.shape = value
    root.recomputeBallWeight()
  }

  // Size setters take inches; callers convert from display units.
  function setDiameter(inches) {
    root.sizeIn = inches
    root.recomputeBallWeight()
  }

  function setPanWidth(v) {
    root.panWidthIn = v
    root.recomputeBallWeight()
  }

  function setPanLength(v) {
    root.panLengthIn = v
    root.recomputeBallWeight()
  }

  function selectThicknessPreset(value) {
    root.thickness = value
    root.thicknessFactorOz = Calculator.thicknessFactorOzFor(value)
    root.recomputeBallWeight()
  }

  function setThicknessFactor(v) {
    root.thickness = "custom"
    root.thicknessFactorOz = v
    root.recomputeBallWeight()
  }

  function selectFermentPreset(tempF) {
    root.fermentTempF = tempF
  }

  // ---- share / print ----
  property bool copied: false
  Timer { id: copiedTimer; interval: 2000; onTriggered: root.copied = false }

  function shareInput() {
    return {
      ballCount: root.ballCount,
      ballWeight: root.ballWeight,
      shape: root.shape,
      sizeIn: root.sizeIn,
      panWidthIn: root.panWidthIn,
      panLengthIn: root.panLengthIn,
      thicknessLabel: Calculator.thicknessLabelFor(root.thickness),
      hydrationPct: root.hydrationPct,
      saltPct: root.saltPct,
      oilPct: root.oilPct,
      sugarPct: root.sugarPct,
      maltPct: root.maltPct,
      yeastType: root.yeastType,
      fermentHours: root.fermentHours,
      fermentTempF: root.fermentTempF,
      metric: root.metric,
      recipe: root.recipe
    }
  }

  function copyRecipe() {
    Quickshell.clipboardText = Calculator.formatRecipeText(root.shareInput())
    root.copied = true
    copiedTimer.restart()
  }

  // Rendered as HTML and handed to the desktop's default handler (usually
  // the browser) rather than driven through CUPS directly: that gets us a
  // real print dialog — printer selection, "Save as PDF" — for free, with
  // no dependency on a specific print stack being configured.
  function printRecipe() {
    recipeFile.setText(Calculator.formatRecipeHtml(root.shareInput()))
    Util.execArgv(["xdg-open", recipeFile.path])
  }

  // ---- remembered settings ----
  // Every setting is saved (debounced) to a small JSON file and restored at
  // startup, so the recipe survives shell restarts and reboots.
  readonly property string settingsDir: Quickshell.env("HOME") + "/.local/state/omarchy"
  readonly property var settingsDefaults: ({
    metric: false, ballCount: 4, shape: "round", sizeIn: 12, panWidthIn: 12, panLengthIn: 16,
    thickness: "medium", thicknessFactorOz: Calculator.thicknessFactorOzFor("medium"),
    ballWeight: Calculator.suggestedWeightFromArea(Calculator.roundAreaIn2(12), Calculator.thicknessFactorOzFor("medium")),
    hydrationPct: 65, saltPct: 2.5, oilPct: 2, sugarPct: 1, maltPct: 0,
    fermentTempF: 70, fermentHours: 4, yeastType: "idy"
  })
  // Numbers are clamped to what the controls allow; strings must be one of
  // the listed choices.
  readonly property var settingsRanges: ({
    ballCount: [1, 24], sizeIn: [5.9, 30], panWidthIn: [3.9, 30], panLengthIn: [3.9, 30],
    thicknessFactorOz: [0.05, 0.30], ballWeight: [50, 2000],
    hydrationPct: [50, 90], saltPct: [0, 4], oilPct: [0, 10], sugarPct: [0, 5], maltPct: [0, 2],
    fermentTempF: [33, 90], fermentHours: [1, 240],
    shape: ["round", "pan"], thickness: ["thin", "medium", "thick", "custom"], yeastType: ["idy", "ady", "fresh"]
  })
  readonly property string settingsJson: JSON.stringify({
    version: 1, metric: root.metric, ballCount: root.ballCount, shape: root.shape,
    sizeIn: root.sizeIn, panWidthIn: root.panWidthIn, panLengthIn: root.panLengthIn,
    thickness: root.thickness, thicknessFactorOz: root.thicknessFactorOz, ballWeight: root.ballWeight,
    hydrationPct: root.hydrationPct, saltPct: root.saltPct, oilPct: root.oilPct,
    sugarPct: root.sugarPct, maltPct: root.maltPct,
    fermentTempF: root.fermentTempF, fermentHours: root.fermentHours, yeastType: root.yeastType
  }, null, 2)
  property bool settingsLoaded: false

  onSettingsJsonChanged: if (root.settingsLoaded) settingsSaveTimer.restart()

  function restoreSettings(raw) {
    // FileView can report a load more than once at startup; only the first
    // counts, or a late duplicate would undo the user's first edits.
    if (root.settingsLoaded) return
    var saved = null
    try { saved = raw ? JSON.parse(raw) : null } catch (e) { saved = null }
    var s = Calculator.sanitizeSettings(saved, root.settingsDefaults, root.settingsRanges)
    // Assigned directly (not via the setters) so a hand-set ball weight
    // isn't recomputed away.
    root.metric = s.metric
    root.ballCount = s.ballCount
    root.shape = s.shape
    root.sizeIn = s.sizeIn
    root.panWidthIn = s.panWidthIn
    root.panLengthIn = s.panLengthIn
    root.thickness = s.thickness
    root.thicknessFactorOz = s.thicknessFactorOz
    root.ballWeight = Math.round(s.ballWeight)
    root.hydrationPct = s.hydrationPct
    root.saltPct = s.saltPct
    root.oilPct = s.oilPct
    root.sugarPct = s.sugarPct
    root.maltPct = s.maltPct
    root.fermentTempF = s.fermentTempF
    root.fermentHours = s.fermentHours
    root.yeastType = s.yeastType
    root.settingsLoaded = true
  }

  Timer {
    id: settingsSaveTimer
    interval: 400
    onTriggered: settingsFile.setText(root.settingsJson + "\n")
  }

  FileView {
    id: settingsFile
    path: root.settingsDir + "/io.github.enobale.kneadra.json"
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.restoreSettings(text())
    // First run: no file yet. Start from the defaults and save from here on.
    onLoadFailed: root.restoreSettings("")
  }

  // Omarchy creates this directory itself; make sure anyway, so the first
  // save can't fail on an unusual install.
  Component.onCompleted: Util.execArgv(["mkdir", "-p", root.settingsDir])

  FileView {
    id: recipeFile
    path: Quickshell.cacheDir + "/kneadra-recipe.html"
    atomicWrites: true
    printErrors: false
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // A labeled slider: name + live value (with unit suffix) on top, PanelSlider
  // below. Used for baker's percentages ("%") and, in advanced mode, the
  // Thickness Factor ("oz/in²").
  component LabeledSlider: Column {
    id: labeledSlider
    property string label: ""
    property string unit: "%"
    property real value: 0
    property real minimum: 0
    property real maximum: 100
    property real step: 0.5
    property int decimals: 1
    // The panel's ScrollView Flickable — set by callers so a wheel tick
    // that lands on this slider mid-scroll moves the panel instead of the
    // slider's value. See the wheel-blocking MouseArea below.
    property Flickable scrollFlickable: null
    signal moved(real value)

    spacing: Style.spacing.xs

    Row {
      width: parent.width

      Text {
        id: sliderLabel
        textFormat: Text.PlainText
        text: labeledSlider.label
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      Item { width: parent.width - sliderLabel.implicitWidth - valueLabel.implicitWidth; height: 1 }

      Text {
        id: valueLabel
        textFormat: Text.PlainText
        text: labeledSlider.value.toFixed(labeledSlider.decimals) + labeledSlider.unit
        color: Qt.darker(Color.foreground, 1.2)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
    }

    Item {
      width: parent.width
      height: slider.implicitHeight

      PanelSlider {
        id: slider
        width: parent.width
        minimum: labeledSlider.minimum
        maximum: labeledSlider.maximum
        step: labeledSlider.step
        value: labeledSlider.value
        // PanelSlider leaves snapping to the caller, so a drag reports raw
        // values (e.g. 69.774 for a step-1 slider). Snap to `step` here so
        // the stored value matches the label and the copied/printed recipe.
        onMoved: function(v) {
          var snapped = Math.round(v / labeledSlider.step) * labeledSlider.step
          var clamped = Math.max(labeledSlider.minimum, Math.min(labeledSlider.maximum, snapped))
          var stepped = parseFloat(clamped.toFixed(6))
          // The slider just drew its knob at the raw pointer position; pull
          // it onto the step so knob, label and stored value always agree
          // (otherwise the knob glides back to the step on release).
          slider.liveValue = stepped
          labeledSlider.moved(stepped)
        }
      }

      // The panel scrolls, so a little vertical drift mid-drag lets its
      // Flickable steal the mouse grab and the drag just stops. Freeze
      // scrolling while a slider is held.
      Binding {
        target: labeledSlider.scrollFlickable
        property: "interactive"
        value: false
        when: slider.dragging && labeledSlider.scrollFlickable !== null
      }

      // qs.Ui's PanelSlider always treats a wheel-over as a value nudge,
      // with no opt-out — fine for a single slider, but inside a panel
      // that's mostly sliders, scrolling past one to reach the next
      // silently changes it. Swallow the wheel here (acceptedButtons:
      // NoButton keeps click/drag/hover falling through to the slider
      // underneath) and scroll the panel instead.
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: function(wheel) {
          var flick = labeledSlider.scrollFlickable
          if (flick) {
            var maxY = Math.max(0, flick.contentHeight - flick.height)
            var next = flick.contentY - (wheel.angleDelta.y / 120) * Style.space(48)
            flick.contentY = Math.max(0, Math.min(maxY, next))
          }
          wheel.accepted = true
        }
      }
    }
  }

  // Ingredient name ........ weight, like a printed recipe card.
  component RecipeRow: Item {
    id: recipeRow
    property string label: ""
    property string amount: ""
    width: parent.width
    implicitHeight: Math.max(nameLabel.implicitHeight, amountLabel.implicitHeight)

    Text {
      id: nameLabel
      anchors.left: parent.left
      textFormat: Text.PlainText
      text: recipeRow.label
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }

    Item {
      anchors.left: nameLabel.right
      anchors.right: amountLabel.left
      anchors.leftMargin: Style.spacing.sm
      anchors.rightMargin: Style.spacing.sm
      height: parent.height
      clip: true

      Text {
        anchors.right: parent.right
        anchors.baseline: parent.top
        anchors.baselineOffset: nameLabel.baselineOffset
        textFormat: Text.PlainText
        text: " .".repeat(60)
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.3)
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
    }

    Text {
      id: amountLabel
      anchors.right: parent.right
      textFormat: Text.PlainText
      text: recipeRow.amount
      color: Color.accent
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "🍕" // pizza slice emoji
    tooltipText: "Kneadra — pizza dough calculator"
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    // Settings on the left (scrolls), recipe card on the right (fixed), so
    // the grams stay in view while any slider moves.
    readonly property real columnGap: Style.spacing.panelGap * 2
    readonly property real columnWidth: (panel.contentWidth - panel.columnGap) / 2
    contentWidth: panel.fittedContentWidth(Style.space(340) * 2 + panel.columnGap)
    contentHeight: panel.fittedContentHeight(Math.max(panelColumn.implicitHeight, card.implicitHeight), Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      ScrollView {
        id: scrollArea
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: panel.columnWidth
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        // Qt's default lets the Flickable overshoot and spring back at the
        // ends, which reads as a bounce at the bottom of the panel. Every
        // first-party panel stops at the bounds instead.
        Binding {
          target: scrollArea.contentItem
          property: "boundsBehavior"
          value: Flickable.StopAtBounds
        }

        Column {
          id: panelColumn
          // Leave room for the overlay scrollbar: it floats on top of the
          // Flickable rather than reserving its own width, so content that
          // reaches the right edge (e.g. slider value labels) gets
          // covered by it while scrolling without this margin.
          width: scrollArea.availableWidth - Style.space(10)
          spacing: Style.spacing.panelGap

          Item {
            width: parent.width
            height: Math.max(titleRow.implicitHeight, unitsToggle.implicitHeight)

          Row {
            id: titleRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.md

            Text {
              textFormat: Text.PlainText
              text: "🍕"
              font.pixelSize: Style.font.heading
            }

            Column {
              Text {
                textFormat: Text.PlainText
                text: "Kneadra"
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
              }
              Text {
                textFormat: Text.PlainText
                text: "Pizza dough calculator"
                color: Qt.darker(Color.foreground, 1.4)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }
          }

            ButtonGroup {
              id: unitsToggle
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              fontSize: Style.font.bodySmall
              options: [
                { value: "us", label: "°F · in" },
                { value: "metric", label: "°C · cm" }
              ]
              value: root.metric ? "metric" : "us"
              onChanged: function(v) { root.metric = v === "metric" }
            }
          }

          PanelSeparator {}

          PanelSectionHeader { text: "Dough balls" }

          NumberField {
            label: "Number of balls"
            value: root.ballCount
            from: 1
            to: 24
            stepSize: 1
            onModified: function(v) { root.ballCount = v }
          }

          PanelSectionHeader { text: "Size" }
          ButtonGroup {
            options: [
              { value: "round", label: "Round" },
              { value: "pan", label: "Pan (rectangular)" }
            ]
            value: root.shape
            onChanged: function(v) { root.selectShape(v) }
          }

          ButtonGroup {
            visible: root.shape === "round"
            options: Calculator.sizePresets(root.metric).map(function(n) {
              return { value: String(n), label: n + (root.metric ? "" : "\"") }
            })
            value: String(Math.round(Calculator.lengthToDisplay(root.sizeIn, root.metric)))
            onChanged: function(v) { root.setDiameter(Calculator.lengthFromDisplay(parseInt(v, 10), root.metric)) }
          }

          // Rebuilt whenever the units change. SpinBox clamps its value to
          // from/to, and on a unit switch the new value can land before the
          // new range does (cm -> in: 12 clamped to the old 15 minimum,
          // then stuck). A fresh field applies range and value together.
          Repeater {
            model: [root.metric]
            NumberField {
              visible: root.shape === "round"
              label: "Diameter (" + (root.metric ? "cm" : "in") + ") — edit to override"
              value: Math.round(Calculator.lengthToDisplay(root.sizeIn, root.metric))
              from: root.metric ? 15 : 6
              to: root.metric ? 76 : 30
              stepSize: 1
              onModified: function(v) { root.setDiameter(Calculator.lengthFromDisplay(v, root.metric)) }
            }
          }

          Repeater {
            model: [root.metric]
            NumberField {
              visible: root.shape === "pan"
              label: "Pan width (" + (root.metric ? "cm" : "in") + ")"
              value: Math.round(Calculator.lengthToDisplay(root.panWidthIn, root.metric))
              from: root.metric ? 10 : 4
              to: root.metric ? 76 : 30
              stepSize: 1
              onModified: function(v) { root.setPanWidth(Calculator.lengthFromDisplay(v, root.metric)) }
            }
          }

          Repeater {
            model: [root.metric]
            NumberField {
              visible: root.shape === "pan"
              label: "Pan length (" + (root.metric ? "cm" : "in") + ")"
              value: Math.round(Calculator.lengthToDisplay(root.panLengthIn, root.metric))
              from: root.metric ? 10 : 4
              to: root.metric ? 76 : 30
              stepSize: 1
              onModified: function(v) { root.setPanLength(Calculator.lengthFromDisplay(v, root.metric)) }
            }
          }

          PanelSectionHeader { text: "Thickness" }
          ButtonGroup {
            options: [
              { value: "thin", label: "Thin" },
              { value: "medium", label: "Medium" },
              { value: "thick", label: "Thick / pan" }
            ]
            value: root.thickness
            onChanged: function(v) { root.selectThicknessPreset(v) }
          }

          Button {
            text: (root.advancedOpen ? "▾ " : "▸ ") + "Advanced: Thickness Factor"
            leftAlign: true
            fontSize: Style.font.bodySmall
            foreground: Qt.darker(Color.foreground, 1.2)
            onClicked: root.advancedOpen = !root.advancedOpen
          }

          Column {
            width: parent.width
            visible: root.advancedOpen
            spacing: Style.spacing.xs

            Text {
              textFormat: Text.PlainText
              width: parent.width
              wrapMode: Text.WordWrap
              text: "Thickness Factor (TF) is the dough weight per " + (root.metric ? "square centimetre" : "square inch")
                + " of pan area — the same metric pizza-dough calculators (e.g. Lehmann's) use. Overriding it here replaces the Thin/Medium/Thick preset."
              color: Qt.darker(Color.foreground, 1.4)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }

            LabeledSlider {
              width: parent.width
              label: "Thickness Factor"
              // Metric: g/cm² (×4.39), on a step that keeps a similar feel.
              unit: root.metric ? " g/cm²" : " oz/in²"
              decimals: root.metric ? 2 : 3
              value: Calculator.thicknessToDisplay(root.thicknessFactorOz, root.metric)
              minimum: Calculator.thicknessToDisplay(0.05, root.metric)
              maximum: Calculator.thicknessToDisplay(0.30, root.metric)
              step: root.metric ? 0.02 : 0.005
              scrollFlickable: scrollArea.contentItem
              onMoved: function(v) { root.setThicknessFactor(Calculator.thicknessFromDisplay(v, root.metric)) }
            }
          }

          NumberField {
            label: "Ball weight (g) — edit to override"
            value: root.ballWeight
            from: 50
            to: 2000
            stepSize: 5
            onModified: function(v) { root.ballWeight = v }
          }

          PanelSeparator {}
          PanelSectionHeader { text: "Baker's percentages" }

          LabeledSlider {
            width: parent.width
            label: "Water"
            value: root.hydrationPct
            minimum: 50; maximum: 90; step: 1; decimals: 0
            scrollFlickable: scrollArea.contentItem
            onMoved: function(v) { root.hydrationPct = v }
          }
          LabeledSlider {
            width: parent.width
            label: "Salt"
            value: root.saltPct
            minimum: 0; maximum: 4; step: 0.1
            scrollFlickable: scrollArea.contentItem
            onMoved: function(v) { root.saltPct = v }
          }
          LabeledSlider {
            width: parent.width
            label: "Oil"
            value: root.oilPct
            minimum: 0; maximum: 10; step: 0.5
            scrollFlickable: scrollArea.contentItem
            onMoved: function(v) { root.oilPct = v }
          }
          LabeledSlider {
            width: parent.width
            label: "Sugar"
            value: root.sugarPct
            minimum: 0; maximum: 5; step: 0.5
            scrollFlickable: scrollArea.contentItem
            onMoved: function(v) { root.sugarPct = v }
          }

          LabeledSlider {
            width: parent.width
            label: "Diastatic malt"
            value: root.maltPct
            minimum: 0; maximum: 2; step: 0.25; decimals: 2
            scrollFlickable: scrollArea.contentItem
            onMoved: function(v) { root.maltPct = v }
          }

          PanelSeparator {}
          PanelSectionHeader { text: "Fermentation" }

          ButtonGroup {
            // Values stay in °F; only the labels follow the units.
            options: [
              { value: "70", label: "Room temp (" + Calculator.formatTemp(70, root.metric) + ")" },
              { value: "38", label: "Fridge (" + Calculator.formatTemp(38, root.metric) + ")" }
            ]
            value: String(Math.round(root.fermentTempF))
            onChanged: function(v) { root.selectFermentPreset(parseInt(v, 10)) }
          }

          Repeater {
            model: [root.metric]
            NumberField {
              label: "Temperature (" + (root.metric ? "°C" : "°F") + ")"
              value: Math.round(Calculator.tempToDisplay(root.fermentTempF, root.metric))
              from: root.metric ? 1 : 33
              to: root.metric ? 32 : 90
              stepSize: 1
              onModified: function(v) { root.fermentTempF = Calculator.tempFromDisplay(v, root.metric) }
            }
          }

          NumberField {
            label: "Target fermentation time (hours)"
            value: root.fermentHours
            from: 1
            to: 240
            stepSize: 1
            onModified: function(v) { root.fermentHours = v }
          }

          Dropdown {
            label: "Yeast type"
            value: root.yeastType
            options: [
              { value: "idy", label: "Instant dry yeast" },
              { value: "ady", label: "Active dry yeast" },
              { value: "fresh", label: "Fresh / cake yeast" }
            ]
            onChanged: function(v) { root.yeastType = v }
          }

        }
      }

      Rectangle {
        id: card
        anchors.right: parent.right
        anchors.top: parent.top
        width: panel.columnWidth
        readonly property real pad: Style.space(14)
        implicitHeight: cardColumn.implicitHeight + cardButtons.height + Style.spacing.md + 2 * card.pad
        // Full height so it reads as one card, with Print/Copy at its foot.
        anchors.bottom: parent.bottom
        radius: Style.space(12)
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
        border.width: 1
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)
        clip: true

        Column {
          id: cardColumn
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: card.pad
          spacing: Style.spacing.sm

          PizzaPreview {
            width: parent.width
            framed: false
            stacked: true
            shape: root.shape
            diameterIn: root.sizeIn
            panWidthIn: root.panWidthIn
            panLengthIn: root.panLengthIn
            thicknessFactorOz: root.thicknessFactorOz
            thicknessLabel: Calculator.thicknessLabelFor(root.thickness)
            sizeLabel: Calculator.sizeDescriptionFor({
              shape: root.shape, sizeIn: root.sizeIn, panWidthIn: root.panWidthIn,
              panLengthIn: root.panLengthIn, metric: root.metric
            })
            ballCount: root.ballCount
            ballWeight: root.ballWeight
            totalDoughG: root.recipe.totalDoughG
          }

          PanelSeparator {}

          PanelSectionHeader { text: "Ingredients" }

          RecipeRow { label: "Flour"; amount: Calculator.formatGrams(root.recipe.flourG) }
          RecipeRow { label: "Water"; amount: Calculator.formatGrams(root.recipe.waterG) }
          RecipeRow { label: "Salt"; amount: Calculator.formatGrams(root.recipe.saltG) }
          RecipeRow { visible: root.oilPct > 0; label: "Oil"; amount: Calculator.formatGrams(root.recipe.oilG) }
          RecipeRow { visible: root.sugarPct > 0; label: "Sugar"; amount: Calculator.formatGrams(root.recipe.sugarG) }
          RecipeRow { visible: root.maltPct > 0; label: "Diastatic malt"; amount: Calculator.formatGrams(root.recipe.maltG) }
          RecipeRow {
            label: "Yeast (" + Calculator.yeastTypeLabel(root.yeastType) + ", " + root.recipe.yeastPct.toFixed(2) + "%)"
            amount: Calculator.formatGrams(root.recipe.yeastG)
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: "Ferment " + root.fermentHours + " h at " + Calculator.formatTemp(root.fermentTempF, root.metric)
              + (root.fermentTempF <= 45 ? " (fridge)" : "")
            color: Qt.darker(Color.foreground, 1.3)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }

          Text {
            width: parent.width
            visible: root.fermentNote !== ""
            textFormat: Text.PlainText
            text: root.fermentNote
            wrapMode: Text.WordWrap
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

        }

        Row {
          id: cardButtons
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.margins: card.pad
          spacing: Style.spacing.sm

          Button {
            width: (parent.width - Style.spacing.sm) / 2
            bordered: true
            iconText: "🖨️"
            text: "Print"
            tooltipText: "Open the recipe to print, or Save as PDF"
            onClicked: root.printRecipe()
          }

          Button {
            width: (parent.width - Style.spacing.sm) / 2
            bordered: true
            iconText: root.copied ? "✓" : "📋"
            text: root.copied ? "Copied!" : "Copy"
            tooltipText: "Copy recipe as text, to paste anywhere"
            onClicked: root.copyRecipe()
          }
        }
      }
    }
  }
}
