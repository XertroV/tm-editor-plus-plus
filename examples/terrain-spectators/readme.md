Command to generate the spectator positions was like this:

```
python examples/spectators_from_image.py from-image \
  --method heightmap --facing-dir direction \
  --facing-point 1 1 --block-width 32.0 --hm-max-height 18.0 \
  --exported-file ~/OpenplanetNext/PluginStorage/editor++-dev/Spectators/Export.csv \
  --output-file ~/OpenplanetNext/PluginStorage/editor++-dev/Spectators/Import.csv \
  --spectator-limit 1000 \
  ~/win/Pictures/Openplanet/DecoPlatformDiag1.png
```

* block-width was 32 or 64 depending on the block
* facing-point was usually `-1 -1` or `0 -1` depending on the block (some others, too)
* facing-dir was either `direction`, `awayfrom`, or `towards`
* hm-max-height is calibrated so 0xFF in the red channel = 18 height -- the other colors are scaled to this, with 0x00 being 0 height
* spectator-limit was 500 for triangle/hole, 1000 for 1x1, 2000 for 2x1, and 4000 for 2x2 blocks
