# k8-study

Mobile-friendly, interactive Kubernetes study guide — built to be better than the
ad-spammy tutorial apps out there. Study notes, flashcards, quizzes, and
CKA-domain-mapped practice tests. Starts as an installable PWA; goes native only
when the web version earns it.

## Stack (locked unless a blocker surfaces)

- **Flutter**, `flutter build web` → PWA. One codebase; native iOS/Android later.
- No backend. No accounts. Progress persisted locally.
- Ads behind an `AdsService` interface: AdSense placeholders on web now,
  AdMob on native later. Test IDs only in dev; real unit IDs via env, never committed.

## Content

Study notes are hand-written from the official Kubernetes documentation
(https://kubernetes.io/docs/), which is licensed
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) — attribution kept in
the app's About page and below. Every note links back to its source page; no
invented API fields or flags.

Curriculum is mapped to CKA exam domains.

## Workflow

Spec-driven: `spec/SPEC.md` first (reviewed before app code), then plan, then
implement. Done-criteria live in the spec.

## Attribution

Kubernetes documentation © The Kubernetes Authors, used under CC BY 4.0.
This project is not affiliated with the CNCF or The Linux Foundation.
