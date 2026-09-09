# Kneadra

![Kneadra preview](preview.png)

A pizza dough baker's-percentage calculator for the Omarchy bar. Click the
🍕 icon to open it.

Set the number of dough balls and choose round (with a diameter override)
or a rectangular pan (width × length), plus a crust Thickness Factor —
Thin/Medium/Thick presets, or an advanced raw oz/in² override for anyone
who already knows their number — to get a suggested per-ball dough weight
(always editable by hand). Baker's percentages — hydration, salt, oil,
sugar — are set with sliders. Pick a fermentation temperature (°F) and
target time, and the yeast percentage is computed from a
temperature/time model (shorter or warmer ferments need more yeast; long,
cold ferments need very little). Yeast type (instant dry / active dry /
fresh) converts the final gram amount.

The recipe section at the bottom shows the resulting flour, water, salt,
oil, sugar, and yeast weights in grams for the total batch.

## Install

```bash
omarchy plugin add https://github.com/enobale/omarchy-kneadra --enable
```

Or, to keep a local editable copy instead of a git checkout:

```bash
git clone https://github.com/enobale/omarchy-kneadra ~/.config/omarchy/plugins/io.github.enobale.kneadra
omarchy plugin enable io.github.enobale.kneadra
```

## Remove

```bash
omarchy plugin remove io.github.enobale.kneadra
```

## Files

- `manifest.json` — plugin manifest (`kinds: ["bar-widget"]`)
- `BarWidget.qml` — bar icon + popup UI, built on Omarchy's `Panel` /
  `KeyboardPanel` / `WidgetButton` / `PanelSlider` / `NumberField` /
  `ButtonGroup` / `Dropdown` components (no external dependencies beyond
  the Omarchy shell's own `qs.Ui` / `qs.Commons` component kit)
- `Calculator.js` — pure dough-math helpers (dough-weight suggestion from
  pan area and Thickness Factor, temperature/time-based yeast percent,
  baker's-percentage solve)

## License

MIT — see [LICENSE](LICENSE).
