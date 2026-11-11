#!/usr/bin/env python3
"""Set the first usable LBA of a GPT, in both headers, on a disk image or a drive.

PS5 system software 4.x sizes its walk over the partition entries from that field. bootc-image-builder writes 2048,
which makes it read far past the 128 real entries: the table fails its check, no partitions appear, and the PS5
says "unknown format" (the loader then finds no bzImage). 34, what sgdisk writes, works. Found by fitamix and
numitors (ps5-bazzite-deck issue thread on firmware 4.x).

  gpt-first-lba.py ps5-bazzite-deck-bootc-vX.Y.img           show what would change
  gpt-first-lba.py ps5-bazzite-deck-bootc-vX.Y.img --apply   change it
  sudo gpt-first-lba.py /dev/sdX --apply                     an already flashed drive (macOS: /dev/rdiskN)

Only that field and the two header checksums change; partitions and data are untouched.
"""
import argparse
import struct
import sys
import zlib

HDR = struct.Struct("<8sIIIIQQQQ16sQIII")   # up to and including the entries' CRC


def read_header(f, sector, lba):
    f.seek(lba * sector)
    raw = f.read(sector)
    if len(raw) < 92 or raw[:8] != b"EFI PART":
        return None
    sig, rev, size, crc, _, my, alt, first, last, guid, entries, count, esize, ecrc = HDR.unpack_from(raw)
    if not 92 <= size <= sector:
        return None
    body = bytearray(raw[:size])
    body[16:20] = b"\0\0\0\0"
    if zlib.crc32(body) & 0xFFFFFFFF != crc:
        return None
    return {"lba": lba, "raw": bytearray(raw), "size": size, "my": my, "alt": alt, "first": first,
            "entries": entries, "count": count, "esize": esize}


def lowest_partition_start(f, sector, h):
    f.seek(h["entries"] * sector)
    table = f.read(h["count"] * h["esize"])
    starts = [struct.unpack_from("<Q", table, i * h["esize"] + 32)[0]
              for i in range(h["count"]) if any(table[i * h["esize"]:i * h["esize"] + 16])]
    return min(starts) if starts else None


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("target", help="disk image or drive")
    ap.add_argument("--first-lba", type=int, default=34)
    ap.add_argument("--apply", action="store_true", help="write the change (default: only show it)")
    a = ap.parse_args()

    with open(a.target, "r+b" if a.apply else "rb") as f:
        for sector in (512, 4096):
            primary = read_header(f, sector, 1)
            if primary:
                break
        else:
            sys.exit(f"{a.target}: no valid GPT header")
        table_end = primary["entries"] + -(-primary["count"] * primary["esize"] // sector)
        lowest = lowest_partition_start(f, sector, primary)
        if a.first_lba < table_end:
            sys.exit(f"first usable LBA {a.first_lba} would overlap the partition entries (they end at {table_end - 1})")
        if lowest is not None and a.first_lba > lowest:
            sys.exit(f"first usable LBA {a.first_lba} is beyond the first partition (starts at {lowest})")

        headers = [primary]
        backup = read_header(f, sector, primary["alt"])
        if backup:
            headers.append(backup)
        else:
            print(f"backup header at LBA {primary['alt']}: missing or invalid, left alone")
        changed = False
        for h in headers:
            name = "primary" if h is primary else "backup"
            if h["first"] == a.first_lba:
                print(f"{name} header: first usable LBA is already {a.first_lba}")
                continue
            print(f"{name} header (LBA {h['lba']}): first usable LBA {h['first']} -> {a.first_lba}")
            changed = True
            if not a.apply:
                continue
            raw = h["raw"]
            struct.pack_into("<Q", raw, 40, a.first_lba)
            raw[16:20] = b"\0\0\0\0"
            struct.pack_into("<I", raw, 16, zlib.crc32(raw[:h["size"]]) & 0xFFFFFFFF)
            f.seek(h["lba"] * sector)
            f.write(raw)
        if changed and not a.apply:
            print("nothing written; add --apply to change it")
        if a.apply:
            f.flush()


if __name__ == "__main__":
    main()
