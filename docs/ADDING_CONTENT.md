# Adding study content

All study material is data: JSON files under `assets/content/`. Adding a topic,
or a whole new subject such as Linux or Docker, needs no Dart changes.

```
assets/content/
  catalog.json                      # which subjects ship, in display order
  subjects/<subjectId>/
    subject.json                    # title, curriculum/domains, topic list, source allow-list, attribution
    practice_tests.json             # practice test definitions
    topics/<topicId>.json           # one file per topic: notes + flashcards + questions
```

Validate any time, without Flutter:

```sh
python3 tool/validate_content.py                  # everything
python3 tool/validate_content.py kubernetes rbac  # one topic file (even before it's registered)
```

`flutter test` runs the same rules (`test/content_test.dart`).

## Add a topic

1. Read the source pages yourself. Write the notes in your own words. Don't paste
   sentences or scrape pages.
2. Create `subjects/<subjectId>/topics/<topicId>.json`. Use an existing topic as a
   template (for example `kubernetes/topics/kubeadm.json`).
3. Add `<topicId>` to `topics` in `subject.json`. That list is the recommended
   study order. It drives the "Topic N of M" position, the continue card and the
   order within each domain. Prerequisites must come earlier in the list.
4. Run `python3 tool/validate_content.py` and `python3 tool/source_report.py`.

### Topic file

```jsonc
{
  "id": "rbac",                       // = file name; every item id starts with "rbac-"
  "title": "RBAC",
  "summary": "One sentence shown on the topic card.",
  "order": 4,                         // legacy; display follows the subject's topic list
  "domainIds": ["cluster-arch"],      // first = primary domain (grouping, practice breakdown)
  "competencyIds": ["ca-rbac"],       // ids from subject.json domains[].competencies
  "prerequisites": ["namespaces"],    // optional: topic ids to study first
  "estMinutes": 12,
  "reviewedAt": "2026-10-11",         // date you checked it against the sources
  "sections":  [ /* 4–8 sections, ≤ 1,500 words in total */ ],
  "flashcards": [ /* ≥ 10 */ ],
  "questions":  [ /* ≥ 12; 10 are drawn per quiz */ ]
}
```

**Section:** `{ id, heading, sourceUrl, sourceTitle, blocks: [...] }`. Every
section cites exactly one page. Block types:

| type | fields | notes |
|---|---|---|
| `p` | `text` | inline `` `code` `` and `**bold**` only |
| `bullets` | `items` | |
| `code` | `lang`, `text` | use `<placeholders>` and never realistic-looking invented values |
| `callout` | `kind` (`key` · `exam` · `warn`), `text` | |
| `table` | `header` (2–3 columns), `rows` | |
| `diagram` | `title`, `width`, `height`, `nodes`, `edges?`, `steps?` | animated, see below |

**Diagram:** boxes on a `width` × `height` grid (use width 10; the diagram
scales to the screen).
- `nodes`: `{ id, label, x, y, w, h, kind?, group? }`. `kind` picks the colour:
  `control` · `worker` · `pod` · `service` · `storage` · `external` · `user` ·
  `generic`. `group: true` draws a labelled container behind the other boxes.
  Use `\n` in a label to break a long name.
- `edges`: `{ from, to, label?, flow? }`. `flow: true` animates packets along
  the arrow. Labels are hidden when the arrow is too short for them.
- `steps`: `{ text, highlight: [nodeIds] }`, a walkthrough the reader steps
  or plays through. Step text counts toward the word limit and is what
  screen readers and search see.

**Flashcard:** `{ id, front, back, sourceUrl }`

**Question:** `{ id, type, stem, options, sourceUrl, difficulty (1–3), competencyId? }`
- `single`: 3–5 options, exactly 1 correct.
- `multi`: 3–5 options, ≥ 2 correct. The stem must contain `Select N`.
- `truefalse`: options exactly `True` / `False`.
- Every option needs an `explanation`, including correct ones.
- `competencyId` feeds the per-competency gap view. Set it whenever a
  competency fits.

### Honesty rules

- Every command, flag, field, port, default or number must appear on the
  item's own `sourceUrl` page. If you can't find it there, leave it out.
- Wrong options must be plainly wrong according to the source. Don't invent
  commands or flags to use as distractors; use real ones that do something else.
- `sourceUrl` must match an allow-listed prefix in `subject.json`.

## Add a subject (e.g. Linux, Docker)

Quick start: `python3 tool/new_subject.py docker "Docker" --source https://docs.docker.com/`
scaffolds the files below and registers the subject in `catalog.json` and
`pubspec.yaml`. Then fill in the TODOs.

1. Create `subjects/<subjectId>/subject.json`:

```jsonc
{
  "id": "docker",
  "title": "Docker",
  "tagline": "Containers from first principles",
  "description": "…",
  "contentVersion": 1,
  "reviewedAt": "YYYY-MM-DD",
  "curriculum": {                    // optional: omit if there's no exam
    "name": "…", "title": "…", "source": "https://…",
    "examVersion": "…", "checkedAt": "YYYY-MM-DD", "note": "…"
  },
  "domains": [                       // how topics are grouped; exam weights optional
    { "id": "basics", "title": "Basics", "weightPercent": null, "isExamDomain": false,
      "competencies": [ { "id": "…", "text": "…" } ] }
  ],
  "topics": ["…"],
  "sourceAllowlist": [ { "prefix": "https://docs.docker.com/" } ],
  "attributions": [ { "text": "…license + changes statement…", "links": [ { "label": "…", "url": "…" } ] } ],
  "trademarks": [ { "text": "…", "links": [] } ]
}
```

2. Check the licence of every source before you allow-list it, and write a
   matching attribution. The About page shows each subject's attributions.
3. Add `practice_tests.json` (it may be `{ "tests": [] }`), then your topics.
4. Add the subject id to `catalog.json`. Then declare its two asset
   directories in `pubspec.yaml` (`flutter test` checks this):

   ```yaml
       - assets/content/subjects/<subjectId>/
       - assets/content/subjects/<subjectId>/topics/
   ```

   The app shows a subject switcher once more than one subject exists.
5. Progress is stored per item id, so new subjects never collide with existing
   progress as long as topic ids are unique across subjects. The validator
   checks this.
