#!/usr/bin/env python3
"""Render the GitHub release notes of v1.0.3 and newer in one common structure and update them.

  python3 tools/release_notes.py            # render to /tmp/release-notes/<tag>.md and update GitHub
  python3 tools/release_notes.py --dry-run  # render only

Per release it combines: the release's
"What's new" / "What to test" / "Testing" / "Sharing logs" / "Known issues" (docs/release-notes/<tag>.md), its in-place update section
(docs/update-sections/<tag>.md), the common settings/install/known-issues blocks below, the release's
own VERSIONS.md (downloaded from the release) and its actual asset list.
"""
import json, os, re, subprocess, sys, tempfile

REPO = "VivaLaVent/ps5-bazzite-deck"
def _tags():
    d = os.path.join(SRC, "docs/release-notes")
    tags = [f[:-3] for f in os.listdir(d) if re.fullmatch(r"v\d+\.\d+(?:\.\d+)?\.md", f)]
    return sorted(tags, key=lambda t: tuple(int(x) for x in t[1:].split(".")))

DISCORD = "https://discord.gg/ps5linux"
KOFI = "https://ko-fi.com/vivalavent"
SRC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = "/tmp/release-notes"

COMMON_ISSUES = []


def gh(*args, capture=True):
    r = subprocess.run(["gh", *args], capture_output=capture, text=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip())
    return r.stdout


def section(text, name):
    m = re.search(rf"^## {re.escape(name)}\n(.*?)(?=^## |\Z)", text, re.S | re.M)
    return m.group(1).strip() if m else ""


def files_section(tag, assets):
    base = f"ps5-bazzite-deck-{tag}"
    used, lines = set(), []
    vols = sorted(a for a in assets if re.fullmatch(rf"{re.escape(base)}\.img\.7z\.\d{{3}}", a))
    if vols:
        lines.append(f"- `{base}.img.7z.{'/.'.join(v.rsplit('.', 1)[1] for v in vols)}` – full image, 7-Zip multi-volume (extract from `.001`)")
        used.update(vols)
    bootc_vols = sorted(a for a in assets if re.fullmatch(rf"ps5-bazzite-deck-bootc-{re.escape(tag)}\.img\.7z\.\d{{3}}", a))
    if bootc_vols:
        lines.append(f"- `ps5-bazzite-deck-bootc-{tag}.img.7z.*` – bootc disk image, 7-Zip multi-volume (extract from `.001`)")
        used.update(bootc_vols)
    for name, desc in [
        (f"{base}.sha256", "checksums for the image volumes"),
        (f"ps5-bazzite-deck-bootc-{tag}.sha256", "checksums for the bootc image volumes"),
        (f"{base}-update.tar.gz", "in-place update (see Updating above)"),
        (f"{base}-update.tar.gz.sha256", "checksum"),
        (f"{base}-update.tar.xz", "in-place update (see Updating above)"),
        (f"{base}-update.tar.xz.sha256", "checksum"),
        (f"ps5-quick-{tag}.tar.gz", "quick kernel package"),
        (f"ps5-quick-{tag}.tar.gz.sha256", "checksum"),
        (f"bazzite-bootc-loader-{tag}.elf", "replaces the standard PS5 Linux loader; built from rmux's ps5-linux-loader + BLS/bootc patches"),
        (f"bazzite-bootc-loader-{tag}.elf.sha256", "loader checksum"),
        ("btusb.ko", "Bluetooth kernel module for v1.0.2 users"),
    ] + [(a, "PS5 Linux kernel RPM (used by the bootc image build)") for a in sorted(assets) if a.endswith(".rpm")]:
        if name in assets:
            lines.append(f"- `{name}` – {desc}")
            used.add(name)
    lines += [f"- `{a}`" for a in sorted(assets) if a not in used]
    return "## Files\n" + "\n".join(lines) + "\n"


def render(tag, tmp):
    info = json.loads(gh("release", "view", tag, "--repo", REPO, "--json", "body,assets"))
    assets = [a["name"] for a in info["assets"]]
    per = open(os.path.join(SRC, "docs/release-notes", f"{tag}.md"), encoding="utf-8").read()
    upd = open(os.path.join(SRC, "docs/update-sections", f"{tag}.md"), encoding="utf-8").read().strip()
    versions = ""
    if "VERSIONS.md" in assets:
        gh("release", "download", tag, "--repo", REPO, "-p", "VERSIONS.md", "-D", tmp, "--clobber")
        v = open(os.path.join(tmp, "VERSIONS.md"), encoding="utf-8").read().split("\n")
        versions = "## Versions\n" + "\n".join(l for l in v if l.startswith("|")) + "\n"
    issues = [l[2:] for l in section(per, "Known issues").splitlines() if l.startswith("- ")]
    vrr = section(per, "VRR test")
    extra = "".join(f"## {name}\n{body}\n" for name in
                    ("What to test", "Testing", "Sharing logs",
                     "Already running", "New installs", "Trying the bootc image")
                    if (body := section(per, name)))
    parts = ["## What's new\n" + section(per, "What's new") + "\n",
             ("## VRR test\n" + vrr + "\n") if vrr else "", extra, upd + "\n",
             ("## Known issues\n" + "\n".join(f"- {i}" for i in COMMON_ISSUES + issues) + "\n") if issues else "",
             versions, files_section(tag, assets), f"---\n**New install:** download the [latest stable release](https://github.com/{REPO}/releases/latest) full image, flash it to USB, then update using the built-in update command above.\n**Bootc image:** `sudo bootc upgrade` on a running bootc install pulls the latest image in the background.\n\n**Found a problem?** Run `ps5-report` on the PS5 and post the file it saves in [Discord]({DISCORD}).\nLike the project? Support it on [Ko-fi]({KOFI}).\n"]
    return "\n".join(p for p in parts if p)


def main():
    dry = "--dry-run" in sys.argv
    os.makedirs(OUT, exist_ok=True)
    for tag in [a for a in sys.argv[1:] if not a.startswith("--")] or _tags():
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
        else:
            try:
                gh("release", "edit", tag, "--repo", REPO, "--notes-file", path)
                print(f"updated {tag}")
            except Exception as e:      # release deleted on GitHub: its notes stay in docs/
                print(f"skip {tag}: no release ({e})")


if __name__ == "__main__":
    main()
