#!/usr/bin/env python3
"""Render docs/release-notes/<tag>.md with the release's files and update GitHub.

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
    known = [
        (f"ps5-bazzite-deck-bootc-{tag}.sha256", "checksums for the bootc image and its volumes"),
        (f"bazzite-bootc-loader-{tag}.elf", "the PS5 Linux loader for this release: soniciso1's ps5-linux-loader, which also hands Linux "
                                            "the PS5 Pro GPU firmware, the Wi-Fi firmware and the console's Bluetooth pairings"),
        (f"bazzite-bootc-loader-{tag}.elf.sha256", "loader checksum"),
        (f"ps5-bazzite-deck-{tag}-update.tar.xz", "the last in-place update for Legacy installs, which are no longer supported"),
        (f"ps5-bazzite-deck-{tag}-update.tar.xz.sha256", "checksum"),
    ] + [(a, "PS5 Linux kernel RPM (used by the bootc image build)") for a in sorted(assets) if a.endswith(".rpm")]
    vols = sorted(a for a in assets if re.fullmatch(rf"ps5-bazzite-deck-bootc-{re.escape(tag)}\.img\.7z\.\d{{3}}", a))
    lines = [f"- `ps5-bazzite-deck-bootc-{tag}.img.7z.*` – bootc disk image, 7-Zip multi-volume (extract from `.001`)"] if vols else []
    lines += [f"- `{name}` – {desc}" for name, desc in known if name in assets]
    used = set(vols) | {name for name, _ in known}
    lines += [f"- `{a}`" for a in sorted(assets) if a not in used]
    return "## Files\n" + "\n".join(lines) + "\n"


def render(tag, tmp):
    assets = [a["name"] for a in json.loads(gh("release", "view", tag, "--repo", REPO, "--json", "body,assets"))["assets"]]
    per = open(os.path.join(SRC, "docs/release-notes", f"{tag}.md"), encoding="utf-8").read()
    versions = ""
    if "VERSIONS.md" in assets:
        gh("release", "download", tag, "--repo", REPO, "-p", "VERSIONS.md", "-D", tmp, "--clobber")
        v = open(os.path.join(tmp, "VERSIONS.md"), encoding="utf-8").read().split("\n")
        versions = "## Versions\n" + "\n".join(l for l in v if l.startswith("|")) + "\n"
    issues = [l for l in section(per, "Known issues").splitlines() if l.startswith("- ")]
    known = ("## Known issues\n" + "\n".join(issues) + "\n") if issues else ""

    def secs(*names):
        return "".join(f"## {n}\n{body}\n" for n in names if (body := section(per, n)))

    parts = ["## What's new\n" + section(per, "What's new") + "\n", secs("bootc", "Problems"), known,
             secs("What to test", "Sharing logs"), versions, files_section(tag, assets), "---\n" + PROBLEMS]
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
