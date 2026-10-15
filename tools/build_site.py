#!/usr/bin/env python3
"""Builds the site of the official plugin list: site/index.json, site/zips/<id>-<version>.zip and a small index.html.

Usage: tools/build_site.py [--out site] [--published URL-of-the-published-index.json]

* Every folder in plugins/ with a plugin.json is a plugin. The zip holds the files of the folder, in a fixed order with
  fixed dates, so the same files always give the same zip (and the same SHA-256).
* With --published the new zips are compared with the list that is online: a plugin whose files changed but whose version
  did not is an error ("bump the version"), so what people installed is never silently different from what the list says.
"""
import argparse
import datetime
import hashlib
import html
import json
import os
import re
import sys
import urllib.request
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE_URL = "https://michalsarna.github.io/baseCreator-plugins/"
REPO_URL = "https://github.com/michalsarna/baseCreator-plugins"
ID_RE = re.compile(r"^[a-z0-9_-]{1,64}$")
VER_RE = re.compile(r"^\d+(\.\d+){0,3}$")
PROGRAMS = {"lightcreator", "millcreator", "pencreator"}


def fail(msg):
    print(f"ERROR: {msg}")
    sys.exit(1)


def files_of(folder):
    out = []
    for base, dirs, names in os.walk(folder):
        dirs[:] = sorted(d for d in dirs if not d.startswith("."))
        for n in sorted(names):
            if n.startswith(".") or n.endswith("~"):
                continue
            full = os.path.join(base, n)
            out.append((os.path.relpath(full, folder).replace(os.sep, "/"), full))
    return sorted(out)


def build_zip(folder, dest):
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for rel, full in files_of(folder):
            info = zipfile.ZipInfo(rel, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            with open(full, "rb") as f:
                z.writestr(info, f.read())
    h = hashlib.sha256()
    with open(dest, "rb") as f:
        h.update(f.read())
    return h.hexdigest(), os.path.getsize(dest)


def provides(m):
    names = [("presets", "presets"), ("clipart", "clipart"), ("texts", "translations"), ("data", "data files"), ("importers", "importers"), ("generators", "generators"), ("postprocessors", "postprocessors")]
    return [label for key, label in names if m.get(key)]


def changelog(folder):
    p = os.path.join(folder, "CHANGELOG.md")
    if not os.path.exists(p):
        return ""
    text = open(p, encoding="utf-8").read().strip()
    # the first section
    parts = re.split(r"\n(?=## )", text)
    first = parts[0] if not parts[0].startswith("# ") or len(parts) == 1 else parts[1]
    return first.strip()[:600]


def published_index(url):
    if not url:
        return {}
    try:
        with urllib.request.urlopen(url, timeout=20) as r:
            data = json.load(r)
        return {p["id"]: p for p in data.get("plugins", [])}
    except Exception as e:  # not published yet, or no network: nothing to compare with
        print(f"note: no published list to compare with ({e})")
        return {}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "site"))
    ap.add_argument("--published", default="")
    args = ap.parse_args()
    published = published_index(args.published)
    plugins_dir = os.path.join(ROOT, "plugins")
    os.makedirs(os.path.join(args.out, "zips"), exist_ok=True)
    entries = []
    for name in sorted(os.listdir(plugins_dir)):
        folder = os.path.join(plugins_dir, name)
        manifest = os.path.join(folder, "plugin.json")
        if not os.path.isfile(manifest):
            continue
        m = json.load(open(manifest, encoding="utf-8"))
        pid = m.get("id", "")
        if pid != name or not ID_RE.match(pid):
            fail(f"{name}: the id must equal the folder name and use a-z 0-9 - _")
        version = str(m.get("version", ""))
        if not VER_RE.match(version):
            fail(f"{pid}: the version must be like 1.2.0")
        for key in ("name", "description", "author", "license"):
            if not str(m.get(key, "")).strip():
                fail(f"{pid}: the manifest needs {key}")
        for p in m.get("programs", []):
            if p not in PROGRAMS:
                fail(f"{pid}: unknown program {p}")
        zip_name = f"{pid}-{version}.zip"
        dest = os.path.join(args.out, "zips", zip_name)
        digest, size = build_zip(folder, dest)
        old = published.get(pid)
        if old and old.get("version") == version and old.get("sha256") != digest:
            fail(f"{pid}: the files changed but the version is still {version}; bump the version in plugin.json (and say what changed in CHANGELOG.md)")
        entries.append({
            "id": pid,
            "name": m["name"],
            "description": m["description"],
            "author": m["author"],
            "license": m["license"],
            "programs": m.get("programs", []),
            "provides": provides(m),
            "version": version,
            "min_base": m.get("min_base", ""),
            "url": SITE_URL + "zips/" + zip_name,
            "sha256": digest,
            "size": size,
            "homepage": f"{REPO_URL}/tree/main/plugins/{pid}",
            "changelog": changelog(folder),
        })
        print(f"built {zip_name} {size} bytes")
    if not entries:
        fail("no plugins found")
    index = {"format": 1, "updated": datetime.date.today().isoformat(), "plugins": entries}
    with open(os.path.join(args.out, "index.json"), "w", encoding="utf-8") as f:
        json.dump(index, f, indent=2, ensure_ascii=False)
        f.write("\n")
    rows = "".join(
        f"<tr><td><b>{html.escape(e['name'])}</b><br><small>{html.escape(e['description'])}</small></td><td>{html.escape(e['version'])}</td>"
        f"<td>{html.escape(', '.join(e['programs']) or 'all')}</td><td>{html.escape(', '.join(e['provides']))}</td></tr>"
        for e in entries
    )
    page = f"""<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>baseCreator plugins</title>
<style>body{{font:16px system-ui,sans-serif;max-width:860px;margin:2rem auto;padding:0 1rem;background:#1f2125;color:#e8e8e8}}
a{{color:#f5883f}}table{{border-collapse:collapse;width:100%}}td,th{{border-bottom:1px solid #444;padding:.5rem;text-align:left;vertical-align:top}}
img{{width:96px;height:96px;float:left;margin:0 1rem 1rem 0}}small{{color:#aaa}}</style>
<img src="icon.png" alt=""><h1>baseCreator plugins</h1>
<p>The official list of plugins for LightCreator, MillCreator and PenCreator. The programs read <a href="index.json">index.json</a>:
open <b>Settings → Plugins… → Official plugins</b> in a program to install and update them.
How to write one, and how to send it here: <a href="{REPO_URL}">the repository</a>.</p>
<table><tr><th>Plugin</th><th>Version</th><th>For</th><th>Brings</th></tr>{rows}</table></html>"""
    with open(os.path.join(args.out, "index.html"), "w", encoding="utf-8") as f:
        f.write(page)
    import shutil
    shutil.copy(os.path.join(ROOT, "assets", "icon-256.png"), os.path.join(args.out, "icon.png"))
    print(f"{len(entries)} plugins in {args.out}/index.json")


if __name__ == "__main__":
    main()
