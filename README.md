# Pixel Pets

A pixel-art cat that lives on your [Omarchy](https://omarchy.org) desktop. She walks along the bottom of the
screen, sits, naps, and stays out of your way: clicks next to her go straight through to your windows.

- **Click** her to pet her.
- **Drag** her to pick her up, let go to drop her.

Now and then she jumps up and hangs from the top edge of one of your windows, then drops back down. She lets
go if the window closes, moves away, or you click her.

She hides under fullscreen apps.

## Install

```sh
omarchy plugin add https://github.com/skrilexxx/omarchy-pixel-pets --enable
```

Remove with `omarchy plugin remove skrilexxx.pixel-pets`.

## Develop

```sh
python3 tools/make_sprites.py   # redraw sprites/cat.png (edit PALETTE to recolor)
node tools/test_brain.js        # behaviour self-check
omarchy plugin validate .

# install the working copy (plugin folders may not be symlinks)
rsync -a --delete --exclude .git ./ ~/.config/omarchy/plugins/skrilexxx.pixel-pets/
omarchy-shell shell rescanPlugins
omarchy plugin enable skrilexxx.pixel-pets
omarchy restart shell           # needed after changing .qml/.js; images hot-reload, code does not
```

Layout: `Service.qml` is the window and input, `Brain.js` is the behaviour, `tools/make_sprites.py` draws the
sprite sheet (32x32 frames, one row per animation).

## License

MIT, code and art.
