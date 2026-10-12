"""Scaffolds a new study subject (e.g. Linux, Docker).

    python3 tool/new_subject.py docker "Docker" --source https://docs.docker.com/

Creates assets/content/subjects/<id>/{subject.json, practice_tests.json, topics/},
adds the id to catalog.json and the asset directories to pubspec.yaml. Then:
fill in domains/attributions, check the source licence, add topics
(docs/ADDING_CONTENT.md) and run `python3 tool/validate_content.py <id>`.
"""
import argparse
import json
import re
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "assets" / "content"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("id", help="lowercase id, e.g. docker")
    ap.add_argument("title", help='display title, e.g. "Docker"')
    ap.add_argument("--source", action="append", default=[],
                    help="allowed source URL prefix (repeatable)")
    args = ap.parse_args()

    sid = args.id
    if not re.fullmatch(r"[a-z][a-z0-9-]*", sid):
        raise SystemExit("id must be lowercase letters, digits and dashes")
    sdir = CONTENT / "subjects" / sid
    if sdir.exists():
        raise SystemExit(f"{sdir} already exists")
    (sdir / "topics").mkdir(parents=True)

    subject = {
        "id": sid,
        "title": args.title,
        "tagline": "TODO one-line tagline",
        "description": "TODO description",
        "contentVersion": 1,
        "reviewedAt": date.today().isoformat(),
        "domains": [
            {"id": f"{sid}-basics", "title": "Basics", "weightPercent": None,
             "isExamDomain": False, "competencies": []},
        ],
        "topics": [],
        "sourceAllowlist": [{"prefix": p} for p in args.source],
        "attributions": [
            {"text": "TODO: licence + 'Changes: summarized and rewritten' statement "
                     "for every allow-listed source.", "links": []},
        ],
        "trademarks": [],
    }
    (sdir / "subject.json").write_text(json.dumps(subject, indent=2) + "\n")
    (sdir / "practice_tests.json").write_text(json.dumps({"tests": []}, indent=2) + "\n")

    catalog_path = CONTENT / "catalog.json"
    catalog = json.loads(catalog_path.read_text())
    catalog["subjects"].append(sid)
    catalog_path.write_text(json.dumps(catalog, indent=2) + "\n")

    pubspec_path = ROOT / "pubspec.yaml"
    pubspec = pubspec_path.read_text()
    anchor = "    - assets/content/\n"
    if anchor not in pubspec:
        raise SystemExit("pubspec.yaml: couldn't find the assets list; add the directories by hand")
    pubspec = pubspec.replace(
        anchor,
        anchor + f"    - assets/content/subjects/{sid}/\n    - assets/content/subjects/{sid}/topics/\n",
        1,
    )
    pubspec_path.write_text(pubspec)
    print(f"Created {sdir.relative_to(ROOT)}; registered in catalog.json and pubspec.yaml.")
    print("Next: add topics (docs/ADDING_CONTENT.md), then python3 tool/validate_content.py " + sid)


if __name__ == "__main__":
    main()
