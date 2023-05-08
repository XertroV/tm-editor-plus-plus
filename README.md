# Editor++

License: Public Domain

Authors: XertroV

Suggestions/feedback: @XertroV on Openplanet discord

Code/issues: [https://github.com/XertroV/tm-play-map](https://github.com/XertroV/tm-play-map)

GL HF

done:
- add set next cp linked status (tntree)

todo:
- port effects from IPT
- port item repeat from IPT
- add 'luck' param to placed items (bmx22c)
- add mass apply property
- add mass transform
- add block/item index
- create groups of blocks/items
- re-find block/item based on coords/props (block done)
- implement search
- save state in some way to persist between editor sessions
- when creating items, set the block coord
- find/replace blocks/items
- scroll on vec3 inputs to change value
- blocks: normal to ghost or free, and vice versa
- blocks: add duplication method
- randomizer: change blocks and items to be random blocks / items
- validation runs: track and record validation runs this session -- expose data for medals & validation tab
- save and reload map: add caching camera coords and move camera
- add cam movement API in general
- (todo: fill list out more)

research:
- convert normal block to free block?
- item inventory refresh via blendermania
  - create map with items

else:
- export all functions in namespace

test:
- when refresh marked as unsafe, does adding items via the items update method work?
