# Pixel Pets

A pixel-art cat that lives on your [Omarchy](https://omarchy.org) desktop. She walks along the bottom of the
screen, sits, naps, and stays out of your way: clicks next to her go straight through to your windows.

- **Click** her to pet her.
- **Drag** her to pick her up, let go to drop her.
- **Double-click** her to give her a ball of yarn. She chases and bats it around; you can drag and throw it too.
- Wiggle the **mouse** near the bottom of the screen and she may stalk and pounce on it.

Now and then she jumps up and hangs from the top edge of one of your windows, then drops back down. She lets
go if the window closes, moves away, or you click her.

Between all that she grooms, yawns, and stretches after naps.

She hides under fullscreen apps.

## Settings

Click the cat icon in the bar to open her settings: name, coat (orange, grey, tuxedo, white, cream),
size, energy (lazy to playful), whether she chases the mouse or hangs from windows, and a button to give her
a yarn ball. Right-click the icon to hide or show her. Her name pops up when you pet her.

Settings are saved in `~/.config/omarchy/pixel-pets.json`.

## Install

```sh
omarchy plugin add https://github.com/skrilexxx/omarchy-pixel-pets --enable
```

Remove with `omarchy plugin remove skrilexxx.pixel-pets`.

## Develop

```sh
python3 tools/make_sprites.py   # redraw sprites/cat-<coat>.png (coats are in COATS)
node tools/test_brain.js        # behaviour self-check
omarchy plugin validate .

# install the working copy (plugin folders may not be symlinks)
rsync -a --delete --exclude .git ./ ~/.config/omarchy/plugins/skrilexxx.pixel-pets/
omarchy-shell shell rescanPlugins
omarchy plugin enable skrilexxx.pixel-pets   # puts the icon in the right of the bar
omarchy restart shell           # needed after changing .qml/.js; images hot-reload, code does not
```

Layout: `Service.qml` is the pet window, input and saved settings, `Panel.qml` is the bar icon and settings
panel, `Brain.js` is the behaviour, `tools/make_sprites.py` draws the
sprite sheet (32x32 frames, one row per animation).

## License

MIT, code and art.
