# ActivityWatch categories

Importable category set derived from ~90 days of Hyprland window titles
(`aw-watcher-window-hyprland`) plus browser tab patterns.

## Import

1. Open ActivityWatch → **Settings** → **Categorization**
2. Use **Import** and select `aw-categories.json`
3. Activate the set **`hyprland-enes`** if prompted, then **Save**

The file uses the export format `{ "id", "categories" }`, so it imports as its
own set and does not silently overwrite `default`.

## How matching works

- Rules match the window **`app`** and **`title`** fields (not URL alone).
- Deeper categories win; `priority` on a rule beats depth when set.
- Project rules (e.g. `coverlttr`) sit under `Work > Projects` so they beat
  generic `Work > Programming` when both match.

## After import

Revisit Top Categories for a recent day. Tweak regexes in the UI for anything
still in Uncategorized, or edit this JSON and re-import.
