# Layout assessment — preliminary, for the next round

Scope: **read-only assessment of v0.6.17 source.** No bug was fixed. Everything below marked
"confirmed" was read in the source; "unconfirmed" means it needs a live run to settle.

The problem this fork exists for: the plugin perturbs the layout of existing notes. This document maps
the mechanism so the fix can be targeted rather than exploratory.

---

## 1. Where the non-destructive parameters live

**In the note's Markdown — a trailing attr_list block on the image line.** No sidecar file, no HTML
attribute in the file, no entry in `data.json`.

- Write: `src/transforms.ts` → `serializeTransform()` → `buildEmbed()` → `src/source-writer.ts` →
  `writeSource()`, applied as a single `isolateHistory` transaction (so undo is one step).
- Read: `scanAttributeBlock()` (`src/link-format.ts`) → `parseAltText()` (`src/transforms.ts`).

Key order produced by the serializer: `.inline`, `.class…`, `align=`, `rotate=`,
`flip=horizontal|vertical`, `transform="…"`, `filter="…"`, `aspect-ratio=`, `width=`, `height=`,
`style="…"`. Example:

```markdown
![[photo.png]]{aspect-ratio=1.7777 transform="translate(-12.5%, -8%) scale(2.4)" width=320}
```

Native sizes (`![[img|300]]`) are **folded into the block** by `applyNativeSize()` / `foldNativeSize()`,
never left in the pipe.

**Consequence for this fork:** the format is independent of the plugin ID, which is why the rename is
safe. It also means **the format is a compatibility contract** — do not change key names, ordering, or
escaping while fixing layout.

## 2. How rendering works (two independent paths)

| View | Entry point | Mechanism |
|---|---|---|
| Live Preview | `src/live-preview.ts` → `createLivePreviewExtension()`, registered in `main.ts:onload` via `registerEditorExtension(Prec.highest(...))` | CodeMirror 6 `StateField` + `EditorView.decorations` + `RangeSetBuilder<Decoration>`. Decorations used: `Decoration.widget` (`FakeLinkWidget`, `EmbedWidget`), `Decoration.mark` (`lie-suppress-native`, `lie-attr`), and `{block:true}` for bare embeds. **No `Decoration.replace` anywhere** — the native embed is not replaced, it is hidden by CSS and the plugin draws its own image inside a widget. |
| Reading View | `main.ts:90` `registerMarkdownPostProcessor(...)` → `postProcessor()` → `processBlock()` → `applyTransformToImage()` → `src/render-core.ts` `buildLayers()` | Post-processor walks rendered DOM, plus a reconcile pass (`reconcileFromSource` / `applySourcePairs`, `main.ts:550-563`). |

**Both paths wrap the `<img>` in new nodes.** `render-core.ts::ensureLayers()` inserts
`span.lie-image-area > span.lie-frame` around the image; `EmbedWidget.toDOM()` builds
`div.lie-wrapper > div.lie-box > div.lie-image-host > .lie-image-area > .lie-frame > img`.

That wrapper is the single most important fact in this document: any layout bug is most likely a
consequence of a wrapper element being injected into a container that never expected one.

---

## 3. Layout-breakage suspects (ranked)

### S1 — `.lie-frame { position: absolute }` makes the image leave the flow — *confirmed*

`sizeLayers()` gives the outer element an inline `width` and `aspect-ratio`; the `<img>` itself is
absolutely positioned inside it. Until the natural size is known, the outer box has no in-flow content.
The natural size arrives via `whenNatural()`, which **polls up to 20 × 50 ms**. In that window the
`aspect-ratio: var(--lie-auto-aspect, auto)` falls back to `auto`, so the box can collapse to zero
height and then pop to full height.

Affects: plain images, list items, callouts, tables — anything that measures its own height.

### S2 — list items are classified as *inline* — *confirmed; top suspect for the list complaint*

`src/live-preview.ts::collectEmbeds()` decides whether an embed stands alone with:

```ts
standalone = doc.sliceString(line.from, from).trim() === ""
```

For `- ![[photo.png]]` the text before the embed is `- `, which `.trim()`s to `"-"` — not `""`. So a
list-item image is classified **inline**, and an inline `Decoration.widget` whose DOM is
`div.lie-wrapper { display: inline-block }` is injected **inside the `li`'s `.cm-line`**. The result is
the expected two failures at once: the list line's height is inflated by an inline-block box, and text
flows beside the image instead of the image occupying its own line.

Note `.lie-wrapper-standalone { display:block; z-index:1 }` exists precisely to push a non-floated
image onto its own line — the list case never reaches it.

### S3 — `:has()` rules rewrite the host element — *confirmed*

`styles.css` (~lines 200-220, 295-298, 376-388) sets `float`, or `display:block; width:100%`, on the
**host** (`.lie-wrapper` / `.image-embed`), and includes
`.image-embed:has(…) + br { display: none }`, which removes a sibling `<br>` the host may be relying on.
`:has()` also re-evaluates on every DOM mutation, so it can interact badly with the reconcile pass.

### S4 — the host is given `display: inline-block` — *confirmed*

`main.ts:306` and `main.ts:560` add `.lie-embed { display: inline-block }` to Obsidian's own
`.image-embed`. `.lie-has-caption` switches the host to `inline-flex; flex-direction: column`.
Both override Obsidian's native block-level embed behaviour inside tables and callouts.

### S5 — post-processor assumes one image per block, in document order — *confirmed*

`postProcessorImages()` returns `null` when an `.internal-embed` contains ≠1 `<img>`.
`POSTPROCESSOR_BLOCK_SELECTOR = ".cm-embed-block.markdown-rendered, .cm-embed-block.cm-callout"` maps a
whole render block to its images **by document order**. Any block that renders extra images (callout
with an icon, a table containing several images) can mis-pair source with DOM.

### S6 — lists have no CSS at all — *confirmed*

`styles.css` contains **zero** `li` / `ul` / `ol` selectors. There is no list-specific handling
anywhere; the list case is simply the generic inline case applied to a list. This matches the reported
symptom.

### Unconfirmed (needs a live run)

- Whether nested-list indentation is affected beyond the inline-block line-height effect.
- Whether `.lie-frame`'s absolute positioning escapes its containing block inside callout padding.
- Exact px deltas — the box is integer-rounded (`nativeBoxWidth` / `rotatedAabb` in
  `src/renderer-logic.ts` use `Math.round`, and 90°/270° swaps axes), so ±1 px differences from the
  native line box are expected even when everything "works".

### One dead guard worth knowing

`src/attach-logic.ts::isHiddenHostCopy()` has **no production caller** — only
`tests/unit/attach-logic.test.ts`. The `display:none` ancestor check it implements is therefore not
protecting anything at runtime.

---

## 4. Minimal-change fix strategies (ordered by risk)

**A — make the wrapper flow-neutral (recommended first attempt).** Write the outer element's px
`width`/`height` **synchronously** from `naturalWidth`/`naturalHeight` at wrap time so S1's collapse
window disappears, and scope `vertical-align`/`line-height` to non-inline hosts. Touches no inviolable
doc. Caveat: `RENDER_CSS` in `render-core.ts` and its byte-identical copy in `styles.css` must change
**together** — a unit test asserts they match.

**B — `display: contents` on the wrapper in inline hosts.** Keeps the wrapper in the DOM (so
decorations and reconcile still find it) but removes it from the flow. Low code footprint; the risk is
that `.lie-frame`'s absolute positioning loses its containing block. Needs verification before trust.

**C — host-aware suppression.** When the image sits inside `li, td, th, .callout`, skip `ensureLayers`
and apply only a class/mark plus inline width/transform on the native `<img>`. Smallest runtime
footprint, **highest design risk**: `architecture.md` AD3 mandates the uniform three-layer image
structure, so this probably violates an inviolable document — which upstream rules forbid without
escalating to the user.

Sequence: try **A**, measure; fall back to **B**; treat **C** as a design decision, not a patch.

---

## 5. Regression matrix

| # | Case | Layer | Assertion |
|---|---|---|---|
| 1 | Unordered list, image on its own item | CDP | `li` height unchanged ±0 px vs. native; bullet top == image top ±1 px; no extra line box |
| 2 | Nested list | CDP | inner `ul` `padding-inline-start` and `li` left edge unchanged; `scrollWidth <= clientWidth` |
| 3 | Callout | CDP | `.callout` height delta ±0 px when untransformed; no `.lie-wrapper` escaping the callout |
| 4 | Table cell | CDP | `td` height parity; cell count unchanged (already asserted today) |
| 5 | HTML `<img>` | CDP | `getBoundingClientRect()` ratio == `naturalWidth/naturalHeight` ±0.01; attributes untouched |
| 6 | Plain Markdown image | CDP | Reading View: `img.closest('.lie-image-area') === null` — proves the `hasTransforms` gate still holds |
| 7 | Image is the only content of a list item | CDP | `li` height == img height + 2 × `padding-block` ±0 px |
| 8 | Width serialization round-trip | unit | `- ![[img.png]]{width=200}` survives `rewriteWidth` / `buildEmbed` with the `- ` prefix and block intact |

**Critical structural finding:** unit tests **cannot** catch the list case. `lineDecorations` uses
`scanWholeLineEmbed`, which rejects `- ![[x]]`, while the real Live Preview path uses
`collectEmbeds` + `scanEmbed`. The two disagree about the same input, which is exactly why this bug
reached users. Any list regression must be a CDP test.

**Extend, don't duplicate:**

- `tests/cdp/verify-toolbar-hosts.mjs` — `HOST_LINES` already contains `table-host`, `callout-host`,
  `footnote-host`. Add `list-host` / `nested-list-host` here.
- `tests/cdp/verify-table-host.mjs` — already asserts cell counts.
- `tests/unit/regressions.test.ts` — already covers the Bug 78/79 native-cap sizing (box collapse).
- `tests/unit/live-preview.test.ts` — already covers `rewriteWidth` / `inlineEmbeds`.
- `tests/unit/render-core.test.ts` — already asserts `RENDER_CSS` identity with `styles.css`.

**Vault gap:** `vault-image-toolbar/` has `08 — Tables.md` but **no list note**. Added
`vault-peng/09 — Lists & nesting.md` locally (gitignored) with seven cases: image-only item, image
mid-sentence, nested list, ordered list, cropped image in a list, block image in a list, and a
plain-paragraph control block. Consider mirroring it upstream later.

---

## 6. Suggested order of work

1. Add the list repro note to `vault-peng/`, reproduce S2 by eye, and confirm the inline classification
   with a CDP probe. *(Cheapest, and it validates the whole assessment.)*
2. Implement **A**; measure cases 1-7 before/after with CDP.
3. Only then decide whether **B** is needed.
4. Keep `docs/development/` untouched throughout; fork-side notes live here.
