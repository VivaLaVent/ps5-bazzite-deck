#!/usr/bin/env python3
"""Render docs/release-notes/<tag>.md (and docs/update-sections/<tag>.md) with the release's files and update GitHub.

  python3 tools/release_notes.py [tag ...] [--dry-run]
"""
import json, os, re, subprocess, sys, tempfile

REPO = "VivaLaVent/ps5-bazzite-deck"
DISCORD = "https://discord.gg/ps5linux"
KOFI = "https://ko-fi.com/vivalavent"
SRC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = "/tmp/release-notes"
PROBLEMS = (f"**Found a problem?** Run `ps5-report` on the PS5 and post the file it saves in [Discord]({DISCORD}).\n"
            f"Like the project? Support it on [Ko-fi]({KOFI}).\n")


def tags():
    d = os.path.join(SRC, "docs/release-notes")
    t = [f[:-3] for f in os.listdir(d) if re.fullmatch(r"v\d+\.\d+(?:\.\d+)?\.md", f)]
    return sorted(t, key=lambda t: tuple(int(x) for x in t[1:].split(".")))


def gh(*args):
    r = subprocess.run(["gh", *args], capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip())
    return r.stdout


def section(text, name):
    m = re.search(rf"^## {re.escape(name)}\n(.*?)(?=^## |\Z)", text, re.S | re.M)
    return m.group(1).strip() if m else ""


def files_section(tag, assets):
    base = f"ps5-bazzite-deck-{tag}"
    used, lines = set(), []
    for prefix, desc in [(base, "full image"), (f"ps5-bazzite-deck-bootc-{tag}", "bootc disk image")]:
        vols = sorted(a for a in assets if re.fullmatch(rf"{re.escape(prefix)}\.img\.7z\.\d{{3}}", a))
        if not vols:
            continue
        if prefix == base:
            lines.append(f"- `{base}.img.7z.{'/.'.join(v.rsplit('.', 1)[1] for v in vols)}` – {desc}, 7-Zip multi-volume (extract from `.001`)")
        else:
            lines.append(f"- `{prefix}.img.7z.*` – {desc}, 7-Zip multi-volume (extract from `.001`)")
        used.update(vols)
    for name, desc in [
        (f"{base}.sha256", "checksums for the image volumes"),
        (f"ps5-bazzite-deck-bootc-{tag}.sha256", "checksums for the bootc image and its volumes"),
        (f"{base}-update.tar.xz", "in-place update for Legacy installs"),
        (f"{base}-update.tar.xz.sha256", "checksum"),
        (f"bazzite-bootc-loader-{tag}.elf", "the PS5 Linux loader: soniciso1's ps5-linux-loader, which dumps the PS5 Pro GPU firmware on most firmware versions"),
        (f"bazzite-bootc-loader-{tag}.elf.sha256", "loader checksum"),
    ] + [(a, "PS5 Linux kernel RPM (used by the bootc image build)") for a in sorted(assets) if a.endswith(".rpm")]:
        if name in assets:
            lines.append(f"- `{name}` – {desc}")
            used.add(name)
    lines += [f"- `{a}`" for a in sorted(assets) if a not in used]
    return "## Files\n" + "\n".join(lines) + "\n"


def render(tag, tmp):
    assets = [a["name"] for a in json.loads(gh("release", "view", tag, "--repo", REPO, "--json", "body,assets"))["assets"]]
    per = open(os.path.join(SRC, "docs/release-notes", f"{tag}.md"), encoding="utf-8").read()
    upd_path = os.path.join(SRC, "docs/update-sections", f"{tag}.md")
    upd = open(upd_path, encoding="utf-8").read().strip() if os.path.exists(upd_path) else ""
    versions = ""
    if "VERSIONS.md" in assets:
        gh("release", "download", tag, "--repo", REPO, "-p", "VERSIONS.md", "-D", tmp, "--clobber")
        v = open(os.path.join(tmp, "VERSIONS.md"), encoding="utf-8").read().split("\n")
        versions = "## Versions\n" + "\n".join(l for l in v if l.startswith("|")) + "\n"
    issues = [l for l in section(per, "Known issues").splitlines() if l.startswith("- ")]
    known = ("## Known issues\n" + "\n".join(issues) + "\n") if issues else ""

    def secs(*names):
        return "".join(f"## {n}\n{body}\n" for n in names if (body := section(per, n)))

    head = "## What's new\n" + section(per, "What's new") + "\n"
    if section(per, "Legacy"):
        parts = [head, secs("bootc", "Problems"), known, secs("What to test", "Sharing logs", "Legacy"),
                 versions, files_section(tag, assets), "---\n" + PROBLEMS]
    else:
        footer = "" if section(per, "New install") else (
            f"---\n**New install:** download the [latest stable release](https://github.com/{REPO}/releases/latest) full image, "
            "flash it to USB, then update using the built-in update command above.\n"
            "**Bootc image:** `sudo bootc upgrade` on a running bootc install pulls the latest image in the background.\n\n" + PROBLEMS)
        parts = [head, upd + "\n", secs("New install", "What to test", "Testing", "Sharing logs"), known,
                 versions, files_section(tag, assets), footer]
    return "\n".join(p for p in parts if p)


def main():
    dry = "--dry-run" in sys.argv
    os.makedirs(OUT, exist_ok=True)
    for tag in [a for a in sys.argv[1:] if not a.startswith("--")] or tags():
        try:
            with tempfile.TemporaryDirectory() as tmp:
                notes = render(tag, tmp)
        except RuntimeError as e:
            print(f"skip {tag}: {e}")
            continue
        path = os.path.join(OUT, f"{tag}.md")
        open(path, "w", encoding="utf-8").write(notes)
        if dry:
            print(f"rendered {tag} -> {path}")
            continue
        try:
            gh("release", "edit", tag, "--repo", REPO, "--notes-file", path)
            print(f"updated {tag}")
        except Exception as e:
            print(f"skip {tag}: no release ({e})")


if __name__ == "__main__":
    main()
