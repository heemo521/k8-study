# K8 Study — Specification (v1)

Status: **APPROVED 2026-10-11** (decisions in §12).

## 1. Product summary

K8 Study is a mobile-first, installable PWA for learning Kubernetes and
preparing for the CKA exam. It replaces long, ad-cluttered static note pages
with short notes you can actually read on a phone, flashcards with spaced
repetition, per-topic quizzes that explain every answer, and practice tests
mapped to CKA exam domains.

| Constraint | Decision |
|---|---|
| Stack | Flutter (stable channel), `flutter build web`, PWA |
| Native builds | Android and iOS from the same code, for the app stores (docs/PUBLISHING.md) |
| Backend / accounts | None. All progress lives in browser local storage |
| Ads | Behind `AdsService`; web renders placeholders, native uses AdMob; flag-gated, off by default |
| Content | Hand-written from kubernetes.io/docs (CC BY 4.0), every note links its source |

### 1.1 Non-goals (v1)

- Backend, sync, accounts, analytics, leaderboards.
- A live cluster / terminal simulator (the real CKA is hands-on; see §7.4).
- Real ad unit IDs in the repo, and real ad network calls on the web.
- Scraping kubernetes.io or copying text from it or from any tutorial app.

## 2. Verified facts this spec relies on

Checked 2026-10-11 by reading the pages directly.

| Fact | Source |
|---|---|
| kubernetes.io footer: "© 2026 The Kubernetes Authors \| Documentation Distributed under CC BY 4.0" (license link → `git.k8s.io/website/LICENSE`) | https://kubernetes.io/docs/home/ |
| Kubernetes trademark/policies: "Copyright © Kubernetes a Series of LF Projects, LLC … see https://lfprojects.org/policies/" | same footer |
| Latest docs version shown: v1.37 | same page |
| CKA is based on Kubernetes **v1.35**, 2-hour exam; the page does **not** state a passing score | CKA page (link below) |
| CKA domains and weights (table in §4.1) | https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/ |
| minikube docs footer: "© 2026 The Kubernetes Authors" | https://minikube.sigs.k8s.io/docs/start/ |
| kubernetes.io names managed options only generically (managed control plane, managed worker nodes, serverless) and links to Turnkey Cloud Solutions / Partners; it does not name EKS/GKE/AKS in that text | https://kubernetes.io/docs/setup/production-environment/ |

Consequences:

- The app never states a CKA passing score (§7.4).
- Content is reviewed against current docs, and each topic records the date
  it was checked (§5.2).
- The managed-offerings topic needs a sourcing decision (§12.1).

## 3. Information architecture & screens

Bottom navigation, 4 tabs: **Learn · Practice · Progress · About**.
Routing: `go_router`, hash URL strategy (`/#/topic/architecture`) so the
build works on any static host without rewrite rules. Every screen has a
deep-linkable route.

| # | Screen | Route | Purpose |
|---|---|---|---|
| S1 | Topic Browser (Learn tab) | `/` | Topics grouped by CKA domain |
| S2 | Topic Detail | `/topic/:topicId` | Hub for one topic: Notes, Flashcards, Quiz |
| S3 | Study Notes | `/topic/:topicId/notes` | Read the note sections |
| S4 | Flashcards | `/topic/:topicId/cards` | Spaced-repetition review |
| S5 | Topic Quiz | `/topic/:topicId/quiz` | 10-question quiz with instant feedback |
| S6 | Quiz Results / Review | `/topic/:topicId/quiz/result` | Score, review, retry |
| S7 | Practice Hub (Practice tab) | `/practice` | Pick a practice test; past results |
| S8 | Practice Test Run | `/practice/:testId/run` | Timed, deferred-feedback test |
| S9 | Practice Results | `/practice/:testId/result` | Score, per-domain breakdown, review |
| S10 | Progress (Progress tab) | `/progress` | Overall + per-topic progress; reset |
| S11 | About & Attribution (About tab) | `/about` | License, attribution, disclaimers, version |

### S1 Topic Browser

- Header: app name and an overall progress bar ("3 of 6 topics complete").
- Sections, in this order:
  1. **Foundations** (not an exam domain; prerequisites).
  2. The five CKA domains in exam-weight order, each showing its weight (e.g. "Troubleshooting · 30%").
- Each domain section lists its topics as cards: title, one-line summary,
  estimated minutes, and a status chip (Not started / In progress / Complete)
  with a small progress ring.
- A domain with no v1 topics shows a muted "Coming later" row, so coverage is
  visible and honest.
- Tap a topic card → S2.
- Ad: banner slot at the bottom of the list (§9).

### S2 Topic Detail

- Title, summary, CKA domain chip(s), the competencies it maps to (verbatim
  competency text from the CKA page), estimated minutes.
- Three action tiles in loop order, each showing its status:
  1. **Study notes**: "4 of 6 sections read".
  2. **Flashcards**: "8 due · 12 total".
  3. **Quiz**: "Best 80% · 2 attempts", or "Not taken".
- Primary button = the next incomplete step (Notes → Flashcards → Quiz).
- "Sources" expander: a de-duplicated list of every source URL used by this topic.
- No ad on this screen.

### S3 Study Notes

- One scrolling page, with sections rendered in order. Each section has:
  - a heading;
  - typed content blocks (§5.3): paragraph, bullet list, code (monospace,
    horizontal scroll, copy button), key-point callout, and a table (max 3 columns);
  - a **"Source: <page title> ↗"** link at the foot of the section (opens kubernetes.io in a new tab).
- A section is marked as read when its foot scrolls into view, or when the user
  taps "Mark read". Read state is persisted.
- Sticky top bar: topic title + section progress (e.g. "3/6").
- End of page: "Next: Flashcards →".
- Target length: ≤ 1,500 words per topic. Short sections, no walls of text.
- Ad: one banner slot between section 2 and section 3, and none if the
  topic has fewer than 3 sections. Never more than one banner on screen (§9).

### S4 Flashcards

- One card at a time. Tap or press Space to flip (front = prompt, back =
  answer plus a source link).
- After the flip, two buttons: **Again** and **Got it**. Keyboard shortcuts: 1 and 2.
- A progress strip shows cards remaining in this session.
- At session end: summary ("10 reviewed · 7 got it"), plus "Review again" and
  "Next: Quiz →".
- When nothing is due: "All caught up — next review in N days", with a
  "Practice anyway" button that runs every card in the topic without changing the schedule.
- Engine: §7.1. No ads.

### S5 Topic Quiz

- One question per screen: stem, options (shuffled, §7.2), Submit button.
- Question types: single choice (radio), multiple choice (checkbox, stem
  says "Select N"), true/false.
- After Submit: options lock. The correct option(s) turn green and a wrong
  pick turns red. **Every option shows its own explanation**, plus a source link for the question.
- "Next" advances. A header shows "Q 3/10" and the running score.
- Leaving mid-quiz asks for confirmation. An unfinished attempt is discarded,
  not saved (v1).
- No ads during the quiz.

### S6 Quiz Results / Review

- Score shown as a percentage and as N/10, pass/fail against the **app's**
  80% topic mastery threshold (labelled "Topic mastered", not an exam claim),
  and the best score so far.
- Review list: each question collapsed, with a ✓/✗ marker. Expanding shows
  your answer, the correct answer, and the explanations.
- Buttons: **Retry all** (new draw and shuffle), **Retry missed** (only the
  wrong questions, reshuffled; does not count toward best score), and **Back to topic**.
- Ad: an interstitial **may** show when this screen is reached, before it
  renders, if the flag and frequency cap allow (§9).

### S7 Practice Hub

- Explainer card: "The real CKA is a hands-on, performance-based exam. These
  multiple-choice tests check your knowledge of the concepts; they are not a
  simulation of the exam."
- Test list (§7.3): "Mixed — all topics" and one test per CKA domain that
  has questions. Each row shows the question count, time limit, and best score.
- Coverage note listing the domains that have no questions yet.
- Ad: banner slot at the bottom.

### S8 Practice Test Run

- Same question widget as S5, but with **deferred feedback**: no correctness
  shown until the test ends.
- Countdown timer in the header (optional; it can be turned off on the setup sheet).
- Flag-for-review toggle on each question. A question grid lets you jump to
  any question (answered / flagged / blank states).
- "Finish" button asks for confirmation if any question is unanswered.
  When the timer expires, the test auto-finishes.
- No ads during the test.

### S9 Practice Results

- Overall score, time used, and a per-domain breakdown (bars). Per-topic
  weak spots link to that topic's notes.
- Full review, same as S6.
- Buttons: Retake (new draw) and Back to Practice.
- Ad: interstitial eligibility same as S6.

### S10 Progress

- Totals: topics complete, cards mastered (box ≥ 4), and quizzes passed.
- Per-topic rows: notes %, cards due, best quiz score, last activity date.
- Practice history: last 10 results.
- **Reset progress** (destructive, confirmation dialog). This clears all
  local data except settings.
- Export/import progress as a JSON file is deferred to v1.1.

### S11 About & Attribution

- What the app is; "Not affiliated with the CNCF, The Linux Foundation, or the Kubernetes project."
- **Attribution block** (verbatim intent):
  "Study notes are original summaries adapted from the Kubernetes
  Documentation, © The Kubernetes Authors, licensed under CC BY 4.0
  (link). Changes: content has been summarized, reorganized, and rewritten. Each note links to its source page."
  Plus the minikube attribution, if it is used as a source.
- Trademark line: "Kubernetes® is a registered trademark of The Linux
  Foundation" (link to https://lfprojects.org/policies/ and https://www.linuxfoundation.org/legal/trademark-usage).
- CKA disclaimer: the curriculum mapping follows the public CKA curriculum
  page (link), and the app is not endorsed by the Linux Foundation.
- Content review date and app version/build.
- Ads disclosure: shown only when ads are enabled.
- No ads.

### 3.1 Layout rules (mobile-first)

- Design viewport: **390 × 844**. Must be usable down to 360px wide.
- Content is centred with a max width of 640px; wider screens only add margins.
- Tap targets ≥ 48 × 48 dp. Body text 16sp. Respects system text scale up to 200% with no clipped text.
- No horizontal page scroll at 360px or wider. Only code blocks and tables scroll horizontally, inside their own box.
- Light and dark themes follow the system setting.
- Keyboard and screen-reader basics: semantic labels on icon buttons, logical focus order.

## 4. Curriculum

### 4.1 CKA domains (from the CKA page, 2026-10-11)

| id | Domain | Weight |
|---|---|---|
| `troubleshooting` | Troubleshooting | 30% |
| `cluster-arch` | Cluster Architecture, Installation & Configuration | 25% |
| `services-networking` | Services & Networking | 20% |
| `workloads-scheduling` | Workloads & Scheduling | 15% |
| `storage` | Storage | 10% |
| `foundations` | Foundations (app-only, not an exam domain) | — |

Competency strings are stored verbatim in `domains.json`, so topics can cite them.

### 4.2 v1 topics

| topicId | Title | Domain(s) → competency | Primary sources |
|---|---|---|---|
| `what-is-k8s` | What is Kubernetes? | foundations | /docs/concepts/overview/ |
| `architecture` | Cluster Architecture | cluster-arch; troubleshooting → "Troubleshoot cluster components" (concept level only) | /docs/concepts/architecture/, /docs/concepts/overview/components/, /docs/concepts/architecture/nodes/, /docs/concepts/architecture/control-plane-node-communication/ |
| `namespaces` | Namespaces | foundations (cross-cutting; used in every domain) | /docs/concepts/overview/working-with-objects/namespaces/, /docs/tasks/administer-cluster/namespaces/ |
| `minikube` | Local Clusters with minikube | foundations | /docs/tutorials/hello-minikube/, /docs/setup/learning-environment/, /docs/tasks/tools/, minikube.sigs.k8s.io/docs/start/ |
| `managed-k8s` | Managed Kubernetes (EKS / GKE / AKS) | cluster-arch → "Prepare underlying infrastructure for installing a Kubernetes cluster" | /docs/setup/production-environment/, /docs/setup/production-environment/turnkey-solutions/; vendor overview pages (§12.1) |
| `kubeadm` | Cluster Setup with kubeadm | cluster-arch → "Prepare underlying infrastructure…", "Create and manage Kubernetes clusters using kubeadm" | /docs/setup/production-environment/tools/kubeadm/install-kubeadm/, …/create-cluster-kubeadm/, /docs/setup/production-environment/container-runtimes/, /docs/reference/networking/ports-and-protocols/ |

All `/docs/...` paths are on `https://kubernetes.io`. All of them were confirmed
to return HTTP 200 on 2026-10-11.

v1 content volume per topic: 4–8 note sections, 10–15 flashcards, and a bank of 12–15
quiz questions (10 drawn per attempt). Total ≈ 80 questions.

Honest coverage: in v1, only `cluster-arch` has domain-mapped questions, plus a
small amount of `troubleshooting`. S1 and S7 show the other domains as "Coming later".

## 5. Content data model

Content ships as JSON assets bundled into the build (`assets/content/`). There
is no runtime fetch from kubernetes.io. The content is hand-authored in the repo.

```
assets/content/
  manifest.json          # contentVersion, reviewedAt, list of topic files
  domains.json           # CKA domains + verbatim competencies
  topics/<topicId>.json  # one file per topic: notes + flashcards + questions
  practice_tests.json    # practice test definitions
```

### 5.1 Schemas (Dart models mirror these; `fromJson` is strict)

```jsonc
// domains.json
{ "domains": [ {
    "id": "cluster-arch",                 // slug
    "title": "Cluster Architecture, Installation & Configuration",
    "weightPercent": 25,                  // null for foundations
    "isExamDomain": true,
    "competencies": [ { "id": "kubeadm-create", "text": "Create and manage Kubernetes clusters using kubeadm" } ]
} ],
  "source": "https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/",
  "examK8sVersion": "1.35",
  "checkedAt": "2026-10-11" }
```

```jsonc
// topics/<topicId>.json
{
  "id": "kubeadm",
  "title": "Cluster Setup with kubeadm",
  "summary": "One sentence.",
  "order": 6,                              // display order within its domain
  "domainIds": ["cluster-arch"],           // first = primary (grouping on S1)
  "competencyIds": ["infra-prep", "kubeadm-create"],
  "estMinutes": 12,
  "reviewedAt": "2026-10-xx",              // date notes were checked against sources
  "sections": [ {
      "id": "kubeadm-init",
      "heading": "Initialising the control plane",
      "sourceUrl": "https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/",
      "sourceTitle": "Creating a cluster with kubeadm",
      "blocks": [ /* §5.3 */ ]
  } ],
  "flashcards": [ {
      "id": "kubeadm-fc-01",
      "front": "Which command bootstraps the first control-plane node?",
      "back": "`kubeadm init`",
      "sourceUrl": "https://kubernetes.io/docs/…"
  } ],
  "questions": [ {
      "id": "kubeadm-q-01",
      "type": "single",                    // single | multi | truefalse
      "stem": "…",
      "options": [
        { "id": "a", "text": "…", "correct": true,  "explanation": "Why this is right." },
        { "id": "b", "text": "…", "correct": false, "explanation": "Why this is wrong." }
      ],
      "competencyId": "kubeadm-create",    // optional; drives practice-test domain breakdown
      "sourceUrl": "https://kubernetes.io/docs/…",
      "difficulty": 1                      // 1 easy · 2 medium · 3 hard
  } ]
}
```

```jsonc
// practice_tests.json
{ "tests": [ {
    "id": "mixed",
    "title": "Mixed — all topics",
    "description": "Questions from every topic, foundations included.",
    "questionCount": 25,
    "timeLimitMinutes": 35,
    "filter": { "domainIds": null },       // null = every question in the bank
    "weighting": "uniform"                 // "uniform", or "domain" = by CKA weight among domains that have questions
} ] }
```

### 5.2 Content invariants (enforced by `test/content_test.dart`)

1. All ids are unique: topic ids globally; section, card, and question ids
   globally (they are prefixed with the topic id).
2. Every section, flashcard, and question has a `sourceUrl` on the allowlist:
   - `https://kubernetes.io/docs/...`;
   - `https://minikube.sigs.k8s.io/docs/...`;
   - the vendor documentation hosts in §12.1, only for the `managed-k8s` topic.
3. `single`/`truefalse`: exactly 1 correct. `multi`: 2 or more correct, and
   the stem contains "Select N", where N is the correct count. `truefalse`
   has exactly the options "True" and "False".
4. 3–5 options for `single`/`multi`. Every option has a non-empty `explanation`.
5. Every `domainIds`/`competencyId` resolves in `domains.json`.
6. Every topic has ≥ 10 flashcards and ≥ 12 questions, and every section has ≥ 1 block.
7. Every practice test can be filled: enough matching questions for `questionCount`.
8. The `manifest.json` topic list matches the files on disk.

### 5.3 Note content blocks

Notes use structured blocks, not Markdown. This means no Markdown dependency,
predictable mobile rendering, and length kept in check.

```jsonc
{ "type": "p",       "text": "Inline `code` spans and **bold** only." }
{ "type": "bullets", "items": ["…", "…"] }
{ "type": "code",    "lang": "shell", "text": "kubeadm init --pod-network-cidr=<cidr>" }
{ "type": "callout", "kind": "key" | "exam" | "warn", "text": "…" }
{ "type": "table",   "header": ["Component", "Runs on", "Job"], "rows": [["…","…","…"]] }
```

Inline markup is limited to `` `code` `` and `**bold**`, parsed by a small
tested parser. Anything else renders literally.

### 5.4 Content honesty rules (authoring)

- Notes are written from reading the source page. No sentences are pasted
  from kubernetes.io or from any tutorial app.
- Every command, flag, field name, port, or default in a note, card, or
  question must appear on that item's `sourceUrl` page. If it can't be found
  there, it is left out.
- Values that change between versions are avoided, or phrased as "see the
  source page for current values".
- Placeholders in commands use `<angle-brackets>`, never invented example values that look real
  (Exception: `command` question stems may name scenario objects, see
  §15.5.)
- The PR that adds content includes a review checklist: one line per item,
  in the form `id → URL → where on the page`.

## 6. Local persistence

- Package: `shared_preferences` (backed by `window.localStorage` on web).
  One key per concern, with JSON values. A `schemaVersion` is stored for
  migrations, and an unknown or older schema falls through a migration function.

| Key | Value |
|---|---|
| `k8s.schema` | `1` |
| `k8s.notes` | `{ topicId: [readSectionIds] }` |
| `k8s.cards` | `{ cardId: { box: 1-5, dueAt: ISO date, lastReviewedAt } }` |
| `k8s.quiz` | `{ topicId: { attempts, bestPct, lastPct, lastAt, missed: [questionIds] } }` |
| `k8s.practice` | `[ { testId, pct, perDomain: {domainId: {correct,total}}, durationSec, at } ]` (max 50, oldest dropped) |
| `k8s.ads` | `{ quizzesSinceInterstitial, lastInterstitialAt }` |
| `k8s.settings` | `{ practiceTimerOn }` |
| `k8s.rewards` | `{ xp, streak, day: last study date, best }` (XP, daily streak; see §14) |
| `k8s.labs` | `{ labId: completed runs }` (guided-lab fading; see §15.8) |

- Content-version changes: entries for ids that no longer exist are ignored, not crashed on.
- Topic **complete** = all sections read **and** quiz best score ≥ 80%.
  Flashcards are encouraged but do not block completion.
- Corrupt JSON in a key → that key is reset to its default and a debug log
  is written. The app must never fail to start because of stored data.

## 7. Engines

All engine code is pure Dart, with no Flutter imports. It takes injected
`Random` and `Clock`, so it is deterministic in unit tests.

### 7.1 Flashcards (Leitner, 5 boxes)

- A new card starts in box 1 and is due immediately.
- Intervals by box after "Got it": 1 → box 2 (due +1 day), 2 → 3 (+3 d),
  3 → 4 (+7 d), 4 → 5 (+14 d), 5 → stays at 5 (+30 d).
- "Again": the card goes to box 1 and is re-queued at the end of the current
  session, at most once more per session.
- Session = due cards (oldest due first) then new cards. The session is capped
  at 20 cards, and the order within each group is shuffled.
- "Mastered" = box ≥ 4.
- "Practice anyway" mode doesn't change box or due dates.
- Due is compared by local calendar date, not to the exact millisecond.

### 7.2 Topic quiz

- Draw: 10 questions, sampled without replacement from the topic bank. Where
  possible, questions missed in the previous attempt are prioritised; the rest
  are filled at random.
- **Option shuffle**: the options of every question are shuffled for each
  attempt (Fisher–Yates). Exception: `truefalse` always shows True then False.
  Option ids are stable, so grading never depends on display position.
- Grading: `single`/`truefalse` is correct when the selected id is the correct
  id. `multi` is correct only on an exact set match (no partial credit, matching how the app scores).
- Score = correct / asked, shown as a rounded percentage.
- Persisted on finish only: `attempts++`, `lastPct`, and `bestPct = max`.
  "Retry missed" runs are **not** persisted to best score; they only update
  the missed-question set used for prioritisation.

### 7.3 Practice tests

- Pool = questions whose topic `domainIds` match the test's `filter`.
- `weighting: "domain"`: the target count for each domain is proportional to
  the CKA weights, normalised over the domains that have questions in the pool.
  Rounding uses the largest-remainder method. If a domain runs short, the rest
  is filled from the other domains.
- Same option shuffle and grading as §7.2. Feedback is deferred until the
  test finishes.
- Timer: wall-clock based (it survives tab throttling). When it expires, the
  test auto-submits. A result is persisted only when the test is finished.
- The per-domain breakdown uses each question's topic's primary domain.

### 7.4 Exam honesty

- There is no "CKA pass/fail" anywhere. The 80% figure is labelled as the app's mastery threshold.
- Practice-test copy states that the real exam is hands-on (§S7).

## 8. PWA

- `web/manifest.json`: `name` "K8 Study", `short_name` "K8 Study",
  `start_url` "./", `scope` "./", `display` "standalone", `theme_color`,
  `background_color`, and icons at 192, 512, and 512-maskable. The app icon
  is original artwork, not the Kubernetes logo, to respect the trademark.
- **Service worker:** Flutter 3.47 still emits the generated
  `flutter_service_worker.js` but has deprecated it (`--pwa-strategy` is
  gone). The app therefore ships its own `web/sw.js`, plus a
  `web/flutter_bootstrap.js` template that doesn't register Flutter's worker.
  `tool/gen_precache.dart` runs after `flutter build web` to fill in the
  precache list and build hash.
  - The precache list covers the app shell, all assets (content JSON, fonts,
    shaders), icons, and the two CanvasKit variants a dart2js build can load:
    about 15 MB.
  - It skips debug `*.symbols`, the Wasm-only renderers (skwasm, wimp,
    webparagraph) and licence `NOTICES`. Any skipped file is cached on first
    use.
  - install: precache everything, versioned by a build hash;
  - fetch: cache-first for precached assets, network-first for `index.html`;
  - activate: delete old caches.
  - So **all** modules are available offline after the first load. This is a
    superset of "offline for completed modules", because content is small (est. < 300 KB JSON).
- Renderer: the default for the Flutter version used. CanvasKit is bundled
  locally (`--no-web-resources-cdn`) so offline works and nothing loads from a CDN.
- `index.html`: viewport meta, theme-color meta, and a manifest link.
- A pinned Flutter version is recorded in `.flutter-version` and README.
- Installability is verified in headless Chromium by `tool/pwa_check/check.cjs`
  (Playwright), which checks three things:
  - the manifest parses (CDP `Page.getAppManifest`);
  - the SW is controlling the page;
  - `Page.getInstallabilityErrors` is empty. This is the same signal Chrome
    uses before it fires `beforeinstallprompt`, which does not fire reliably
    in headless mode.

## 9. Ads

### 9.1 Interface (screens depend only on this)

```dart
enum AdPlacement { topicListBanner, studyNotesBanner, practiceHubBanner, quizComplete, practiceComplete }

abstract interface class AdsService {
  bool get enabled;
  Future<void> init();
  /// Returns a fixed-height slot widget, or SizedBox.shrink() when disabled.
  Widget banner(AdPlacement placement);
  /// Shows an interstitial if enabled and the frequency cap allows. Completes when dismissed.
  Future<void> maybeShowInterstitial(BuildContext context, AdPlacement placement);
}
```

- Implementations:
  - `NoopAdsService`, used when the flag is off;
  - `PlaceholderAdsService` (web, v1). The banner is a 320×50 bordered box
    labelled "Ad placeholder". The interstitial is a full-screen dialog
    labelled "Ad placeholder" with a Close button enabled after 3 seconds;
  - `AdMobAdsService` (Android/iOS): Google AdMob 320×50 banners and
    interstitials, after the Google consent (UMP) prompt where required. It is
    reached only through `ads/impl/platform_ads.dart`, whose conditional export
    keeps the SDK out of the web build.
- Selected once in `main.dart` and provided through DI. A static check (a
  test that greps `lib/screens/**`) fails if any screen imports an ad SDK or
  anything under `lib/ads/impl/`.

### 9.2 Feature flag and IDs

- `--dart-define=ADS_ENABLED=true|false`. **The default is false.**
- `--dart-define=ADSENSE_CLIENT=...` and per-slot ids are read from defines
  only. Nothing real is committed. Docs and tests use the obviously fake
  `ca-pub-0000000000000000`. `.env*` is already git-ignored.
- In v1, the web build never loads `adsbygoogle.js`. A real AdSense integration
  is a later, separately approved change.
- Native builds read `--dart-define=ADMOB_BANNER_ID=...` and
  `ADMOB_INTERSTITIAL_ID=...`; without them they use Google's public test
  units. The AdMob app ID comes from `android/key.properties` (`admobAppId=`)
  and `ios/Flutter/AdMob.local.xcconfig`, both git-ignored. Only Google's test
  publisher `ca-app-pub-3940256099942544` may appear in the repo.

### 9.3 Placement rules

| Placement | Screen | Rule |
|---|---|---|
| `topicListBanner` | S1 | Bottom of the list, inline (not sticky) |
| `studyNotesBanner` | S3 | Between sections 2 and 3, inline, only if ≥ 3 sections |
| `practiceHubBanner` | S7 | Bottom of the list, inline |
| `quizComplete` | before S6 | Interstitial; at most 1 per 3 completed quizzes and at most 1 per 10 minutes |
| `practiceComplete` | before S9 | Interstitial; same shared cap |

Never on S2, S4, S5, S8, S10, or S11, and never mid-question. At most one
ad visible at a time. Slots reserve their height, so they cause no layout shift.

## 10. Code layout

```
lib/
  main.dart                 # bootstrap, DI, flag read
  app/router.dart, theme.dart
  content/                  # models + loader (assets → models)
  engine/                   # flashcards.dart, quiz.dart, practice.dart (pure Dart)
  progress/                 # repository over shared_preferences
  ads/ads_service.dart      # interface
  ads/impl/                 # noop, placeholder, admob stub
  screens/                  # one file per screen S1–S11 (+ home_shell.dart)
  widgets/                  # note blocks, question card, progress ring, ad slot frame
assets/content/             # §5
web/                        # index.html, manifest.json, sw.js, icons
tool/                       # gen_precache.dart, pwa_check (Playwright)
test/                       # unit + widget tests
spec/SPEC.md
```

Dependencies (minimal): `go_router`, `shared_preferences`, `url_launcher`,
`provider` for DI and state, and `material_ui`. As of Flutter 3.47, Material
widgets are published as the standalone `material_ui` package, and
`go_router` already depends on it. Dev dependencies: `flutter_test`,
`flutter_lints`. Each new dependency needs a reason in the PR.

## 11. Done criteria (v1)

Each item must be demonstrated in the implementation PR, with command output or screenshots.

1. `flutter analyze` is clean, and `flutter test` is green, covering:
   - the engine unit tests: Leitner transitions, shuffle independence from
     grading, multi exact-match, practice allocation by weight, and timer expiry;
   - the content invariants in §5.2;
   - the ads static check from §9.1;
   - widget tests of S3 → S4 → S5 → S6 at a 390×844 surface.
2. `flutter build web --release --no-web-resources-cdn` succeeds, followed
   by `dart run tool/gen_precache.dart`.
3. Served locally, the headless Chromium check at **390×844** passes:
   - the manifest is valid and the SW is controlling the page;
   - Chromium reports no installability errors (installable);
   - with the network offline, a reload still renders S1 and any topic's notes;
   - no horizontal scroll on any screen at 390px or 360px.
4. An end-to-end run at 390×844 (Playwright script, screenshots in the PR)
   completes the full loop:
   - S1 → topic → read all notes → flashcard session → quiz → results → retry missed;
   - after a reload, the progress for that topic persists.
5. A practice test, run start to finish, shows the per-domain breakdown.
6. With `ADS_ENABLED=false`: no ad slots render. With `ADS_ENABLED=true`:
   the placeholders appear only at the §9.3 placements, and the interstitial
   respects the frequency cap.
7. The About page shows the CC BY 4.0 attribution, the trademark notice, and
   the non-affiliation notices. README attribution is present.
8. All 6 v1 topics meet §5.2 and §5.4, and the PR includes the source-check list.
9. The repo contains no real ad IDs (`grep -r "ca-pub-" lib web` → only `ca-pub-0000000000000000`).

## 12. Review decisions (approved 2026-10-11)

All recommendations accepted:

1. **Managed offerings:** generic concepts sourced from kubernetes.io, plus a short
   "Examples" section naming EKS/GKE/AKS as plain facts, each linking that vendor's
   own docs. Allowlisted vendor hosts (for `managed-k8s` only):
   `docs.aws.amazon.com/eks/`, `cloud.google.com/kubernetes-engine/docs/`,
   `learn.microsoft.com/en-us/azure/aks/`.
2. **minikube:** `minikube.sigs.k8s.io/docs/` is an allowed source, credited on About.
3. **Docs version:** link the unversioned (latest) docs and record `reviewedAt`.
4. **Ads flag:** `ADS_ENABLED` defaults to false in every build.
5. **URLs:** hash URL strategy.

## 13. v1.1 — complete curriculum, gaps, multi-subject (added after v1 review)

The goal after v1 was complete CKA material, a clear sense of where you are,
fast discovery of knowledge gaps, and easy onboarding of new subjects (Linux,
Docker, …).

### 13.1 Content

- 33 Kubernetes topics cover all five CKA domains plus Foundations, with
  432 flashcards and 451 questions.
- Each topic was written from its source pages, then fact-checked
  independently against them. `docs/SOURCES.md` lists every cited page.
- `subject.json` `topics` sets the recommended **study order**. Topics may
  declare `prerequisites`, which must appear earlier in that order.
- Practice tests:
  - a CKA domain-weighted mock (30 questions);
  - a mixed test across all topics;
  - one test per exam domain.

### 13.2 Multi-subject content

```
assets/content/catalog.json                 # subject ids, in display order
assets/content/subjects/<id>/subject.json   # metadata, exam, domains, study order, source allow-list, attributions
assets/content/subjects/<id>/practice_tests.json
assets/content/subjects/<id>/topics/*.json
```

- A new subject is data only. The steps are in `docs/ADDING_CONTENT.md`;
  `tool/validate_content.py` checks content without Flutter.
- The About page and source allow-lists are driven by `subject.json`.
- A subject switcher appears in the Learn app bar once there are two or more
  subjects.
- A second subject, **Docker**, ships to prove this path end to end. It was
  created with `tool/new_subject.py`.
  - 4 topics: overview, images, containers, storage.
  - Sources are docs.docker.com (Apache-2.0, credited on About).
  - Widget and browser tests switch subjects and confirm progress stays
    separate.
- Progress is keyed by item id. Ids must be unique across subjects; a test
  checks this.

### 13.3 Where am I

- **Continue card** (S1) shows "Continue / Up next · Topic N of M", the
  topic's Notes/Cards/Quiz status and a button for the next step.
  - The next action is the recently opened topic if it's incomplete.
  - Otherwise it's the next incomplete topic after it, wrapping round to
    earlier gaps.
- **Domain sections** show a weight, "x/y complete" and a progress bar, and
  can be collapsed. Fully complete domains start collapsed.
- **Topic cards** show their study-order number and step chips: Notes x/y,
  Cards, and Quiz best %, marked red when below mastery.
- **Topic hub** shows "Topic N of M", prerequisites (with completion), and
  previous/next topic links.
- **Notes** have a sections menu with read state and jump-to-section, and
  support deep links (`?section=`).
- **Search** (S1 app bar) covers topics, note sections and flashcards. A hit
  opens the exact section.

### 13.4 Finding gaps

- **Answer history** (`k8s.answers`): for each question, times seen, times
  correct, whether the latest answer was right, and when. It is recorded by
  topic quizzes, retries, reviews and practice tests.
- **Progress & gaps** (S10) shows:
  - reviews due: flashcards due across topics, and questions missed last
    time;
  - **readiness by domain**: topic progress plus accuracy on answered
    questions;
  - **knowledge gaps by competency**, weakest first. A competency is a gap
    when its accuracy is below 80% or fewer than half its questions have been
    answered;
  - topics that need attention, and practice history.
- **Review quizzes** (`/progress/review?kind=missed|competency|domain&id=…`)
  draw from that pool, prioritising questions that were wrong or are unseen.
  They feed answer history but not topic best scores.
- **Due-card session** (`/progress/cards`) reviews every due flashcard in the
  subject in one Leitner session.

## 14. Gamification: XP and daily streak

- **XP** is earned for studying: 10 per note section read (first time), 2 per
  flashcard reviewed, 5 per question answered correctly and 1 per wrong answer
  (any quiz, review or practice test; skipped questions earn nothing), and a
  50 XP bonus the first time a topic quiz reaches mastery.
- **Levels**: level N needs 100 × N XP to reach N + 1 (100, 200, 300…).
- **Daily streak**: consecutive days with any study activity. It still shows
  on the day after the last session and resets after a missed day. It is
  stored in `k8s.rewards`, so it isn't capped by the 60-day activity log, and
  the best streak is kept.
- Existing progress is credited once when `k8s.rewards` is missing (first run
  after the update, or a backup without it).
- Shown on the continue card (level and streak), the Progress screen (level
  bar, XP to next level, streak and best) and quiz/practice results (+XP).

## 15. Learning-science features

Each feature below comes from the audit in
[`docs/LEARNING.md`](../docs/LEARNING.md).

### 15.1 Confidence rating

- Topic and review quizzes submit with **Sure** or **Not sure** instead of a
  single Submit. Desktop: Enter = Sure, U = Not sure.
- After the reveal, one line explains what the rating means:
  - wrong and sure: a *confident mistake*; read the explanation closely;
  - right and unsure: it comes back for review tomorrow;
  - wrong and unsure: it comes back for review.
- Results show "N confident mistakes · M right but unsure" when either is
  non-zero.
- Answer history stores the latest rating (`sure: false` only when unsure;
  absent means sure, so older data stays valid).
- **Solid** = latest answer right *and* sure. Readiness accuracy and
  competency gaps count only solid answers, so a lucky guess still shows as a
  gap.
- Practice tests don't ask for a rating, since they simulate the exam. Their
  answers count as sure.

### 15.2 Spaced review of questions

- Questions get a review slot (box 1–5 and due date, stored as `box`/`due` in
  `k8s.answers`) using the flashcard intervals (§7.1):
  - wrong → box 1, due today;
  - right but unsure → same box (1 if new), due tomorrow;
  - right and sure → next box, due after that box's interval; a question with
    no slot stays without one.
- Answers saved before this existed: a wrong latest answer is due on the day
  it was answered.
- "Questions to review" (Home chip, Progress "Review now") lists the due
  questions, earliest first. The review quiz (`kind=missed`) prioritises
  confident mistakes.

### 15.3 Today's review (interleaved)

- Home shows a **Today's review** card when any flashcards or questions are
  due. It shows both counts, links to each, and has a **Start today's review**
  button.
- Start runs the due-card session first, then the due questions. When the
  due-card session ends (or there are no due cards), its next button reads
  "Next: N questions to review" if questions are due.
- Both steps draw across every topic and shuffle, so practice is mixed
  instead of grouped by topic.

### 15.4 Session nudges

- The end of a due-card session and the results of a review quiz show when
  the next review is due ("Next review tomorrow." / "Next review in N
  days."), using the earliest future due date across cards and questions.
- The app never prompts for extra sessions on the same day beyond what is
  due.

### 15.5 Typed-answer `command` questions

- New question type `command`. The learner types a command and it is graded
  against the accepted `answers`; the first is shown as the model answer.
  This is practice in the exam's own format (typed `kubectl`), not
  recognition.

  ```jsonc
  { "id": "deployments-cmd-01", "type": "command", "difficulty": 1,
    "stem": "Scale the Deployment `nginx-deployment` to 10 replicas.",
    "answers": ["kubectl scale deployment/nginx-deployment --replicas=10"],
    "explanation": "…", "sourceUrl": "…", "competencyId": "ws-rollouts" }
  ```

  `options` is absent. `answers` (non-empty) and `explanation` are required.
- **Grading** (`lib/engine/command_grading.dart`) compares the normalised
  shape: positional words in order, plus flags as an unordered set.
  Accepted equivalents: `k` for `kubectl`; a leading `$ ` prompt; short and
  long flags (`-n`/`--namespace`, `-A`/`--all-namespaces`, `-it`/
  `--stdin --tty`, …); `--flag=value` or `--flag value`; resource short
  names and plurals (`deploy`, `deployments`); `type/name` or
  `type name`; quotes around one word. Words after `--` must match
  exactly. Anything else, such as a different name, value or verb, or a
  missing flag, is wrong.
- **UI**: a monospace field with no autocorrect. After the reveal it shows the
  typed command (marked right or wrong), the model answer and the
  explanation. Single-key shortcuts are off while the field has focus.
- Command questions mix into topic quizzes, reviews and practice tests like
  any other question.
- **Authoring**: every accepted answer must appear on `sourceUrl`. Stems may
  name scenario objects (a node, a Deployment), and the answer may use that
  name where the page shows a placeholder. Prefer the page's own example
  names. `content_test` checks that every accepted answer grades as correct.

### 15.6 Warm-up before the notes

- A topic that hasn't been started (no notes read, no cards, no quiz) shows a
  **Warm-up: try 3 questions first** card on its hub
  (`/topic/<id>/quiz?mode=warmup`).
- It draws 3 multiple-choice questions, easiest first (no `command`
  questions). Feedback is shown as usual.
- Nothing is recorded: no answer history, no score, no ad. The last button
  reads "Start the notes" and opens them.
- Why: an attempt before studying, even a wrong one, makes the later
  reading stick better (pretesting effect).

### 15.7 "Why is it right?" prompt

- In topic and review quizzes, a right answer to a multiple-choice question
  with difficulty ≥ 2 shows the right/wrong marking but holds back the
  explanations. A card asks the learner to explain the answer to themselves in
  one sentence, then **Show the explanation**.
- Not shown for wrong answers (they need the explanation now), `command`
  questions or the warm-up. Next stays available, so it can be skipped.

### 15.8 Guided labs with fading

- A topic may have `labs`: a scenario and an ordered list of steps, each a
  `prompt`, accepted `answers` and an `explanation`.

  ```jsonc
  "labs": [{ "id": "deployments-lab-01", "title": "…", "scenario": "…",
             "sourceUrl": "…",
             "steps": [{ "prompt": "…", "answers": ["kubectl …"], "explanation": "…" }] }]
  ```

- The topic hub lists them under **Hands-on labs** (`/topic/<id>/lab/<labId>`).
- Each step is typed and checked with the §15.5 grading. A wrong answer can be
  retried, or the answer shown. After a right (or shown) answer the
  explanation appears and the lab moves on.
- **Fading** by completed runs (`k8s.labs`: lab id → runs, included in
  backup and reset):
  - run 1, *Worked example*: the full command is shown;
  - run 2, *Partly guided*: only its start (`kubectl rollout undo …`);
  - run 3 and later, *On your own*: the prompt only.
- The lab asks the learner to run each command in their own practice cluster.
  The app checks the typed command, not the cluster.
- Authoring follows §15.5: every answer appears on `sourceUrl`.
