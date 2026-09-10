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

// Time-to-full-proof model for instant dry yeast (IDY), fit from the
// reference chart/formula at https://derwille1.github.io/cf-calculator/:
//   hours = A * idyPct^(-ALPHA) * exp(-BETA * (tempF - REF_TEMP))
// i.e. proof time falls off as a power of the yeast dose and decays
// exponentially as temperature rises above REF_TEMP (35°F). Covers both
// cold (fridge, ~35-45°F) and room-temp (~65-75°F) ferments with one
// continuous curve instead of two separate tables.
var FERMENT_A = 30.91
var FERMENT_ALPHA = 0.72
var FERMENT_BETA = 0.110
var FERMENT_REF_TEMP_F = 35

// IDY percent (of flour weight) needed to reach full proof in `hours` at
// `tempF`. Clamped to a realistic dough range so extreme inputs (near-zero
// hours, very cold temps) don't blow up into nonsense percentages.
function idyPercentForHours(hours, tempF) {
  var expF = Math.exp(-FERMENT_BETA * (tempF - FERMENT_REF_TEMP_F))
  var base = hours / (FERMENT_A * expF)
  if (base <= 0) return 2
  var pct = Math.pow(base, -1 / FERMENT_ALPHA)
  return Math.max(0.01, Math.min(2, pct))
}

// Inverse of the above: estimated hours to full proof for a given IDY%
// and temperature. Not currently surfaced in the UI, kept for reference/
// potential display of "≈ Xh at this dose".
function hoursForIdyPercent(idyPct, tempF) {
  if (idyPct <= 0) return Infinity
  return FERMENT_A * Math.pow(idyPct, -FERMENT_ALPHA) * Math.exp(-FERMENT_BETA * (tempF - FERMENT_REF_TEMP_F))
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
//           idyPct, yeastType }
// All *Pct values are percentages of flour weight (flour itself is 100%).
function computeRecipe(input) {
  var totalDoughG = Math.max(0, input.ballWeight * input.ballCount)
  var yeastPct = input.idyPct * yeastMultiplier(input.yeastType)
  var sumFraction = 1
    + input.hydrationPct / 100
    + input.saltPct / 100
    + input.oilPct / 100
    + input.sugarPct / 100
    + yeastPct / 100
  var flourG = sumFraction > 0 ? totalDoughG / sumFraction : 0
  return {
    totalDoughG: totalDoughG,
    flourG: flourG,
    waterG: flourG * input.hydrationPct / 100,
    saltG: flourG * input.saltPct / 100,
    oilG: flourG * input.oilPct / 100,
    sugarG: flourG * input.sugarPct / 100,
    yeastG: flourG * yeastPct / 100,
    yeastPct: yeastPct
  }
}

function formatGrams(value) {
  if (!isFinite(value)) return "0 g"
  if (value < 10) return value.toFixed(1) + " g"
  return Math.round(value) + " g"
}

function sizeDescriptionFor(input) {
  return input.shape === "pan"
    ? input.panWidthIn + "×" + input.panLengthIn + "\" pan"
    : input.sizeIn + "\" round"
}

// Builds the ingredient rows shared by the plain-text and HTML recipe
// renderers, so the two formats can't drift apart.
// input: same shape as computeRecipe()'s input, plus { recipe } (the
// already-computed result) and { shape, sizeIn, panWidthIn, panLengthIn,
// thicknessLabel, ballCount, ballWeight, fermentHours, fermentTempF }.
function recipeIngredientRows(input) {
  var rows = [
    ["Flour", formatGrams(input.recipe.flourG)],
    ["Water", formatGrams(input.recipe.waterG) + " (" + input.hydrationPct + "% hydration)"],
    ["Salt", formatGrams(input.recipe.saltG) + " (" + input.saltPct + "%)"]
  ]
  if (input.oilPct > 0) rows.push(["Oil", formatGrams(input.recipe.oilG) + " (" + input.oilPct + "%)"])
  if (input.sugarPct > 0) rows.push(["Sugar", formatGrams(input.recipe.sugarG) + " (" + input.sugarPct + "%)"])
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
  lines.push("Fermentation: " + input.fermentHours + "h at " + input.fermentTempF + "°F")
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
    + "<p class=\"sub\">Fermentation: " + input.fermentHours + "h at " + input.fermentTempF + "°F</p>"
    + "</body></html>"
}
