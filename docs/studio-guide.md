# Studio guide

## Preview and save

- Pick a palette or change individual colors in **Appearance**. The **Living patterns** card sets the motif, strength, and flow speed. Choose **Reduced motion** in the **Finish** card for a still preview.
- Try **Compact**, **Music**, or **Expanded** in the viewfinder. **Paper**, **Slate**, and **Night** change the preview backdrop.
- Use **Ctrl+K** to find a setting and **Ctrl+S** to apply the current draft.
- **Apply changes live** automatically saves edits. Turn it off to stage changes before pressing **Apply changes**.
- **Undo session** restores the Studio-managed fields to their values at the start of the session. Other configuration fields are preserved.

## Use it with a compatible shell

With the prerequisites in the [README](../README.md) installed, run `python studio/studio.py` to open the regular editor. It reads `~/.config/latto/config.json` by default and follows `XDG_CONFIG_HOME` when set. To work on a specific configuration file, use `python studio/studio.py --config /path/to/config.json`.

Live effects require a Latto build that implements the corresponding settings and renderer. In particular, the ambient motifs and extended layout controls shown here depend on the matching Studio-compatible shell. Consult the shell’s own installation instructions and option list. [Upstream Latto](https://github.com/Fadilix/latto)

Studio creates a local backup before its first save in each editor session. Profile imports are staged for review. The isolated demo uses temporary settings and backups and disables shell lifecycle controls.

## Theme CLI

```sh
python studio/theme_cli.py --list
python studio/theme_cli.py "Aurora Rush" --dry-run
python studio/theme_cli.py "Neon Pulse"
python studio/theme_cli.py --motion reduced
python studio/theme_cli.py --effect off
python studio/theme_cli.py --restore
```

The first two commands preview choices. The others edit the regular Latto configuration. `--restore` restores the appearance saved before the first CLI edit.

## Run the tests

```sh
python -m pip install pytest
QT_QPA_PLATFORM=offscreen python -m pytest -q studio
```

The tests cover palette and preview behavior, geometry and motion, configuration validation, profile round-tripping, and widget input. The optional defaults check runs when `LATTO_RUNTIME_SETTINGS` points to the matching shell’s `Settings.qml`.
