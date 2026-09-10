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

  // ---- dough balls ----
  property int ballCount: 4
  property string shape: "round" // round | pan
  property int sizeIn: 12 // round diameter, inches
  property int panWidthIn: 12 // pan/rectangular, inches
  property int panLengthIn: 16
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

  // ---- fermentation ----
  property int fermentTempF: 70
  property real fermentHours: 4
  property string yeastType: "idy" // idy | ady | fresh

  readonly property real idyPct: Calculator.idyPercentForHours(root.fermentHours, root.fermentTempF)
  readonly property var recipe: Calculator.computeRecipe({
    ballWeight: root.ballWeight,
    ballCount: root.ballCount,
    hydrationPct: root.hydrationPct,
    saltPct: root.saltPct,
    oilPct: root.oilPct,
    sugarPct: root.sugarPct,
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

  function selectSize(value) {
    root.sizeIn = parseInt(value, 10)
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
      yeastType: root.yeastType,
      fermentHours: root.fermentHours,
      fermentTempF: root.fermentTempF,
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
        onMoved: function(v) { labeledSlider.moved(v) }
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

  // Ingredient name + computed weight, right-aligned.
  component RecipeRow: Row {
    id: recipeRow
    property string label: ""
    property string amount: ""
    width: parent.width

    Text {
      textFormat: Text.PlainText
      text: recipeRow.label
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      width: parent.width - amountLabel.implicitWidth
    }

    Text {
      id: amountLabel
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
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Column {
          id: panelColumn
          // Leave room for the overlay scrollbar: it floats on top of the
          // Flickable rather than reserving its own width, so content that
          // reaches the right edge (e.g. the bold recipe amounts) gets
          // covered by it while scrolling without this margin.
          width: scrollArea.availableWidth - Style.space(10)
          spacing: Style.spacing.panelGap

          Row {
            width: parent.width
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
            options: [
              { value: "10", label: "10\"" },
              { value: "12", label: "12\"" },
              { value: "14", label: "14\"" },
              { value: "16", label: "16\"" },
              { value: "18", label: "18\"" }
            ]
            value: String(root.sizeIn)
            onChanged: function(v) { root.selectSize(v) }
          }

          NumberField {
            visible: root.shape === "round"
            label: "Diameter (in) — edit to override"
            value: root.sizeIn
            from: 6
            to: 30
            stepSize: 1
            onModified: function(v) { root.selectSize(String(v)) }
          }

          NumberField {
            visible: root.shape === "pan"
            label: "Pan width (in)"
            value: root.panWidthIn
            from: 4
            to: 30
            stepSize: 1
            onModified: function(v) { root.setPanWidth(v) }
          }

          NumberField {
            visible: root.shape === "pan"
            label: "Pan length (in)"
            value: root.panLengthIn
            from: 4
            to: 30
            stepSize: 1
            onModified: function(v) { root.setPanLength(v) }
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
              text: "Thickness Factor (TF) is the dough weight per square inch of pan area — the same metric pizza-dough calculators (e.g. Lehmann's) use. Overriding it here replaces the Thin/Medium/Thick preset."
              color: Qt.darker(Color.foreground, 1.4)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }

            LabeledSlider {
              width: parent.width
              label: "Thickness Factor"
              unit: " oz/in²"
              decimals: 3
              value: root.thicknessFactorOz
              minimum: 0.05; maximum: 0.30; step: 0.005
              scrollFlickable: scrollArea.contentItem
              onMoved: function(v) { root.setThicknessFactor(v) }
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
            label: "Hydration"
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

          PanelSeparator {}
          PanelSectionHeader { text: "Fermentation" }

          ButtonGroup {
            options: [
              { value: "70", label: "Room temp (70°F)" },
              { value: "38", label: "Fridge (38°F)" }
            ]
            value: String(root.fermentTempF)
            onChanged: function(v) { root.selectFermentPreset(parseInt(v, 10)) }
          }

          NumberField {
            label: "Temperature (°F)"
            value: root.fermentTempF
            from: 33
            to: 90
            stepSize: 1
            onModified: function(v) { root.fermentTempF = v }
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

          PanelSeparator {}
          PanelSectionHeader {
            text: "Recipe — " + root.ballCount + " × " + root.ballWeight
              + "g = " + Math.round(root.recipe.totalDoughG) + "g total"
          }

          RecipeRow { label: "Flour"; amount: Calculator.formatGrams(root.recipe.flourG) }
          RecipeRow { label: "Water"; amount: Calculator.formatGrams(root.recipe.waterG) }
          RecipeRow { label: "Salt"; amount: Calculator.formatGrams(root.recipe.saltG) }
          RecipeRow { visible: root.oilPct > 0; label: "Oil"; amount: Calculator.formatGrams(root.recipe.oilG) }
          RecipeRow { visible: root.sugarPct > 0; label: "Sugar"; amount: Calculator.formatGrams(root.recipe.sugarG) }
          RecipeRow {
            label: "Yeast (" + Calculator.yeastTypeLabel(root.yeastType) + ", " + root.recipe.yeastPct.toFixed(2) + "%)"
            amount: Calculator.formatGrams(root.recipe.yeastG)
          }

          Row {
            width: parent.width
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
}
