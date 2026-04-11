# Phase 1: Scaffold & Compliance Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `01-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-04-11
**Phase:** 1 — Scaffold & Compliance Foundation
**Areas discussed:** App identity & naming, iOS CI signing path, Crash log format & surface, Placeholder UI scope, Drift v0 schema scope, Theme palette + fonts, Android/iOS SDK floors

---

## App identity & naming

### Q1: Bundle identifier

| Option | Description | Selected |
|--------|-------------|----------|
| com.jmclaughlin.murmur | GitHub/handle as owning namespace | |
| dev.jmclaughlin.murmur | 'dev' TLD convention | ✓ |
| app.murmur.reader | Product-branded TLD | |

**User's choice:** `dev.jmclaughlin.murmur`

### Q2: Display name

| Option | Description | Selected |
|--------|-------------|----------|
| murmur (all lowercase) | Matches project branding in docs | |
| Murmur | Title case | ✓ |

**User's choice:** Murmur

### Q3: Publisher name

| Option | Description | Selected |
|--------|-------------|----------|
| Jonathan McLaughlin | Assumed from PROJECT.md | |
| Studio name | Register under a brand | |
| Other (free text) | — | ✓ |

**User's choice:** Jake McLaughlin (free text)
**Notes:** PROJECT.md and CLAUDE.md both say "Jonathan" — that is incorrect. Jake is the correct name; treat prior doc references to "Jonathan" as stale.

---

## iOS CI signing path

### Q1: Apple Developer Program membership

| Option | Description | Selected |
|--------|-------------|----------|
| Already enrolled / will enroll | Enables signed IPA from CI | |
| Not yet — defer to Phase 4 | Ships Android-only CI | ✓ |
| Not sure | Research agent investigates | |

**User's choice:** Not yet — defer enrollment to Phase 4

### Q2: FND-09 iOS output

| Option | Description | Selected |
|--------|-------------|----------|
| Full signed IPA via fastlane match | Requires Apple Dev Program | |
| Unsigned .xcarchive smoke test | `flutter build ios --no-codesign` | |
| Defer iOS CI entirely to Phase 4 | iOS job scaffolded but disabled | ✓ |

**User's choice:** Defer iOS CI entirely to Phase 4

### Q3: Android signing

| Option | Description | Selected |
|--------|-------------|----------|
| Debug keystore committed to repo | Zero secrets management | ✓ |
| Upload keystore in GitHub secrets | Play Store uploadable from day one | |

**User's choice:** Debug keystore committed to repo
**Notes:** FND-09 wording narrowed accordingly — captured as D-06 in CONTEXT.md. Needs REQUIREMENTS.md amendment.

---

## Crash log format & surface

### Q1: Log format

| Option | Description | Selected |
|--------|-------------|----------|
| JSONL | Structured, greppable, renderable | ✓ |
| Plain text lines | Human-readable only | |

**User's choice:** JSONL

### Q2: Rotation policy

| Option | Description | Selected |
|--------|-------------|----------|
| 1MB cap, rotate to .1, keep 1 old | Ring policy, ~2MB max on disk | ✓ |
| Per-session file, fixed retention | New file per launch, keep N | |
| No rotation, append forever | Unbounded disk risk | |

**User's choice:** Single file capped at 1MB with one rotated old file

### Q3: Settings UI surface

| Option | Description | Selected |
|--------|-------------|----------|
| Scaffold row now, real viewer Phase 6 | Path + byte count only in Phase 1 | ✓ |
| Full viewer + share button in Phase 1 | Overlaps Phase 6 scope | |
| No Settings surface in Phase 1 | File-only, no UI | |

**User's choice:** Scaffold row now, real viewer in Phase 6

### Q4: Global error capture

| Option | Description | Selected |
|--------|-------------|----------|
| All three (FlutterError + onError + runZonedGuarded) | Catches everything async | ✓ |
| FlutterError.onError only | Minimal framework-level capture | |

**User's choice:** All three — full global capture

---

## Placeholder UI scope

### Q1: Screen finish level

| Option | Description | Selected |
|--------|-------------|----------|
| Themed empty states + functional theme picker | Scaffolds Phase 2/3 components | ✓ |
| Minimal stubs — screen name + route | Thinnest scaffold | |
| Functional-minimum per screen | Bleeds into Phase 2/3 scope | |

**User's choice:** Themed empty states with copy + Settings has a functional theme picker

### Q2: Theme persistence

| Option | Description | Selected |
|--------|-------------|----------|
| Persist via shared_preferences | One-line add, end-to-end smoke test | ✓ |
| Ephemeral in Riverpod state only | Resets on restart | |

**User's choice:** Yes — persist via shared_preferences

### Q3: System-theme-follow toggle

| Option | Description | Selected |
|--------|-------------|----------|
| 5-option picker: System / Light / Sepia / Dark / OLED | Respects FND-05 default | ✓ |
| No explicit toggle, picker has 4 themes | Simpler but breaks intent | |

**User's choice:** 5-option picker including System

---

## Drift v0 schema scope

### Q1: Schema scope at v0

| Option | Description | Selected |
|--------|-------------|----------|
| Empty schema, version=1 marker only | Cleanest phase separation | ✓ |
| Empty + trivial app_settings table | Overlap with shared_preferences | |
| Pre-bake Books + Chapters for Phase 2 | Violates phase boundaries | |

**User's choice:** Empty schema — schema_version=1 marker only

### Q2: Settings storage location

| Option | Description | Selected |
|--------|-------------|----------|
| shared_preferences for k/v; Drift for domain | Standard Flutter split | ✓ |
| All settings in Drift app_settings | Single source of truth | |

**User's choice:** shared_preferences for simple k/v; Drift reserved for domain data

### Q3: Migration strategy

| Option | Description | Selected |
|--------|-------------|----------|
| drift_dev generated migrations + schema dumps | Rigorous, build-time checks | ✓ |
| Hand-rolled onUpgrade initially | Simpler but tech debt | |

**User's choice:** drift_dev generated migrations from day one

---

## Theme palette + fonts

### Q1: Palette opinions

| Option | Description | Selected |
|--------|-------------|----------|
| Planner picks sensible defaults (Material 3) | Neutral defaults | |
| Specific colors in mind — specify during planning | User brings reference | ✓ (with reference) |

**User's choice (via free text):** `https://getdesign.md/clay/design-md` with "quiet library" feel.

**Notes:** User provided a specific design reference (Clay design system) and an aesthetic brief ("quiet library"). Workflow fetched the full Clay DESIGN.md and surfaced a mismatch: Clay is actually a warm/playful B2B design with a vivid swatch palette (Matcha/Slushie/Lemon/Ube/Pomegranate), which does NOT match "quiet library" on its own. User's neutral-base-only interpretation clarified the intent (see next sub-question). The full Clay DESIGN.md was saved to `.planning/research/CLAY-DESIGN.md`.

### Q1a (reconciliation): Clay fit with "quiet library"

| Option | Description | Selected |
|--------|-------------|----------|
| Clay neutral base only — drop swatches | Cream canvas + oat borders only | ✓ |
| Clay neutrals + one swatch as accent | Single muted ink-dark swatch | |
| Reject Clay — wasn't what I meant | Planner picks from brief | |

**User's choice:** Clay neutral base only (selected with preview showing the exact palette draft: background `#faf9f7`, surface `#ffffff`, border `#dad4c8`, border-lt `#eee9df`, text `#000000`, text-mute `#55534e`, text-dim `#9f9b93`)

### Q2: Font bundle

| Option | Description | Selected |
|--------|-------------|----------|
| Literata (serif, reader-optimized) | Google OFL serif | ✓ |
| Atkinson Hyperlegible (sans, accessibility) | Braille Institute, low-vision | |
| Inter (sans, neutral UI) | Modern UI sans | |
| Merriweather (serif, classic) | Screen-optimized serif | ✓ |

**User's choice:** Literata + Merriweather only (2 serifs)

### Q2a: 3rd font to satisfy FND-06 "3–4"

| Option | Description | Selected |
|--------|-------------|----------|
| Add Atkinson Hyperlegible | Accessibility sans | |
| Add Inter | Neutral sans | |
| Add both (Atkinson + Inter) | 4 fonts total | |
| Just two — amend FND-06 | Narrow requirement | ✓ |

**User's choice:** Just two; amend FND-06. Captured as D-21 in CONTEXT.md. Needs REQUIREMENTS.md amendment.

### Q3: UI chrome font

| Option | Description | Selected |
|--------|-------------|----------|
| System font (SF Pro / Roboto) | Native on each platform | ✓ |
| Inter for chrome AND reader | Single branded sans | |

**User's choice:** Use system font for chrome

---

## Android/iOS SDK floors

### Q1: Android minSdk

| Option | Description | Selected |
|--------|-------------|----------|
| API 24 (Android 7.0) | ~98% coverage, Flutter standard | ✓ |
| API 26 (Android 8.0) | ~94% coverage, cleaner lifecycle | |
| API 21 (Android 5.0) | ~99.8%, compat tax | |

**User's choice:** API 24

### Q2: Android targetSdk

| Option | Description | Selected |
|--------|-------------|----------|
| API 34 (Android 14) | Play Store required | ✓ |
| API 35 (Android 15) | Edge-to-edge migration | |

**User's choice:** API 34

### Q3: iOS deployment target

| Option | Description | Selected |
|--------|-------------|----------|
| iOS 15.0 | ~96% coverage, Flutter default | |
| iOS 16.0 | ~92% coverage | |
| iOS 17.0 | ~80% coverage, not recommended | ✓ |

**User's choice:** iOS 17.0
**Notes:** User picked despite the explicit "not recommended" annotation citing ~20% buyer loss. Treat as a deliberate informed choice; do not re-propose lowering it in later phases without explicit user direction. Documented as D-26 in CONTEXT.md.

---

## Claude's Discretion

Areas where the user said "you decide" or where the planner has flexibility within the captured constraints:

- Concrete hex values for sepia / dark / OLED themes (constrained by D-19)
- Exact accent color pick from D-18 candidates (matcha-800 vs blueberry-800 vs a third neutral)
- Placeholder sample-paragraph text for the Reader placeholder
- Theme picker widget structure (ListTile+Radio vs SegmentedButton vs custom Card)
- `crashes.log` flush strategy (per-write default unless profiling says otherwise)
- Library empty-state illustration approach (SVG vs Icon vs simple shape)

## Deferred Ideas

See `01-CONTEXT.md` `<deferred>` section for the full list. Highlights:

- Apple Developer Program enrollment → Phase 4
- Real crash log viewer + share → Phase 6 (SET-04)
- Full FND-09 (signed IPA on every push) → restored in Phase 4
- Upload keystore for release signing → Phase 7 (QAL-05)
- Drift Books + Chapters tables → Phase 2
- Atkinson Hyperlegible / Inter as additional reader fonts → v2 if surfaced by store feedback
- Clay swatch accents and playful hover animations → intentionally not adopted
