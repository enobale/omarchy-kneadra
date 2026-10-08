import QtQuick
import qs.Commons

// Header illustration: the pizza the current settings make, drawn to scale.
// The pie grows with the diameter (pepperoni stay a fixed real-world size,
// so a bigger pie simply holds more of them), morphs into a rectangular
// pan for pan mode, and its crust rim fattens with the Thickness Factor.
// Beside it, one dough ball per ball in the batch, sized by ball weight.
Item {
  id: root

  property string shape: "round" // round | pan
  property real diameterIn: 12
  property real panWidthIn: 12
  property real panLengthIn: 16
  property real thicknessFactorOz: 0.105
  property string thicknessLabel: "Medium"
  property string sizeLabel: "12\" round" // in the user's units
  property int ballCount: 4
  property int ballWeight: 335
  property real totalDoughG: 0
  // Draw its own rounded backdrop; off when it already sits inside a card.
  property bool framed: true
  // Pizza on top with the ball summary centered under it (for a tall,
  // narrow spot like the recipe card) instead of side by side.
  property bool stacked: false
  // Largest the stacked pizza may draw; the card shrinks it to make room.
  property real maxPizzaSize: Style.space(230)

  readonly property real pizzaSize: root.stacked
    ? Math.min(root.width, root.maxPizzaSize)
    : Style.space(176)

  implicitHeight: root.stacked
    ? root.pizzaSize + Style.spacing.sm + info.implicitHeight
    : root.pizzaSize

  // Crust rim width in inches: ~0.5" thin, ~0.65" medium, ~1.1" thick.
  function rimInchesFor(tf) {
    return Math.max(0.3, Math.min(1.6, 0.5 + (tf - 0.085) * 8))
  }

  // Values the canvas draws, animated so a setting change reads as the
  // pizza stretching/puffing rather than a jump cut. Pans are drawn
  // landscape: length across, width down.
  property real shownW: root.shape === "pan" ? root.panLengthIn : root.diameterIn
  property real shownH: root.shape === "pan" ? root.panWidthIn : root.diameterIn
  property real shownRound: root.shape === "pan" ? 0 : 1 // 1 = circle, 0 = rectangle
  property real shownRim: root.rimInchesFor(root.thicknessFactorOz)

  Behavior on shownW { NumberAnimation { duration: 380; easing.type: Easing.OutBack } }
  Behavior on shownH { NumberAnimation { duration: 380; easing.type: Easing.OutBack } }
  Behavior on shownRound { NumberAnimation { duration: 320; easing.type: Easing.InOutCubic } }
  Behavior on shownRim { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }

  onShownWChanged: pizza.requestPaint()
  onShownHChanged: pizza.requestPaint()
  onShownRoundChanged: pizza.requestPaint()
  onShownRimChanged: pizza.requestPaint()

  Rectangle {
    visible: root.framed
    anchors.fill: parent
    radius: Style.space(10)
    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
    border.width: 1
    border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
  }

  Canvas {
    id: pizza
    x: root.stacked ? (parent.width - width) / 2 : 0
    y: root.stacked ? 0 : (parent.height - height) / 2
    width: root.pizzaSize
    height: root.pizzaSize
    antialiasing: true

    // Quasi-random point i in [-1, 1]² (R2 low-discrepancy sequence): any
    // prefix of it is evenly spread, so adding toppings as the pie grows
    // never clumps and existing ones never move.
    function r2(i) {
      var x = (0.5 + 0.7548776662 * (i + 1)) % 1
      var y = (0.5 + 0.5698402910 * (i + 1)) % 1
      return { x: x * 2 - 1, y: y * 2 - 1 }
    }

    // Map a unit-square point onto the current shape: identity for the
    // rectangle, squashed radially into the disk for the circle, blended
    // in between while morphing.
    function place(p, k) {
      var len = Math.sqrt(p.x * p.x + p.y * p.y)
      if (len === 0) return p
      var s = Math.max(Math.abs(p.x), Math.abs(p.y)) / len
      var f = 1 + (s - 1) * k
      return { x: p.x * f, y: p.y * f }
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()

      var k = root.shownRound
      var pad = Style.space(12)
      // Everything up to ~16" shares one scale so size differences show;
      // bigger pies shrink the scale to still fit.
      var ppi = (Math.min(width, height) - 2 * pad) / Math.max(root.shownW, root.shownH, 16)
      var w = root.shownW * ppi
      var h = root.shownH * ppi
      var cx = width / 2
      var cy = height / 2
      var rim = root.shownRim * ppi

      function shapePath(inset) {
        var ww = Math.max(1, w - 2 * inset)
        var hh = Math.max(1, h - 2 * inset)
        var rRect = Math.max(2, 0.6 * ppi - inset)
        var rRound = Math.min(ww, hh) / 2
        var r = Math.min(Math.min(ww, hh) / 2, rRect + (rRound - rRect) * k)
        ctx.beginPath()
        ctx.roundedRect(cx - ww / 2, cy - hh / 2, ww, hh, r, r)
      }

      // Dark steel pan, fading in as the shape turns rectangular.
      if (k < 1) {
        shapePath(-0.35 * ppi)
        ctx.fillStyle = Qt.rgba(0.20, 0.21, 0.23, 1 - k)
        ctx.fill()
      }

      // Soft shadow; a puffier crust sits higher off the counter.
      ctx.save()
      ctx.translate(0, 1.5 + root.shownRim * 3)
      shapePath(0)
      ctx.fillStyle = "rgba(0, 0, 0, 0.28)"
      ctx.fill()
      ctx.restore()

      // Crust.
      var crust = ctx.createRadialGradient(cx, cy, 0, cx, cy, Math.max(w, h) / 2)
      crust.addColorStop(0, "#f2c77e")
      crust.addColorStop(0.82, "#e2a857")
      crust.addColorStop(1, "#b47637")
      shapePath(0)
      ctx.fillStyle = crust
      ctx.fill()

      // Leopard char spots around the rim.
      var a = w / 2 - rim / 2
      var b = h / 2 - rim / 2
      var spots = Math.round((w + h) / (ppi * 1.6))
      for (var s = 0; s < spots; s++) {
        var ang = s * 2.39996 // golden angle
        // Blend the point on the ellipse with the one on the rectangle.
        var norm = Math.max(Math.abs(Math.cos(ang)), Math.abs(Math.sin(ang)))
        var ex = Math.cos(ang) * (k + (1 - k) / norm)
        var ey = Math.sin(ang) * (k + (1 - k) / norm)
        var jitter = ((s * 0.618) % 1 - 0.5) * rim * 0.5
        ctx.beginPath()
        ctx.arc(cx + ex * (a + jitter), cy + ey * (b + jitter),
                (0.1 + 0.14 * ((s * 0.377) % 1)) * ppi, 0, Math.PI * 2)
        ctx.fillStyle = "rgba(78, 38, 14, 0.55)"
        ctx.fill()
      }

      // Sauce, then cheese leaving a thin ring of sauce showing.
      shapePath(rim)
      ctx.fillStyle = "#b8391f"
      ctx.fill()
      shapePath(rim + 0.28 * ppi)
      ctx.fillStyle = "#f1cc6e"
      ctx.fill()

      var innerA = Math.max(0, w / 2 - rim - 0.75 * ppi)
      var innerB = Math.max(0, h / 2 - rim - 0.75 * ppi)

      // Melted-cheese highlights.
      for (var m = 0; m < 14; m++) {
        var mp = place(r2(m + 50), k)
        ctx.beginPath()
        ctx.arc(cx + mp.x * innerA, cy + mp.y * innerB, (0.35 + 0.3 * ((m * 0.43) % 1)) * ppi, 0, Math.PI * 2)
        ctx.fillStyle = "rgba(250, 230, 170, 0.55)"
        ctx.fill()
      }

      // Pepperoni: fixed ~1.3" slices, count follows the topped area.
      var toppedIn2 = (innerA * innerB * 4 / (ppi * ppi)) * (1 - 0.2146 * k)
      var count = Math.max(3, Math.min(48, Math.round(toppedIn2 / 5.5)))
      var pr = 0.65 * ppi
      for (var i = 0; i < count; i++) {
        var p = place(r2(i), k)
        var px = cx + p.x * innerA
        var py = cy + p.y * innerB
        ctx.beginPath()
        ctx.arc(px, py + pr * 0.12, pr, 0, Math.PI * 2)
        ctx.fillStyle = "rgba(90, 20, 10, 0.35)"
        ctx.fill()
        ctx.beginPath()
        ctx.arc(px, py, pr, 0, Math.PI * 2)
        ctx.fillStyle = "#a52c1b"
        ctx.fill()
        ctx.lineWidth = Math.max(1, pr * 0.14)
        ctx.strokeStyle = "#7c1e12"
        ctx.stroke()
        for (var f = 0; f < 3; f++) {
          var fa = i * 1.7 + f * 2.1
          ctx.beginPath()
          ctx.arc(px + Math.cos(fa) * pr * 0.45, py + Math.sin(fa) * pr * 0.45, pr * 0.13, 0, Math.PI * 2)
          ctx.fillStyle = "rgba(240, 150, 120, 0.55)"
          ctx.fill()
        }
      }

      // A few basil leaves.
      for (var l = 0; l < 3; l++) {
        var lp = place(r2(l + 90), k)
        ctx.save()
        ctx.translate(cx + lp.x * innerA * 0.9, cy + lp.y * innerB * 0.9)
        ctx.rotate(l * 2.2 + 0.4)
        ctx.scale(1, 0.5)
        ctx.beginPath()
        ctx.arc(0, 0, 0.55 * ppi, 0, Math.PI * 2)
        ctx.fillStyle = "#3f7d2c"
        ctx.fill()
        ctx.restore()
      }
    }
  }

  Column {
    id: info
    x: root.stacked ? 0 : pizza.width
    y: root.stacked ? pizza.height + Style.spacing.sm : (parent.height - implicitHeight) / 2
    width: root.stacked ? parent.width : parent.width - pizza.width - Style.space(12)
    spacing: Style.spacing.sm

    Text {
      width: parent.width
      horizontalAlignment: root.stacked ? Text.AlignHCenter : Text.AlignLeft
      textFormat: Text.PlainText
      text: root.ballCount + " × " + root.ballWeight + " g"
      color: Color.accent
      font.family: Style.font.family
      font.pixelSize: Style.font.heading
      font.bold: true
    }

    // One dough ball per ball, sized (by volume) to the ball weight.
    Flow {
      id: balls
      readonly property real ballD: Math.max(Style.space(9), Math.min(Style.space(26),
        Style.space(16) * Math.cbrt(root.ballWeight / 300)))
      readonly property int shown: Math.min(root.ballCount, 12)
      // Shrink-wrap when stacked so the row can sit centered.
      width: root.stacked
        ? Math.min(parent.width, balls.shown * (balls.ballD + balls.spacing) + (root.ballCount > 12 ? Style.space(28) : 0))
        : parent.width
      x: root.stacked ? (parent.width - width) / 2 : 0
      spacing: Style.space(4)

      Repeater {
        model: balls.shown

        Rectangle {
          width: balls.ballD
          height: balls.ballD
          radius: width / 2
          border.width: 1
          border.color: "#c9a26a"
          gradient: Gradient {
            GradientStop { position: 0.0; color: "#fbf1dc" }
            GradientStop { position: 1.0; color: "#e5cfa4" }
          }
          Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
          Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

          scale: 0
          Component.onCompleted: scale = 1
          Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
        }
      }

      Text {
        visible: root.ballCount > 12
        textFormat: Text.PlainText
        text: "+" + (root.ballCount - 12)
        color: Qt.darker(Color.foreground, 1.2)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
    }

    Text {
      width: parent.width
      horizontalAlignment: root.stacked ? Text.AlignHCenter : Text.AlignLeft
      wrapMode: Text.WordWrap
      textFormat: Text.PlainText
      text: root.sizeLabel + " · " + root.thicknessLabel
        + (root.stacked ? " · " : "\n") + Math.round(root.totalDoughG) + " g dough"
      color: Qt.darker(Color.foreground, 1.3)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
  }
}
