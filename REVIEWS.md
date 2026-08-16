# Review process

We review E++ changes through **GitHub compare views in the browser**, then move review tags. Nothing about the tags is automated — they move only when Max says so.

## Tags

| Tag | Meaning |
|---|---|
| `latest-reviewed` | The most recent commit Max has reviewed. Points into `master` history. |
| `reviewed-YY-MM-DD-HH-MM` | Timestamped snapshot of a review point. Created at the **new** tip (the commit just reviewed) whenever `latest-reviewed` moves, using the local time the review happened. |

Conventions:

- `latest-reviewed` is **force-moved** (`git push -f`) to the reviewed commit; it is not a rolling branch.
- A dated `reviewed-YY-MM-DD-HH-MM` tag is created at the **new** tip each time `latest-reviewed` moves. The previous tip already has its own dated tag from when it was reviewed (no retro-tagging needed).
- Tags are only moved/created on explicit instruction ("update latest-reviewed", "review done at <commit>", etc.). Never infer a review.
- Release tags (`0.8.x…`) are separate and move only on a release decision; they are **not** review markers.

## Opening a review

1. Push `master` so the remote has the commits.
2. Open the compare view with the reviewed tag and the current master shorthand:
   `https://github.com/XertroV/tm-editor-plus-plus/compare/latest-reviewed...<short-sha>`
3. Max reviews in the browser (files/commits tabs as needed).

## After a review

On Max's word ("update latest-reviewed to <sha>" or equivalent):

```bash
NEW_SHA=<short-sha>            # commit just reviewed
STAMP=$(date +%y-%m-%d-%H-%M)  # local time
git push -f origin "$NEW_SHA:refs/tags/latest-reviewed"
git push origin "$NEW_SHA:refs/tags/reviewed-$STAMP"
```

- Old dated tags stay where they are.
- If the release asset should also be rebuilt, that's a separate step (`0.8.x` tag force-move + manual GH release edit — see AGENTS.md / release notes in `research/`).
