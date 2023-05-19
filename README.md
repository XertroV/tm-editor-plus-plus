# Editor++

Current features:

- Edit map properties, including height
- See all blocks and items with details, and focus the cam on them, delete normal/ghost blocks
- Create quick-access windows for folders of blocks/items
- QoL improvements for the cursor, incl reset and manual set
- Edit properties of arbitrary blocks and items, including location (*with live refresh*)
- Embed items in the map so you can use them without restarting the game
- Browse and edit BlockInfo and variants
- Choose the variant and ground status of the selected block
- Fine tune item placement params (or set them to whatever you want)
- Edit item placement layouts for more/less items and customize the position
- Apply vanilla placement layouts to custom items (so you could have a custom road sign, for example)
- Autoset newly placed checkpoints linked status and/or order
- Repeat items in various patterns
- Dissociate items from blocks so you can delete the block without deleting the item
- Apply a jitter to items upon placement (position and/or rotation and/or position offset)
- Randomizer: various properties of blocks and items
- Dev Info: access to convenient utilities and previously hidden properties of blocks and items



License: Public Domain

Authors: XertroV

Suggestions/feedback: @XertroV on Openplanet discord

Code/issues: [https://github.com/XertroV/tm-play-map](https://github.com/XertroV/tm-play-map)

GL HF

todo:
- add 'luck' param to placed items (bmx22c)
- add mass apply property
- add mass transform
- add block/item index
- create groups of blocks/items
- implement search
- save state in some way to persist between editor sessions
- find/replace blocks/items
- scroll on vec3 inputs to change value
- blocks: normal to ghost or free, and vice versa
- blocks: add duplication method
- randomizer: change blocks and items to be random blocks / items
- validation runs: track and record validation runs this session -- expose data for medals & validation tab
- expose inventory selection via api
- modify block variant props
- intercept undo or things that might crash with references to selected block
- bettor 'cursor' editor-plugin as titleless window
- (todo: fill list out more)
- cloning light sphere gives cannot save map error but it saves the item okay

research:
- convert normal block to free block?

else:
- export all functions in namespace

test:
- when refresh marked as unsafe, does adding items via the items update method work?



good icons mb:
- road
- flag
- bookmark
- gift
- magnet
- thumbtack
- cameraretro
- plus
- filter
- arrowsalt
- scissors
- gavel
- undo
- sitemap
- umbrella
- PuzzlePiece
- bullseye
- leveldown/up
- anchor
