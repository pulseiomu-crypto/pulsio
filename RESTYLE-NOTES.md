# PulsIO — Restyle Notes

**Evidence-based comparison of the landing page and the app, and the finish changes the app adopts from it.**

- Compiled: 2026-09-05
- Sources read side by side: [`index.html`](index.html) (the pulsio.mu landing page) and [`pulsio-app-v1_18.html`](pulsio-app-v1_18.html) (the app).
- The landing page is the reference the app should *feel* like. This document records **what actually differs** and, at the end, **the finish changes the app adopts** — a short list, not a redesign.

> **Framing:** both files are built from the **same design language** — identical brand palette (`#060E18` abyss, `#00D4A8` teal, plus amber/coral/sky/green/purple), the same three fonts (Syne / IBM Plex Mono / Instrument Sans), same `theme-color`. This is one system used in **two registers**, not two systems. Every difference below is *usage*, not vocabulary.

---

## 1. Colour

| | Landing | App |
|---|---|---|
| Secondary text | `--muted` bone **0.42**, `--faint` **0.22** | `--muted` bone **0.55**, `--muted-2` **0.34** (brighter) |
| Hairlines | `--line` = **teal 0.12**, used for *every* border/divider/grid | `--hair` = **bone 0.09** (neutral); teal only in `--hair-active` **0.40** |
| Teal's role | pervasive brand accent — carries nearly everything | **reserved** for live/active (its CSS says so) |

The landing uses teal everywhere (hairlines, eyebrows, step numbers, H1 stroke, ring, hero canvas); other accents appear only as tiny decorative dots. The app **rations teal** to live/active state and uses the full palette **semantically** (amber = temp/CEB/warning, coral = LIVE/alert/emergency, sky = humidity/sea, green = fuel/safe). Landing depth = flat abyss + blurred colour **glows** + film grain; app = opaque surface stack.

## 2. Typography

- Weights: landing loads Syne `700;800` only; the app adds Syne `400;600` and Mono `600` for finer small-size hierarchy.
- Range: landing **9→124px** (hierarchy by dramatic scale); app tops out at **30px**, most UI **10–13px** (hierarchy by weight + colour + mono/sans pairing).
- Tracking: landing pushes mono wide (`hero-tag` **.32em**, eyebrows .26–.28em); app similar logic, lower ceiling (mostly .08–.14em).
- Case: landing uppercases display; the app's headings are sentence case.

## 3. Spacing & density

- Landing: bespoke large rhythm — **130px** sections, 1180px centred column, roomy card padding; document-like, airy.
- App: Tailwind 4px scale — `p-4`, rows `py-2.5` (**10px**), `h-screen; overflow:hidden`; a single fixed viewport, high density.

## 4. Surfaces & edges

| | Landing | App |
|---|---|---|
| Border width | **0.5px** | **1px** |
| Radii | larger — 14 / 18 / **22px**, pills | 6 / 10 / 14 / 18, cards cluster 8–14 |
| Depth | almost none — blur, `blur(90px)` glows, dot glows | explicit shadows `--e-1/--e-2/--e-teal/--lift` |

## 5. Motion

- Landing: ambient + scroll-choreographed + long — grain, breathing logo, 42s marquee, a full hero canvas (contours/sonar/pings/waves/particles), scroll parallax, reveal-on-scroll (**.9s** `cubic-bezier(.2,.7,.2,1)`), score count-up.
- App: short, triggered, tactile — `--dur 140/240/420ms`, spring easing, **press `scale(.97)` 80ms**, modal/panel transitions ≤420ms; one cinematic *interactive* set-piece (the PulseFX pulse ceremony).

---

## ⚑ Flag A — landing treatments that DON'T translate to an app

The hero (100svh, 124px caps, teal text-stroke, animated Mauritius canvas, parallax, scroll cue, tagline scramble); all scroll choreography (nav solidify, progress bar, reveal stagger, glow parallax) — the app is a fixed viewport; the brand marquee; full-screen film grain; the "classified until launch" frost panel; the 130px section rhythm / 1180px column; the 230px count-up PulsScore ring. Portable *feel* only: the long ease-out curve and entrance stagger — not the canvas or scroll rig.

## ⚑ Flag B — app choices that are deliberate function, NOT drift (these STAY)

- **Dense data rows** — information density is the product.
- **Semantic multi-colour coding** — amber/coral/sky/green carry meaning.
- **Neutral hairlines, teal reserved for live/active** — so "what's live" pops.
- **Brighter secondary text (0.55)** — legibility of 11px text outdoors.
- **Compressed ≤30px type scale + extra weights** — a fixed viewport needs many small tiers.
- **Real elevation system** — communicates stacking (panel over map, modal over panel).
- **Fast tactile motion (spring + press-scale)** — tap feedback.

---

## ✅ Applied restyle — finish changes the app adopts

A short list of finish moves that pull the app toward the landing's feel **without touching anything in Flag B**:

1. **Hairlines: 0.5px, not 1px.** Thin the neutral structural hairlines to 0.5px (keep them neutral — Flag B). Teal stays reserved for active/live.
2. **Radii: larger and softer.** Move cards/sheets/inputs up the scale (toward the landing's 14–22px), keeping the token ramp coherent.
3. **Glow-based depth alongside shadows.** Add subtle blurred colour glow (the landing's atmosphere) *in addition to* the existing `--e-*` shadow system — not instead of it. Elevation stays.
4. **Wider mono tracking on labels.** Push eyebrow/label letter-spacing toward the landing's .2–.28em range.
5. **Longer ease-out for entrances.** Adopt the landing's `cubic-bezier(.2,.7,.2,1)` (~.5–.9s) for panel/sheet/modal *entrances*. Keep fast spring + press-scale for taps/feedback (Flag B).

Everything else — palette, fonts, density, semantic colour, neutral hairlines, brighter text, compressed scale, tactile feedback — is unchanged.
