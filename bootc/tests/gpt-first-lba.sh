#!/usr/bin/env bash
# gpt-first-lba.py on a table laid out like bootc-image-builder's: the field changes, nothing else does.
set -euo pipefail
PATH=$PATH:/usr/sbin:/sbin
T=$(cd "$(dirname "$0")/../tools" && pwd)/gpt-first-lba.py
D=$(mktemp -d); trap 'rm -rf "$D"' EXIT
truncate -s 600M "$D/a.img"
printf 'label: gpt\nfirst-lba: 2048\nstart=2048, size=2048, type=21686148-6449-6E6F-744E-656564454649\nsize=200M, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B\nsize=100M, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4\ntype=0FC63DAF-8483-4772-8E79-3D69D8477DE4\n' | sfdisk -q "$D/a.img"
cp "$D/a.img" "$D/orig.img"
fail=0; check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$2', want '$3'"; fail=1; fi; }
parts() { sfdisk -d "$1" | grep -E "^$1[0-9]" | sed 's/, uuid=.*//; s/, name=.*//'; }
first() { sfdisk -d "$1" | sed -n 's/^first-lba: //p'; }
before=$(parts "$D/a.img")
python3 "$T" "$D/a.img" > /dev/null
check "a dry run writes nothing" "$(cmp -s "$D/a.img" "$D/orig.img" && echo same)" same
python3 "$T" "$D/a.img" --apply > /dev/null
check "first usable LBA is 34" "$(first "$D/a.img")" 34
check "partitions unchanged" "$(parts "$D/a.img")" "$before"
check "sfdisk accepts the table" "$(sfdisk --verify "$D/a.img" > /dev/null 2>&1 && echo yes)" yes
check "twelve bytes changed" "$(cmp -l "$D/a.img" "$D/orig.img" | wc -l)" 12
check "refuses a value inside the entries" "$(python3 "$T" "$D/a.img" --first-lba 10 > /dev/null 2>&1 || echo refused)" refused
check "refuses a value past the first partition" "$(python3 "$T" "$D/a.img" --first-lba 5000 > /dev/null 2>&1 || echo refused)" refused
cp "$D/orig.img" "$D/big.img"; truncate -s 900M "$D/big.img"   # flashed to a bigger drive: backup header mid-disk
python3 "$T" "$D/big.img" --apply > /dev/null
check "works with the backup header mid-disk" "$(first "$D/big.img" 2>/dev/null)" 34
python3 "$T" "$D/a.img" --first-lba 2048 --apply > /dev/null
check "undo restores every byte" "$(cmp -s "$D/a.img" "$D/orig.img" && echo same)" same
exit $fail
