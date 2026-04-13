# Phase 4: TTS Engine & Playback Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-12
**Phase:** 04-tts-engine-playback-foundation
**Areas discussed:** Model Download UX, Voice Picker & Previews, Isolate Architecture + 300ms Latency, Playback Surface & Session

---

## Model Download UX

### Prompt trigger
| Option | Description | Selected |
|--------|-------------|----------|
| First-launch onboarding | Modal after empty library, 'you need this to hear books read aloud' framing | ✓ |
| First tap on 'Play' | Lazy — prompt only when user tries to play | |
| Library entry + Settings | Passive banner + Settings entry, no modal | |

### Wi-Fi gate
| Option | Description | Selected |
|--------|-------------|----------|
| connectivity_plus hard gate | Detect connection type; block cellular if toggle=ON | |
| Honor-system / info only | 'Prefer Wi-Fi' label; no actual enforcement | ✓ |
| Hard gate + explicit override | Gate with two-tap override on cellular | |

**Notes:** Claude flagged that honor-system diverges from TTS-01 wording ('Wi-Fi only'). User confirmed to keep honor-system and rename label to 'Prefer Wi-Fi'. Planning will update REQUIREMENTS.md wording.

### Progress UI
| Option | Description | Selected |
|--------|-------------|----------|
| Full-screen modal with progress | Blocking modal with percent + MB total | ✓ |
| Non-blocking banner + background isolate | Browse while downloading | |
| Inline card on Library screen | Middle-ground | |

### Hosting
| Option | Description | Selected |
|--------|-------------|----------|
| GitHub Releases on murmur repo | Self-mirror with pinned SHA-256 | |
| Direct from k2-fsa GitHub releases | Upstream + SHA-256 pin | ✓ |
| Hugging Face mirror | Different layout, not primary | |

---

## Voice Picker & Previews

### Voice set
| Option | Description | Selected |
|--------|-------------|----------|
| All 11 — skip curation | Ship every v0_19 voice | ✓ |
| Hand-curate 8–10 | Drop weakest in listening session | |
| 3–4 defaults + 'more voices' | Tiered picker | |

### Previews
| Option | Description | Selected |
|--------|-------------|----------|
| Live-synth on first tap, cache | First tap ~300–800ms, subsequent instant | ✓ |
| Bundle pre-rendered clips | +~1–2MB bundle, instant previews | |
| Live-synth every time, no cache | ~500ms every tap | |

### Preview text
| Option | Description | Selected |
|--------|-------------|----------|
| Fixed branded sentence | Same sentence for all voices | ✓ |
| Excerpt from current book | Different text per preview | |
| Random from small pool | Rotating 3–4 samples | |

### Picker location
| Option | Description | Selected |
|--------|-------------|----------|
| Settings + per-book sheet on playback bar | Global + per-book override (PBK-04) | ✓ |
| Settings only, per-book in book-details | Less discoverable override | |
| Playback bar sheet only, no Settings | Last-used becomes default | |

---

## Isolate Architecture + 300ms Latency

### Isolate lifecycle
| Option | Description | Selected |
|--------|-------------|----------|
| Spawn on reader open, tear down on close | Warm while in reader, released otherwise | ✓ |
| Spawn at app start, keep for session | Always warm, always paying RAM | |
| Spawn on first play, keep until OS kills | Laziest; cold-start risk | |

### Warming
| Option | Description | Selected |
|--------|-------------|----------|
| Pre-synth sentence 0 on chapter load | Audio ready before play tap | ✓ |
| Warm isolate only, rely on cold synth speed | No headroom on 300ms budget | |
| Both (warm + pre-synth) | Belt-and-suspenders, wastes CPU | |

### Skip mid-synth
| Option | Description | Selected |
|--------|-------------|----------|
| Cancel in-flight, synth new target | Responsive, needs Sherpa cancel API | ✓ |
| Let current finish, discard, synth new | Simpler, laggy skip | |
| Queue + interrupt playback | Mixed semantics | |

**Notes:** Flagged as highest risk — Phase 4 must spike on sherpa_onnx cancel API before committing.

### Isolate proto
| Option | Description | Selected |
|--------|-------------|----------|
| SendPort + sealed-class messages | Typed, pattern-matched | ✓ |
| SendPort + Map<String, dynamic> | Stringly-typed, simpler | |
| compute() one-shot per synth | Rejected — violates TTS-05 | |

---

## Playback Surface & Session

### Bar mode
| Option | Description | Selected |
|--------|-------------|----------|
| Persistent mini-bar docked bottom | Always visible in reader | ✓ |
| On-demand: appears on play, hides idle | Max reading surface | |
| Persistent when playing, hidden before first play | FAB pre-play | |

### Immersive behavior
| Option | Description | Selected |
|--------|-------------|----------|
| Bar toggles with chrome | Single-concept 'chrome' | ✓ |
| Bar stays always | Treated as structural | |
| Bar hides only when paused | Nuanced | |

### Lockscreen controls
| Option | Description | Selected |
|--------|-------------|----------|
| Spartan: play/pause + next-chapter | Matches PBK-10 verbatim | ✓ |
| Add skip-sentence ± | More power-user | |
| Add prev-chapter | Symmetric chapter nav | |

### Audio session
| Option | Description | Selected |
|--------|-------------|----------|
| Pause on interruption + auto-resume + unplug pauses | 'speech' category, no ducking | ✓ |
| Same but require user tap to resume | More conservative | |
| Duck with other media | Rejected — TTS under music unintelligible | |

---

## Claude's Discretion

- Per-book voice/speed storage: add `voice_id`, `playback_speed` columns to existing `books` Drift table (CD-01)
- Ring buffer on-disk location + eviction policy (CD-02)
- WAV-wrap helper implementation (CD-03)
- `playbackStateProvider` shape (CD-04)

## Deferred Ideas

- Sleep timer (PBK-11, Phase 6)
- Highlighting + auto-scroll (PBK-05/06/07, Phase 5)
- Non-English voices (TTS-11, future)
- Advanced voices submenu (TTS-12, future)
- Sub-sentence streaming (TTS-13, Phase 7 optimization)
- Self-hosted model mirror (considered, dropped)
- Voice curation down to featured few (dropped, revisit post-launch)
