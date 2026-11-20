# Swiftファイルの括弧バランス簡易チェック
import os
import re

ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Sources")

ok = True
for dirpath, _, files in os.walk(ROOT):
    for fn in sorted(files):
        if not fn.endswith(".swift"):
            continue
        path = os.path.join(dirpath, fn)
        src = open(path, encoding="utf-8").read()
        s = re.sub(r"//[^\n]*", "", src)
        s = re.sub(r'"(?:[^"\\]|\\.)*"', '""', s)
        pairs = {"{": "}", "(": ")", "[": "]"}
        line = fn + ": "
        good = True
        for o, c in pairs.items():
            a, b = s.count(o), s.count(c)
            if a != b:
                good = False
            line += f"{o}{a}/{c}{b} "
        if not good:
            ok = False
        print(("OK " if good else "NG "), line)
print("---")
print("ALL BALANCED" if ok else "IMBALANCE FOUND")
