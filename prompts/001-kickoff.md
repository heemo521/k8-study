## Context
Greenfield repo `heemo521/k8-study` — just initialized, contains only README.md
and .gitignore, no code yet.
Goal: "K8 Study", a mobile-friendly interactive Kubernetes study-guide PWA that
beats ad-spammy tutorial apps (reference: Srinisbook screenshots — long static
note pages, banner-ad spam, no interactivity). Ours: concise study notes,
flashcards, per-topic quizzes, and CKA-domain-mapped practice tests, with ad
slots for revenue.
Stack (locked unless you surface a blocker): Flutter, web/PWA build first.
Native iOS/Android only when the web version earns it (standing rule). No
backend, no accounts, progress in local storage. Ads abstracted behind an
`AdsService` interface: AdSense placeholders on web now, AdMob on native later
— no ad SDK calls in screen code, no real ad unit IDs committed (test IDs /
env only).
Content: hand-written study notes derived from https://kubernetes.io/docs/
(CC BY 4.0 — verify the license footer yourself; keep attribution in README
and an in-app About page; every note links its source page). Curriculum mapped
to CKA exam domains (https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/).
v1 topics: what-is-k8s, architecture, namespaces, minikube, managed offerings
(EKS/GKE/AKS), kubeadm cluster setup.
Workflow: spec-driven. Write `spec/SPEC.md` first — screens, content data
model, quiz/flashcard engine behavior, ad-slot placement, done-criteria — and
STOP for my review before writing any app code.

## Pointers
- Repo: https://github.com/heemo521/k8-study (clone it; `main` branch).
- Content source: https://kubernetes.io/docs/ (read as a human; hand-write notes, no scraping).
- CKA curriculum: https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/
- Ad slots: banner on study screens, interstitial after quiz completion — both behind a feature flag.

## Review criteria
1. Spec first: does `spec/SPEC.md` define every screen, the content data model,
   quiz/flashcard engine behavior, and ad-slot placement before any app code exists?
2. PWA correctness: installable manifest, offline content for completed modules,
   mobile-first layout — verified at phone width (390px).
3. Content honesty: every study note traceable to a kubernetes.io URL; no
   invented API fields, flags, or defaults; attribution present in-app.
4. Quiz engine: question bank per topic, shuffled options, per-answer
   explanations, score + retry, progress persisted locally.
5. Ads abstraction: screens call `AdsService` only; web build renders AdSense
   placeholders; no real ad unit IDs in the repo.
6. Done-criteria: `flutter build web` green, PWA installable, one full
   study → flashcards → quiz loop working end to end on a phone viewport.

## Deliverable
- `spec/SPEC.md` for my review (stop here for approval).
- After approval: Flutter PWA implementing the spec — topic browser, study-note
  screens, flashcards, quizzes, practice-test mode, progress tracking, ad slots
  behind the flag.
- What NOT to do: no native builds, no backend, no user accounts, no scraping
  kubernetes.io beyond reading docs as a human would, no real ad unit IDs, no
  publishing to any store, no copying content from tutorial apps.
