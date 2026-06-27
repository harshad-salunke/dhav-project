# DHAV — Home Tab Background Image Prompts

4 marketplace tab background images for the customer-app home page.
**Each prompt below is fully self-contained** — style, aspect ratio, colors, and
the "avoid" list are all baked into every single prompt, so you can paste ANY ONE
of them into ANY generator (Midjourney, DALL·E, Ideogram, Flux, Leonardo, Canva,
Bing, etc.) on its own and get the right image. Do NOT change the hex colors.

> Quick settings if your tool asks separately: **Aspect ratio 3:2 (landscape)**,
> **1080 × 720 px** (or 2× = 2160 × 1440), **PNG**, gradient runs **top → bottom**.

---

## TAB 1 — DHAV (Groceries) · BLUE
**Filename:** `tab_grocery.png`

```
SETTINGS — Aspect ratio: 3:2 landscape. Resolution: 1080 x 720 pixels (or 2x = 2160 x 1440). Format: PNG. Gradient direction: top to bottom.

A modern flat-vector mobile-app tab background, 3:2 landscape aspect ratio, 1080x720 pixels, premium clean style like the Blinkit / Zepto / Swiggy app UI with soft 3D rounded icons. Theme: blue grocery store. Smooth seamless background gradient running top to bottom, from bright blue #2196F3 at the top to deep blue #1565C0 at the bottom. Tiny grocery objects float as a soft scattered pattern across the whole tile in soft white and pale sky-blue: a shopping bag, a milk carton, a bread loaf, a red tomato, a green leafy vegetable, a sack of rice or grains — everyday Indian kirana essentials, friendly and fresh. The icons are blurred and faded at low opacity around 25 to 30 percent, gently darkened toward the center so white text placed on top stays perfectly readable. Soft studio lighting, subtle glossy highlights, no harsh shadows, edge-to-edge composition, no border, no frame. Negative / avoid: no text, no letters, no words, no numbers, no logos, no watermark, no brand names, no people, no hands, no realistic photo, no clutter, no busy detail, nothing sharp or high-contrast in the center, no white background. --ar 3:2
```

---

## TAB 2 — Fresh Fruits · GREEN
**Filename:** `tab_fruits.png`

```
SETTINGS — Aspect ratio: 3:2 landscape. Resolution: 1080 x 720 pixels (or 2x = 2160 x 1440). Format: PNG. Gradient direction: top to bottom.

A modern flat-vector mobile-app tab background, 3:2 landscape aspect ratio, 1080x720 pixels, premium clean style like the Blinkit / Zepto / Swiggy app UI with soft 3D rounded icons. Theme: fresh fruit market. Smooth seamless background gradient running top to bottom, from leaf green #43A047 at the top to deep forest green #2E7D32 at the bottom. Tiny fruit objects float as a soft scattered pattern across the whole tile in soft white and pale mint: a watermelon slice, a red apple, a bunch of purple grapes, an orange slice, a strawberry, a small green leaf — juicy, fresh-from-the-farm, organic feel. The icons are blurred and faded at low opacity around 25 to 30 percent, gently darkened toward the center so white text placed on top stays perfectly readable. Soft studio lighting, subtle glossy highlights, no harsh shadows, edge-to-edge composition, no border, no frame. Negative / avoid: no text, no letters, no words, no numbers, no logos, no watermark, no brand names, no people, no hands, no realistic photo, no clutter, no busy detail, nothing sharp or high-contrast in the center, no white background. --ar 3:2
```

---

## TAB 3 — Electronics · INDIGO / NAVY
**Filename:** `tab_electronics.png`

```
SETTINGS — Aspect ratio: 3:2 landscape. Resolution: 1080 x 720 pixels (or 2x = 2160 x 1440). Format: PNG. Gradient direction: top to bottom.

A modern flat-vector mobile-app tab background, 3:2 landscape aspect ratio, 1080x720 pixels, premium clean style like the Blinkit / Zepto / Swiggy app UI with soft 3D rounded icons. Theme: premium tech gadgets. Smooth seamless background gradient running top to bottom, from indigo #3949AB at the top to deep navy #1A237E at the bottom. Tiny electronics objects float as a soft scattered pattern across the whole tile in soft white and pale lavender: over-ear headphones, a smartphone, wireless earbuds, a smartwatch, a small lightning or charging bolt — sleek, modern, premium-tech feel. The icons are blurred and faded at low opacity around 25 to 30 percent, gently darkened toward the center so white text placed on top stays perfectly readable. Soft studio lighting, subtle glossy highlights, no harsh shadows, edge-to-edge composition, no border, no frame. Negative / avoid: no text, no letters, no words, no numbers, no logos, no watermark, no brand names, no people, no hands, no realistic photo, no clutter, no busy detail, nothing sharp or high-contrast in the center, no white background. --ar 3:2
```

---

## TAB 4 — Pharmacy · TEAL
**Filename:** `tab_pharmacy.png`

```
SETTINGS — Aspect ratio: 3:2 landscape. Resolution: 1080 x 720 pixels (or 2x = 2160 x 1440). Format: PNG. Gradient direction: top to bottom.

A modern flat-vector mobile-app tab background, 3:2 landscape aspect ratio, 1080x720 pixels, premium clean style like the Blinkit / Zepto / Swiggy app UI with soft 3D rounded icons. Theme: trusted pharmacy and healthcare. Smooth seamless background gradient running top to bottom, from cyan teal #00ACC1 at the top to deep teal #00897B at the bottom. Tiny medical objects float as a soft scattered pattern across the whole tile in soft white and pale aqua: capsules and round pills, a medicine bottle, a soft rounded medical-plus cross, a blister pill strip, a thin heartbeat line — clean, calm, trustworthy, clinical-but-friendly feel. The icons are blurred and faded at low opacity around 25 to 30 percent, gently darkened toward the center so white text placed on top stays perfectly readable. Soft studio lighting, subtle glossy highlights, no harsh shadows, edge-to-edge composition, no border, no frame. Negative / avoid: no text, no letters, no words, no numbers, no logos, no watermark, no brand names, no people, no hands, no realistic photo, no clutter, no busy detail, nothing sharp or high-contrast in the center, no white background. --ar 3:2
```

---

## Notes

- The `--ar 3:2` at the end is for **Midjourney**. On other tools it's harmless,
  but you can delete it and instead pick **3:2 / landscape** in the tool's ratio
  setting. The phrase "3:2 landscape aspect ratio, 1080x720 pixels" inside the
  prompt already states it, so the ratio is covered either way.
- Generate all 4 in one session, or use image #1 as a **style reference** for the
  other 3, so the set looks identical.

### If a result looks wrong
| Problem | Add this sentence to the prompt |
|---------|--------------------------------|
| Icons too bold / distracting | "Icons very faint, almost transparent, blurred background watermark." |
| Text would be unreadable | "Darker solid gradient, objects only near the edges, empty calm center." |
| Looks like a photo | "Flat 2D vector, simple icon style, not realistic, not 3D render." |
| Stray text/letters appear | Re-run; add "absolutely no text or letters anywhere in the image." |
| Wrong colors | Paste the two hex codes again at the very end of the prompt. |

### After generating
1. Save the 4 PNGs with the exact filenames above.
2. Put them in `customer_app/assets/images/tabs/`.
3. Tell me — I'll register them in `pubspec.yaml`, wire each to its marketplace
   (`grocery` / `fruits` / `electronics` / `pharmacy`), convert the tab bar to
   full-width (no scroller), and add a readability scrim behind the label.
