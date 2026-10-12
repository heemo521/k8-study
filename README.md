# k8-study

Mobile-friendly, interactive Kubernetes study guide, built to be better than the
ad-spammy tutorial apps out there. It has 33 topics covering all five CKA domains
(432 flashcards, 473 questions including 22 typed `kubectl` commands, 11 animated diagrams), quizzes, CKA-domain practice tests, and progress
tracking: it shows where you are and which competencies are your weakest.
The content model is multi-subject: a **Docker** subject (4 topics, from the
Apache-2.0 Docker docs) ships alongside Kubernetes, and others such as Linux can be
added as data with `python3 tool/new_subject.py`. It ships as an installable PWA and goes native only
when the web version earns it.

Highlights:

- **Animated diagrams** in the notes: step-through walkthroughs of the
  architecture, Deployments, Services, Ingress, storage, RBAC and more.
- **Read-aloud**: notes are read to you section by section, with an on-device
  voice so it works offline.
- **Mock exam → gap plan**: a CKA-weighted mock exam shows which competencies
  are under 80% and builds a plan for each one (re-read the notes, review the
  flashcards, pass a targeted quiz), plus a re-test of what's still open.
- **Learning-science study loop** ([`docs/LEARNING.md`](docs/LEARNING.md)):
  typed `kubectl` answers, guided labs whose help fades with each run,
  Sure / Not sure ratings, spaced review of wrong or unsure answers, a mixed
  daily review, a warm-up before the notes, and "why?" prompts.
- **Works offline** once loaded, and installs as an app.

Try it: <https://heemo521.github.io/k8-study/> (deployed from `main` by
`.github/workflows/pages.yml` once GitHub Pages is set to "GitHub Actions").

The learning-science basis and feature roadmap are in
[`docs/LEARNING.md`](docs/LEARNING.md).

The full specification is in [`spec/SPEC.md`](spec/SPEC.md). Screens, data model,
engine rules, ad placement and done-criteria are all defined there.

## Stack (locked unless a blocker surfaces)

- **Flutter 3.47.7** (stable), `flutter build web` → PWA. One codebase; native iOS/Android later.
  As of 3.47, Material widgets come from the standalone `material_ui` package.
- No backend. No accounts. Progress persists locally (`shared_preferences` → `localStorage`).
- Ads go through an `AdsService` interface. Web shows AdSense-sized placeholders now, and AdMob comes
  later on native. The ads flag is off by default. Real unit IDs come only via
  `--dart-define`, never committed.

## Run it

```sh
flutter pub get
flutter run -d chrome                         # dev
flutter run -d chrome --dart-define=ADS_ENABLED=true   # with ad placeholders
```

## Build the PWA

```sh
flutter build web --release --no-web-resources-cdn   # CanvasKit bundled → works offline
dart run tool/gen_precache.dart                      # fills build/web/sw.js precache list
```

Serve `build/web` from any static host. Routes use hash URLs (`/#/topic/kubeadm`),
so no rewrite rules are needed. If the app lives under a sub-path, add
`--base-href /sub/path/`.

## Checks

```sh
flutter analyze
flutter test                     # engines, content invariants, ads boundary, widget loop at 390×844

# Headless Chromium: installability, service worker, offline reload, no horizontal
# scroll at 390/360px, and the full study → flashcards → quiz loop with screenshots.
python3 -m http.server 8080 --directory build/web &
(cd tool/pwa_check && npm ci && npm run check)
```

CI (`.github/workflows/ci.yml`) runs all of the above on every PR.

## Layout

```
lib/
  content/     models (strict JSON parsing), loader, inline markup
  engine/      flashcards (Leitner), quiz, practice — pure Dart
  progress/    local persistence + insights (next action, readiness, gaps)
  ads/         AdsService interface, frequency cap, impl/ (noop, placeholder, admob stub)
  screens/     S1–S11 from the spec
  widgets/     note blocks, question view, source links …
assets/content/  catalog.json + subjects/<id>/ (subject.json, topics/, practice_tests.json)
tool/            gen_precache.dart, pwa_check/, source_report.py, make_icons.py
docs/            ADDING_CONTENT.md, SOURCES.md (source-check list), screenshots/
```

## Content

New topics or subjects: see [`docs/ADDING_CONTENT.md`](docs/ADDING_CONTENT.md),
and validate with `python3 tool/validate_content.py`.

Study notes are hand-written from the official Kubernetes documentation
(https://kubernetes.io/docs/), which is licensed
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Attribution appears in the
app's About page and below. Every note section, flashcard and question links back to
its source page, and `flutter test` enforces that. There are no invented API fields or flags.
[`docs/SOURCES.md`](docs/SOURCES.md) maps every item to its source page and
section. Regenerate it with `python3 tool/source_report.py`.

Other sources:
- minikube notes also draw on the [minikube docs](https://minikube.sigs.k8s.io/docs/)
  (© The Kubernetes Authors).
- The Managed Kubernetes topic states basic facts about EKS/GKE/AKS and links to
  each vendor's own documentation.

The curriculum is mapped to the CKA exam domains
([curriculum page](https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/),
checked 2026-10-11; exam based on Kubernetes v1.35). The real CKA is hands-on. The
quizzes here are knowledge checks, and the app never claims a passing score.

## Workflow

Spec-driven: `spec/SPEC.md` first (reviewed before app code), then plan, then
implement. Done-criteria live in the spec.

## Attribution

Kubernetes documentation © The Kubernetes Authors, used under CC BY 4.0.
Content has been summarized, reorganized, and rewritten.
Kubernetes® is a registered trademark of The Linux Foundation.
This project is not affiliated with the CNCF or The Linux Foundation.
The app icon is original artwork, not the Kubernetes logo.
