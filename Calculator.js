// Pure dough-math helpers for Kneadra. No QML/Quickshell dependencies here
// so the recipe logic can be sanity-checked (or unit tested) on its own.

// Thickness Factor (TF): grams (or, traditionally, ounces) of dough per
// square inch of pan/skin area — the standard metric pizza-dough
// calculators (e.g. Tom Lehmann's) use to size dough for a given pan.
// These presets are representative oz/in² midpoints for each style; the
// UI exposes the raw value as an "advanced" override for anyone who
// already knows their preferred TF.
function thicknessFactorOzFor(preset) {
  if (preset === "thin") return 0.085
  if (preset === "thick") return 0.16
  return 0.105 // medium
}

// ---- units ----
// Everything is computed in inches and °F (the fermentation chart's native
// unit). "metric" only changes what the panel shows and accepts: lengths in
// cm, temperatures in °C, Thickness Factor in g/cm².
var CM_PER_IN = 2.54
var G_PER_CM2_PER_OZ_PER_IN2 = 28.3495 / (CM_PER_IN * CM_PER_IN)

function lengthToDisplay(inches, metric) { return metric ? inches * CM_PER_IN : inches }
function lengthFromDisplay(value, metric) { return metric ? value / CM_PER_IN : value }
function tempToDisplay(tempF, metric) { return metric ? (tempF - 32) * 5 / 9 : tempF }
function tempFromDisplay(value, metric) { return metric ? value * 9 / 5 + 32 : value }
function thicknessToDisplay(oz, metric) { return metric ? oz * G_PER_CM2_PER_OZ_PER_IN2 : oz }
function thicknessFromDisplay(value, metric) { return metric ? value / G_PER_CM2_PER_OZ_PER_IN2 : value }

// Whole display units: 12" -> 12", or 30 cm (30.48 rounded) in metric.
function formatLength(inches, metric) {
  return Math.round(lengthToDisplay(inches, metric)) + (metric ? " cm" : "\"")
}

function formatTemp(tempF, metric) {
  return Math.round(tempToDisplay(tempF, metric)) + (metric ? "°C" : "°F")
}

// Round-pizza size shortcuts, in display units: common inch sizes, and the
// usual metric pizzeria sizes (≈ the same pies).
function sizePresets(metric) {
  return metric ? [25, 30, 35, 40, 45] : [10, 12, 14, 16, 18]
}

function ozPerIn2ToGramsPerIn2(oz) {
  return oz * 28.3495
}

function roundAreaIn2(diameterIn) {
  var radius = diameterIn / 2
  return Math.PI * radius * radius
}

function panAreaIn2(widthIn, lengthIn) {
  return Math.max(0, widthIn * lengthIn)
}

// Suggests a dough weight (g) from a pan/skin area (in²) and a Thickness
// Factor (oz/in²), rounded to the nearest 5g.
function suggestedWeightFromArea(areaIn2, thicknessFactorOz) {
  var gramsPerIn2 = ozPerIn2ToGramsPerIn2(thicknessFactorOz)
  var grams = areaIn2 * gramsPerIn2
  return Math.max(50, Math.round(grams / 5) * 5)
}

// Time-to-full-proof data for instant dry yeast (IDY), taken from the
// "Fermentation Table – Extended" chart (Documents/Pizza/Fermentation-
// Table---Extended.jpg): hours to full proof by dough temperature (rows,
// whole °F) and yeast dose (columns). The chart's IDY row is fresh/cake
// yeast (CY) × 0.32, which is what FERMENT_CHART_IDY holds. Cells the chart
// leaves blank (times too long or too short to list) are simply absent.
//
// Each FERMENT_CHART_HOURS row is [index of its first listed FERMENT_CHART_IDY
// column, hours...], one row per °F from FERMENT_CHART_MIN_TEMP_F upward.
var FERMENT_CHART_MIN_TEMP_F = 35
var FERMENT_CHART_MAX_TEMP_F = 80
var FERMENT_CHART_IDY = [0.0032, 0.0064, 0.0096, 0.016, 0.024, 0.032, 0.04, 0.048, 0.056, 0.064, 0.096, 0.128, 0.16, 0.192, 0.224, 0.256, 0.32, 0.384, 0.448, 0.512, 0.576, 0.64, 0.704, 0.768, 0.832, 0.896, 0.96]

var FERMENT_CHART_HOURS = [
  [10, 167, 136, 115, 101, 90, 82, 70, 61, 54, 49, 45, 42, 39, 37, 35, 33, 31], // 35°F
  [10, 149, 121, 103, 90, 80, 73, 62, 54, 49, 44, 40, 37, 35, 33, 31, 29, 28], // 36°F
  [10, 133, 108, 92, 80, 72, 65, 55, 49, 43, 39, 36, 33, 31, 29, 28, 26, 25], // 37°F
  [9, 161, 120, 97, 82, 72, 65, 59, 50, 44, 39, 35, 32, 30, 28, 26, 25, 24, 22], // 38°F
  [8, 159, 145, 108, 87, 74, 65, 58, 53, 45, 39, 35, 32, 29, 27, 25, 24, 22, 21, 20], // 39°F
  [7, 161, 144, 130, 97, 79, 67, 59, 52, 48, 40, 35, 32, 29, 26, 24, 23, 21, 20, 19, 18], // 40°F
  [6, 166, 145, 130, 118, 88, 71, 61, 53, 47, 43, 37, 32, 29, 26, 24, 22, 21, 19, 18, 17, 16], // 41°F
  [6, 151, 132, 118, 107, 80, 65, 55, 48, 43, 39, 33, 29, 26, 24, 22, 20, 19, 18, 17, 16, 15], // 42°F
  [5, 161, 137, 120, 107, 97, 72, 59, 50, 44, 39, 35, 30, 26, 24, 21, 20, 18, 17, 16, 15, 14, 14], // 43°F
  [5, 147, 125, 109, 98, 88, 66, 53, 45, 40, 36, 32, 27, 24, 21, 19, 18, 17, 15, 14, 14, 13, 12, 11], // 44°F
  [4, 165, 134, 114, 100, 89, 81, 60, 49, 41, 36, 32, 29, 25, 22, 20, 18, 16, 15, 14, 13, 12, 12, 11], // 45°F
  [4, 151, 122, 104, 91, 81, 74, 55, 45, 38, 33, 30, 27, 23, 20, 18, 16, 15, 14, 13, 12, 11, 11, 10], // 46°F
  [4, 138, 112, 95, 83, 74, 67, 50, 41, 35, 30, 27, 25, 21, 18, 16, 15, 14, 13, 12, 11, 10, 10, 9], // 47°F
  [4, 126, 102, 87, 76, 68, 62, 46, 37, 32, 28, 25, 23, 19, 17, 15, 14, 12, 12, 11, 10, 10, 9], // 48°F
  [3, 156, 116, 94, 80, 70, 63, 57, 42, 34, 29, 26, 23, 21, 18, 15, 14, 12, 11, 11, 10, 9, 9, 8], // 49°F
  [3, 143, 107, 86, 74, 64, 58, 52, 39, 32, 27, 23, 21, 19, 16, 14, 13, 11, 11, 10, 9, 9, 8, 8, 7], // 50°F
  [3, 132, 98, 80, 68, 59, 53, 48, 36, 29, 25, 22, 19, 18, 15, 13, 12, 11, 10, 9, 8, 8, 7, 7], // 51°F
  [3, 122, 90, 73, 62, 55, 49, 44, 33, 27, 23, 20, 18, 16, 14, 12, 11, 10, 9, 8, 8, 7, 7, 6], // 52°F
  [2, 163, 112, 84, 68, 58, 50, 45, 41, 30, 25, 21, 18, 16, 15, 13, 11, 10, 9, 8, 8, 7, 7, 6, 6], // 53°F
  [2, 150, 104, 77, 63, 53, 47, 42, 38, 28, 23, 19, 17, 15, 14, 12, 10, 9, 8, 8, 7, 7, 6, 6, 5], // 54°F
  [2, 139, 96, 71, 58, 49, 43, 39, 35, 26, 21, 18, 16, 14, 13, 11, 9, 8, 8, 7, 7, 6, 6, 5, 5], // 55°F
  [2, 129, 89, 66, 54, 46, 40, 36, 32, 24, 20, 17, 15, 13, 12, 10, 9, 8, 7, 7, 6, 6, 5, 5, 5], // 56°F
  [1, 161, 120, 82, 61, 50, 42, 37, 33, 30, 22, 18, 15, 14, 12, 11, 9, 8, 7, 7, 6, 6, 5, 5, 4, 4], // 57°F
  [1, 149, 111, 77, 57, 46, 39, 34, 31, 28, 21, 17, 14, 13, 11, 10, 9, 8, 7, 6, 6, 5, 5, 4, 4, 4], // 58°F
  [1, 139, 103, 71, 53, 43, 37, 32, 29, 26, 19, 16, 13, 12, 10, 9, 8, 7, 6, 6, 5, 5, 4, 4, 4, 4], // 59°F
  [1, 129, 96, 66, 49, 40, 34, 30, 27, 24, 18, 15, 12, 11, 10, 9, 7, 7, 6, 5, 5, 5, 4, 4, 4, 4], // 60°F
  [1, 120, 90, 62, 46, 37, 32, 28, 25, 22, 17, 14, 12, 10, 9, 8, 7, 6, 5, 5, 5, 4, 4, 4, 3, 3], // 61°F
  [1, 112, 83, 58, 43, 35, 30, 26, 23, 21, 16, 13, 11, 9, 8, 8, 6, 6, 5, 5, 4, 4, 4, 3, 3, 3], // 62°F
  [1, 105, 78, 54, 40, 32, 28, 24, 22, 20, 15, 12, 10, 9, 8, 7, 6, 5, 5, 4, 4, 4, 3, 3, 3, 3], // 63°F
  [0, 162, 98, 73, 50, 37, 30, 26, 23, 20, 18, 14, 11, 9, 8, 7, 7, 6, 5, 4, 4, 4, 3, 3, 3, 3, 3], // 64°F
  [0, 152, 92, 68, 47, 35, 28, 24, 21, 19, 17, 13, 10, 9, 8, 7, 6, 5, 5, 4, 3, 3, 3, 3, 3, 2, 2], // 65°F
  [0, 142, 86, 64, 44, 33, 27, 23, 20, 18, 16, 12, 10, 8, 7, 6, 5, 4, 4, 3, 3, 3, 3, 2, 2, 2], // 66°F
  [0, 133, 80, 60, 41, 31, 25, 21, 19, 17, 15, 11, 9, 8, 7, 6, 5, 5, 4, 4, 3, 3, 3, 2, 2, 2], // 67°F
  [0, 120, 73, 54, 37, 28, 22, 19, 17, 15, 14, 10, 8, 7, 6, 5, 4, 4, 3, 3, 3, 3, 2, 2, 2, 2], // 68°F
  [0, 109, 66, 49, 34, 25, 20, 17, 15, 14, 12, 9, 7, 6, 6, 5, 4, 4, 3, 3, 3, 2, 2, 2, 2, 2], // 69°F
  [0, 99, 60, 45, 31, 23, 19, 16, 14, 12, 11, 8, 7, 6, 5, 4, 4, 3, 3, 3, 2, 2, 2, 2, 2, 2], // 70°F
  [0, 90, 55, 41, 28, 21, 17, 14, 13, 11, 10, 8, 6, 5, 5, 4, 3, 3, 2, 2, 2, 2, 2, 1, 1], // 71°F
  [0, 83, 50, 37, 26, 19, 15, 13, 12, 10, 9, 7, 6, 5, 4, 4, 3, 3, 3, 2, 2, 2, 2, 1, 1, 1], // 72°F
  [0, 76, 46, 34, 24, 18, 14, 12, 11, 9, 9, 6, 5, 4, 4, 3, 3, 3, 2, 2, 2, 2, 1, 1, 1, 1], // 73°F
  [0, 70, 42, 32, 22, 16, 13, 11, 10, 9, 8, 6, 5, 4, 3, 3, 2, 2, 2, 2, 2, 1, 1, 1, 1], // 74°F
  [0, 65, 39, 29, 20, 15, 12, 10, 9, 8, 7, 5, 4, 4, 3, 3, 3, 2, 2, 2, 2, 1, 1, 1, 1, 1], // 75°F
  [0, 60, 36, 27, 19, 14, 11, 10, 8, 7, 7, 5, 4, 3, 3, 3, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1], // 76°F
  [0, 56, 34, 25, 17, 13, 10, 9, 8, 7, 6, 5, 4, 3, 3, 3, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1], // 77°F
  [0, 52, 31, 23, 16, 12, 10, 8, 7, 6, 6, 4, 4, 3, 3, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1], // 78°F
  [0, 48, 29, 22, 15, 11, 9, 8, 7, 6, 5, 4, 3, 3, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1], // 79°F
  [0, 45, 27, 20, 14, 10, 8, 7, 6, 6, 5, 4, 3, 3, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1], // 80°F
]

// Past the ends of a chart row the dose is extrapolated along a power law,
// hours ∝ idyPct^-ALPHA, with ALPHA fit to the whole chart.
var FERMENT_EXTRAP_ALPHA = 0.78

// Dose limits for what the UI will ever show. The chart itself spans about
// 0.003%–0.96% IDY; these only stop extreme inputs (near-zero hours, very
// long times) from producing nonsense percentages.
var IDY_MIN_PCT = 0.001
var IDY_MAX_PCT = 2

// One chart row as parallel arrays, yeast ascending / hours descending. The
// chart rounds to whole hours, so short ferments repeat the same number
// across several columns; only the lowest-yeast cell of each run is kept so
// hours -> yeast stays single-valued.
function fermentChartRow(tempF) {
  var row = FERMENT_CHART_HOURS[tempF - FERMENT_CHART_MIN_TEMP_F]
  var idy = []
  var hrs = []
  for (var k = 1; k < row.length; k++) {
    if (hrs.length === 0 || row[k] < hrs[hrs.length - 1]) {
      idy.push(FERMENT_CHART_IDY[row[0] + k - 1])
      hrs.push(row[k])
    }
  }
  return { idy: idy, hrs: hrs }
}

// IDY percent for `hours` on one chart row: log-log interpolation between
// the two surrounding cells, or extrapolation (edge "long"/"short") when
// `hours` runs past the longest/shortest time the row lists.
function fermentRowLookup(row, hours) {
  var last = row.hrs.length - 1
  if (hours > row.hrs[0])
    return { pct: row.idy[0] * Math.pow(hours / row.hrs[0], -1 / FERMENT_EXTRAP_ALPHA), edge: "long" }
  if (hours < row.hrs[last])
    return { pct: row.idy[last] * Math.pow(hours / row.hrs[last], -1 / FERMENT_EXTRAP_ALPHA), edge: "short" }
  for (var k = 0; k < last; k++) {
    if (hours <= row.hrs[k] && hours >= row.hrs[k + 1]) {
      var frac = (Math.log(row.hrs[k]) - Math.log(hours)) / (Math.log(row.hrs[k]) - Math.log(row.hrs[k + 1]))
      return { pct: Math.exp(Math.log(row.idy[k]) + frac * (Math.log(row.idy[k + 1]) - Math.log(row.idy[k]))), edge: "" }
    }
  }
  return { pct: row.idy[last], edge: "" }
}

// The chart lookup for an (hours, tempF) pair. Temperatures outside the
// chart use its nearest row; the UI only ever offers whole °F.
function fermentLookup(hours, tempF) {
  if (!(hours > 0)) return { pct: Infinity, edge: "short" }
  var t = Math.round(Math.max(FERMENT_CHART_MIN_TEMP_F, Math.min(FERMENT_CHART_MAX_TEMP_F, tempF)))
  return fermentRowLookup(fermentChartRow(t), hours)
}

// IDY percent (of flour weight) needed to reach full proof in `hours` at
// `tempF`, clamped to IDY_MIN_PCT..IDY_MAX_PCT.
function idyPercentForHours(hours, tempF) {
  return Math.max(IDY_MIN_PCT, Math.min(IDY_MAX_PCT, fermentLookup(hours, tempF).pct))
}

// A short warning when `hours` at `tempF` isn't backed by the chart (or was
// clamped), so the shown dose isn't a straight chart reading; "" when it is.
function fermentRangeNote(hours, tempF, metric) {
  var r = fermentLookup(hours, tempF)
  var minT = formatTemp(FERMENT_CHART_MIN_TEMP_F, metric)
  var maxT = formatTemp(FERMENT_CHART_MAX_TEMP_F, metric)
  if (Math.round(tempF) < FERMENT_CHART_MIN_TEMP_F)
    return "Colder than the fermentation chart covers (" + minT + ") — dose shown is for " + minT + "."
  if (Math.round(tempF) > FERMENT_CHART_MAX_TEMP_F)
    return "Warmer than the fermentation chart covers (" + maxT + ") — dose shown is for " + maxT + ", so it will run high."
  if (r.pct > IDY_MAX_PCT)
    return "Too short for this temperature — dose capped at " + IDY_MAX_PCT + "%. Try a longer time or a warmer temperature."
  if (r.pct < IDY_MIN_PCT)
    return "Too long for this temperature — the dose is below " + IDY_MIN_PCT + "%. Try a shorter time or a cooler temperature."
  if (r.edge === "long")
    return "Longer than the fermentation chart covers at this temperature — the dose is extrapolated."
  if (r.edge === "short")
    return "Shorter than the fermentation chart covers at this temperature — the dose is extrapolated."
  return ""
}

// Conversion from instant dry yeast (IDY) equivalent to other yeast forms.
// Source page states "IDY = ADY × 0.75" (i.e. ADY = IDY / 0.75) and
// "CY (fresh) = IDY × 3" — both standard baking conversions. (Note: that
// page's own JS uses a CY factor of 1/3, which contradicts its own stated
// conversion and common baking references; we follow the documented/
// standard ratio here instead.)
function yeastMultiplier(type) {
  if (type === "ady") return 1 / 0.75
  if (type === "fresh") return 3.0
  return 1.0
}

function yeastTypeLabel(type) {
  if (type === "ady") return "ADY"
  if (type === "fresh") return "Fresh"
  return "IDY"
}

function thicknessLabelFor(preset) {
  if (preset === "thin") return "Thin"
  if (preset === "thick") return "Thick"
  if (preset === "custom") return "Custom"
  return "Medium"
}

// Solves baker's-percentage ingredients from a target total dough weight.
// input: { ballWeight, ballCount, hydrationPct, saltPct, oilPct, sugarPct,
//           maltPct, idyPct, yeastType }
// All *Pct values are percentages of flour weight (flour itself is 100%).
function computeRecipe(input) {
  var totalDoughG = Math.max(0, input.ballWeight * input.ballCount)
  var yeastPct = input.idyPct * yeastMultiplier(input.yeastType)
  var sumFraction = 1
    + input.hydrationPct / 100
    + input.saltPct / 100
    + input.oilPct / 100
    + input.sugarPct / 100
    + input.maltPct / 100
    + yeastPct / 100
  var flourG = sumFraction > 0 ? totalDoughG / sumFraction : 0
  return {
    totalDoughG: totalDoughG,
    flourG: flourG,
    waterG: flourG * input.hydrationPct / 100,
    saltG: flourG * input.saltPct / 100,
    oilG: flourG * input.oilPct / 100,
    sugarG: flourG * input.sugarPct / 100,
    maltG: flourG * input.maltPct / 100,
    yeastG: flourG * yeastPct / 100,
    yeastPct: yeastPct
  }
}

function formatGrams(value) {
  if (!isFinite(value)) return "0 g"
  // Two decimals below 1 g so a tiny (but real) yeast dose doesn't
  // round to a misleading "0.0 g".
  if (value < 1) return value.toFixed(2) + " g"
  if (value < 10) return value.toFixed(1) + " g"
  return Math.round(value) + " g"
}

function sizeDescriptionFor(input) {
  if (input.shape === "pan") {
    var w = Math.round(lengthToDisplay(input.panWidthIn, input.metric))
    var l = Math.round(lengthToDisplay(input.panLengthIn, input.metric))
    return w + "×" + l + (input.metric ? " cm" : "\"") + " pan"
  }
  return formatLength(input.sizeIn, input.metric) + " round"
}

// Builds the ingredient rows shared by the plain-text and HTML recipe
// renderers, so the two formats can't drift apart.
// input: same shape as computeRecipe()'s input, plus { recipe } (the
// already-computed result) and { shape, sizeIn, panWidthIn, panLengthIn,
// thicknessLabel, ballCount, ballWeight, fermentHours, fermentTempF, metric }.
function recipeIngredientRows(input) {
  var rows = [
    ["Flour", formatGrams(input.recipe.flourG)],
    ["Water", formatGrams(input.recipe.waterG) + " (" + input.hydrationPct + "% hydration)"],
    ["Salt", formatGrams(input.recipe.saltG) + " (" + input.saltPct + "%)"]
  ]
  if (input.oilPct > 0) rows.push(["Oil", formatGrams(input.recipe.oilG) + " (" + input.oilPct + "%)"])
  if (input.sugarPct > 0) rows.push(["Sugar", formatGrams(input.recipe.sugarG) + " (" + input.sugarPct + "%)"])
  if (input.maltPct > 0) rows.push(["Diastatic malt", formatGrams(input.recipe.maltG) + " (" + input.maltPct + "%)"])
  rows.push([
    "Yeast (" + yeastTypeLabel(input.yeastType) + ")",
    formatGrams(input.recipe.yeastG) + " (" + input.recipe.yeastPct.toFixed(2) + "%)"
  ])
  return rows
}

// Plain-text recipe summary, for copying to the clipboard and pasting
// anywhere (notes, chat, email).
function formatRecipeText(input) {
  var lines = [
    "Kneadra — Pizza Dough Recipe",
    "",
    input.ballCount + " × " + input.ballWeight + "g balls — "
      + sizeDescriptionFor(input) + ", " + input.thicknessLabel + " crust",
    "Total dough: " + formatGrams(input.recipe.totalDoughG),
    ""
  ]
  recipeIngredientRows(input).forEach(function(row) {
    lines.push(row[0] + ": " + row[1])
  })
  lines.push("")
  lines.push("Fermentation: " + input.fermentHours + "h at " + formatTemp(input.fermentTempF, input.metric))
  return lines.join("\n")
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
}

// Self-contained HTML page for the "Print" action: opened via xdg-open so
// the desktop's default handler (typically a browser) supplies a real
// print dialog — printer selection and "Save as PDF" — without Kneadra
// needing to talk to CUPS or any print stack itself.
function formatRecipeHtml(input) {
  var rowsHtml = recipeIngredientRows(input).map(function(row) {
    return "<tr><td>" + escapeHtml(row[0]) + "</td><td class=\"amt\">" + escapeHtml(row[1]) + "</td></tr>"
  }).join("")

  return "<!doctype html><html><head><meta charset=\"utf-8\"><title>Kneadra Recipe</title><style>"
    + "body{font-family:sans-serif;max-width:32em;margin:2em auto;padding:0 1em;color:#222;}"
    + "h1{font-size:1.4em;margin-bottom:0.1em;}"
    + ".sub{color:#666;margin:0.2em 0;}"
    + "table{width:100%;border-collapse:collapse;margin-top:1em;}"
    + "td{padding:0.35em 0;border-bottom:1px solid #ddd;}"
    + ".amt{text-align:right;font-weight:bold;}"
    + "</style></head><body>"
    + "<h1>🍕 Kneadra</h1>"
    + "<p class=\"sub\">" + input.ballCount + " × " + input.ballWeight + "g balls — "
      + escapeHtml(sizeDescriptionFor(input)) + ", " + escapeHtml(input.thicknessLabel) + " crust</p>"
    + "<p class=\"sub\">Total dough: " + escapeHtml(formatGrams(input.recipe.totalDoughG)) + "</p>"
    + "<table>" + rowsHtml + "</table>"
    + "<p class=\"sub\">Fermentation: " + input.fermentHours + "h at " + escapeHtml(formatTemp(input.fermentTempF, input.metric)) + "</p>"
    + "</body></html>"
}

// ---- saved settings ----
// Validates a parsed settings file against `defaults`: each field keeps the
// default unless the saved value has the same type (and, for numbers, lies
// in `ranges[field]`). A hand-edited or older file can't break the panel.
function sanitizeSettings(saved, defaults, ranges) {
  var out = {}
  for (var key in defaults) {
    var d = defaults[key]
    var v = saved ? saved[key] : undefined
    if (typeof v !== typeof d || (typeof v === "number" && !isFinite(v))) {
      out[key] = d
    } else if (typeof v === "number" && ranges[key]) {
      out[key] = Math.max(ranges[key][0], Math.min(ranges[key][1], v))
    } else if (typeof v === "string" && ranges[key] && ranges[key].indexOf(v) < 0) {
      out[key] = d
    } else {
      out[key] = v
    }
  }
  return out
}
