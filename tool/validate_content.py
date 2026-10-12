"""Validates study content without Flutter (mirrors test/content_test.dart).

    python3 tool/validate_content.py                      # every subject
    python3 tool/validate_content.py kubernetes           # one subject
    python3 tool/validate_content.py kubernetes rbac pv   # specific topic files,
                                                          # even if not yet registered

Exit code 0 = valid. Rules: spec/SPEC.md §5.2 and docs/ADDING_CONTENT.md.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "assets" / "content"
BLOCK_TYPES = {"p", "bullets", "code", "callout", "table", "diagram"}
DIAGRAM_KINDS = {"control", "worker", "pod", "service", "storage", "external", "user", "generic"}
CALLOUTS = {"key", "exam", "warn", "story"}



def check_diagram(sid, b, err):
    """Same rules as DiagramBlock.fromJson; returns the step word count."""
    W, H = b.get("width"), b.get("height")
    if not isinstance(b.get("title"), str) or not b["title"].strip():
        err(f"{sid}: diagram needs a title")
    if not all(isinstance(v, (int, float)) and v > 0 for v in (W, H)):
        err(f"{sid}: diagram needs width/height")
        return 0
    ids = set()
    for nd in b.get("nodes", []):
        nid = nd.get("id")
        if nid in ids:
            err(f"{sid}: diagram duplicate node {nid}")
        ids.add(nid)
        if not isinstance(nd.get("label"), str) or not nd["label"].strip():
            err(f"{sid}: diagram node {nid} needs a label")
        if nd.get("kind", "generic") not in DIAGRAM_KINDS:
            err(f"{sid}: diagram node {nid} kind {nd.get('kind')}")
        x, y, w, h = (nd.get(k) for k in ("x", "y", "w", "h"))
        if not all(isinstance(v, (int, float)) for v in (x, y, w, h)) or \
                x < 0 or y < 0 or x + w > W + 1e-9 or y + h > H + 1e-9:
            err(f"{sid}: diagram node {nid} outside the grid")
    if not ids:
        err(f"{sid}: diagram has no nodes")
    for ed in b.get("edges", []):
        if ed.get("from") not in ids or ed.get("to") not in ids:
            err(f"{sid}: diagram edge {ed.get('from')}->{ed.get('to')} unknown node")
    n = 0
    for st in b.get("steps", []):
        if not isinstance(st.get("text"), str) or not st["text"].strip():
            err(f"{sid}: diagram step needs text")
        for h in st.get("highlight", []):
            if h not in ids:
                err(f"{sid}: diagram step highlights unknown {h}")
        n += words(st.get("text", ""))
    return n

def words(text):
    return len([w for w in re.split(r"\s+", text) if w])


def check_topic(path, subject, comp_ids, domain_ids, allow, errors):
    def err(msg):
        errors.append(f"{path.name}: {msg}")

    try:
        t = json.loads(path.read_text())
    except Exception as e:  # noqa: BLE001
        return err(f"invalid JSON: {e}")
    tid = t.get("id")
    if tid != path.stem:
        err(f"id {tid!r} must equal file name {path.stem!r}")
    for key, typ in [("title", str), ("summary", str), ("order", int), ("domainIds", list),
                     ("competencyIds", list), ("estMinutes", int), ("reviewedAt", str),
                     ("sections", list), ("flashcards", list), ("questions", list)]:
        if not isinstance(t.get(key), typ):
            err(f"{key}: expected {typ.__name__}")
    if errors and any(e.startswith(path.name) for e in errors):
        return
    if not t["domainIds"]:
        err("domainIds empty")
    for d in t["domainIds"]:
        if d not in domain_ids:
            err(f"unknown domain {d}")
    for c in t["competencyIds"]:
        if c not in comp_ids:
            err(f"unknown competency {c}")
    prereq = t.get("prerequisites", [])
    if not isinstance(prereq, list):
        err("prerequisites must be a list")

    def url_ok(url):
        return any(url.startswith(a["prefix"]) and ("topics" not in a or tid in a["topics"]) for a in allow)

    ids = set()

    def item_id(i):
        if not isinstance(i, str) or not i.startswith(tid + "-"):
            err(f"id {i!r} must start with '{tid}-'")
        if i in ids:
            err(f"duplicate id {i}")
        ids.add(i)

    if not 4 <= len(t["sections"]) <= 8:
        err(f"{len(t['sections'])} sections (need 4-8)")
    total_words = 0
    for s in t["sections"]:
        item_id(s.get("id"))
        for k in ("heading", "sourceUrl", "sourceTitle"):
            if not isinstance(s.get(k), str) or not s[k].strip():
                err(f"{s.get('id')}: {k} missing")
        if not url_ok(s.get("sourceUrl", "")):
            err(f"{s.get('id')}: source not allow-listed: {s.get('sourceUrl')}")
        if not s.get("blocks"):
            err(f"{s.get('id')}: no blocks")
        for b in s.get("blocks", []):
            ty = b.get("type")
            if ty not in BLOCK_TYPES:
                err(f"{s['id']}: bad block type {ty}")
            elif ty in ("p",):
                total_words += words(b.get("text", ""))
            elif ty == "diagram":
                total_words += check_diagram(s["id"], b, err)
            elif ty == "bullets":
                if not b.get("items"):
                    err(f"{s['id']}: empty bullets")
                total_words += sum(words(x) for x in b.get("items", []))
            elif ty == "code":
                if not isinstance(b.get("lang"), str) or not b.get("text"):
                    err(f"{s['id']}: code needs lang+text")
                total_words += words(b.get("text", ""))
            elif ty == "callout":
                if b.get("kind") not in CALLOUTS:
                    err(f"{s['id']}: callout kind {b.get('kind')}")
                total_words += words(b.get("text", ""))
            elif ty == "table":
                h = b.get("header", [])
                if not 2 <= len(h) <= 3:
                    err(f"{s['id']}: table needs 2-3 columns")
                for r in b.get("rows", []):
                    if len(r) != len(h):
                        err(f"{s['id']}: ragged table row")
                total_words += sum(words(x) for x in h) + sum(words(c) for r in b.get("rows", []) for c in r)
    if total_words > 1500:
        err(f"notes are {total_words} words (max 1500)")

    if len(t["flashcards"]) < 10:
        err(f"{len(t['flashcards'])} flashcards (need >= 10)")
    for c in t["flashcards"]:
        item_id(c.get("id"))
        for k in ("front", "back", "sourceUrl"):
            if not isinstance(c.get(k), str) or not c[k].strip():
                err(f"{c.get('id')}: {k} missing")
        if not url_ok(c.get("sourceUrl", "")):
            err(f"{c.get('id')}: source not allow-listed")

    if len(t["questions"]) < 12:
        err(f"{len(t['questions'])} questions (need >= 12)")
    for q in t["questions"]:
        qid = q.get("id")
        item_id(qid)
        if not url_ok(q.get("sourceUrl", "")):
            err(f"{qid}: source not allow-listed")
        if q.get("competencyId") is not None and q["competencyId"] not in comp_ids:
            err(f"{qid}: unknown competency {q['competencyId']}")
        if q.get("difficulty") not in (1, 2, 3):
            err(f"{qid}: difficulty must be 1-3")
        opts = q.get("options", [])
        if len({o.get("id") for o in opts}) != len(opts):
            err(f"{qid}: duplicate option ids")
        for o in opts:
            if not o.get("text") or not o.get("explanation") or not isinstance(o.get("correct"), bool):
                err(f"{qid}/{o.get('id')}: needs text, explanation, correct")
        n = sum(1 for o in opts if o.get("correct"))
        ty = q.get("type")
        if ty == "single":
            if n != 1 or not 3 <= len(opts) <= 5:
                err(f"{qid}: single needs 1 correct and 3-5 options")
        elif ty == "multi":
            if n < 2 or not 3 <= len(opts) <= 5:
                err(f"{qid}: multi needs >=2 correct and 3-5 options")
            if f"Select {n}" not in q.get("stem", ""):
                err(f"{qid}: stem must contain 'Select {n}'")
        elif ty == "truefalse":
            if n != 1 or sorted(o.get("text") for o in opts) != ["False", "True"]:
                err(f"{qid}: truefalse needs exactly True/False with 1 correct")
        else:
            err(f"{qid}: bad type {ty}")
    return ids


def check_subject(sid, only=None):
    errors = []
    sdir = ROOT / "subjects" / sid
    subject = json.loads((sdir / "subject.json").read_text())
    domain_ids = {d["id"] for d in subject["domains"]}
    comp_ids = {c["id"] for d in subject["domains"] for c in d["competencies"]}
    allow = subject["sourceAllowlist"]
    files = [sdir / "topics" / f"{t}.json" for t in (only or subject["topics"])]
    if not only:
        on_disk = {p.stem for p in (sdir / "topics").glob("*.json")}
        if on_disk != set(subject["topics"]):
            errors.append(f"subject.json topics != files on disk: {sorted(on_disk ^ set(subject['topics']))}")
    all_ids = {}
    for f in files:
        if not f.exists():
            errors.append(f"missing {f}")
            continue
        ids = check_topic(f, subject, comp_ids, domain_ids, allow, errors) or set()
        for i in ids:
            if i in all_ids:
                errors.append(f"id {i} in both {all_ids[i]} and {f.name}")
            all_ids[i] = f.name
    return errors


def main(argv):
    catalog = json.loads((ROOT / "catalog.json").read_text())
    subjects = [argv[0]] if argv else catalog["subjects"]
    only = argv[1:] or None
    errors = []
    for sid in subjects:
        errors += [f"[{sid}] {e}" for e in check_subject(sid, only)]
    for e in errors:
        print("ERROR", e)
    print("OK" if not errors else f"{len(errors)} error(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
