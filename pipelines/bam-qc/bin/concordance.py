#!/usr/bin/env python3
"""Compare mapped-read counts from samtools flagstat and samtools idxstats.

flagstat's "mapped" line counts every mapped record, including secondary and
supplementary alignments. idxstats column 3 is the mapped count per reference
sequence, read from the BAM index. This script reports both, the difference,
and flagstat's primary-mapped count where samtools provides it (1.13+), so a
reviewer can see which definition explains any gap.
"""

import argparse
import re
import sys


def parse_flagstat(path):
    mapped = primary_mapped = None
    with open(path) as fh:
        for line in fh:
            m = re.match(r"^(\d+) \+ (\d+) (primary )?mapped \(", line)
            if not m:
                continue
            total = int(m.group(1)) + int(m.group(2))
            if m.group(3):
                primary_mapped = total
            elif mapped is None:
                mapped = total
    if mapped is None:
        sys.exit(f"Could not find a 'mapped' line in {path}")
    return mapped, primary_mapped


def parse_idxstats(path):
    mapped = 0
    with open(path) as fh:
        for line in fh:
            cols = line.rstrip("\n").split("\t")
            if len(cols) >= 3:
                mapped += int(cols[2])
    return mapped


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--sample", required=True)
    ap.add_argument("--flagstat", required=True)
    ap.add_argument("--idxstats", required=True)
    args = ap.parse_args()

    fs_mapped, fs_primary = parse_flagstat(args.flagstat)
    idx_mapped = parse_idxstats(args.idxstats)
    diff = fs_mapped - idx_mapped
    status = "concordant" if diff == 0 else "discordant"

    print("\t".join(["sample", "flagstat_mapped", "flagstat_primary_mapped",
                     "idxstats_mapped", "difference", "status"]))
    print("\t".join([args.sample, str(fs_mapped),
                     "NA" if fs_primary is None else str(fs_primary),
                     str(idx_mapped), str(diff), status]))


if __name__ == "__main__":
    main()
