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
