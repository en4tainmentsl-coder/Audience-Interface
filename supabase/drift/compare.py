#!/usr/bin/env python3
"""Compare two catalog snapshots produced by snapshot.sql.

usage: compare.py REBUILT.csv LIVE.csv

Exits 1 if the two databases differ in behaviour.

Counted but not failed, because they are text and not behaviour:
  * function bodies that differ only in comments, whitespace, case or CRLF
  * the MAINTAIN table privilege ('m'), which exists from Postgres 17 only

Listed for a human to read, and not failed: expressions that differ only in
their parentheses. Postgres 16 and 17 print nested ANDs differently, so this
is expected when the two databases are different major versions -- but
parentheses can carry meaning, so these are shown rather than dismissed.
"""
import csv
import re
import sys

csv.field_size_limit(10**9)


def load(path):
    with open(path, newline="") as f:
        return {(k, key): val for k, key, val in csv.reader(f)}


def normalise(kind, val):
    val = val or ""
    if kind == "relacl":
        val = re.sub(r"=([A-Za-z]*)", lambda m: "=" + m.group(1).replace("m", ""), val)
    return val


def parens_only(a, b):
    strip = lambda v: re.sub(r"[()\s]", "", v or "")
    return strip(a) == strip(b)


def main():
    rebuilt, live = load(sys.argv[1]), load(sys.argv[2])
    real, review, text_only = [], [], 0
    for kk in sorted(set(rebuilt) | set(live)):
        kind = kk[0]
        if kk not in rebuilt:
            real.append(f"LIVE ONLY     {kind:10} {kk[1]}\n    {live[kk][:300]}")
        elif kk not in live:
            real.append(f"REBUILD ONLY  {kind:10} {kk[1]}\n    {rebuilt[kk][:300]}")
        elif rebuilt[kk] != live[kk]:
            if kind == "functext" or normalise(kind, rebuilt[kk]) == normalise(kind, live[kk]):
                text_only += 1
            elif kind in ("constraint", "policy", "view") and parens_only(rebuilt[kk], live[kk]):
                review.append(f"{kind:10} {kk[1]}\n    live:    {live[kk][:300]}\n    rebuild: {rebuilt[kk][:300]}")
            else:
                real.append(
                    f"DIFFERENT     {kind:10} {kk[1]}\n    live:    {live[kk][:300]}\n    rebuild: {rebuilt[kk][:300]}"
                )
    print(f"{len(set(rebuilt) | set(live))} objects compared, {text_only} differ in text only")
    if review:
        print(f"\n{len(review)} differ only in parentheses -- read them:\n")
        print("\n".join(review))
    if real:
        print(f"{len(real)} REAL DIFFERENCES:\n")
        print("\n".join(real))
        sys.exit(1)
    print("No difference in behaviour.")


if __name__ == "__main__":
    main()
