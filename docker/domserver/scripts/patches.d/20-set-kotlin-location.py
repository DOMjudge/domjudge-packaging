#!/usr/bin/python3

import pathlib

dj_source = next(pathlib.Path("/domjudge-src").glob("domjudge*"))
kt_run = dj_source / "sql/files/defaultdata/kt/run"

with open(kt_run) as f:
     lines = f.readlines()

for i in range(len(lines)):
    if lines[i].startswith("KOTLIN_DIR="):
        lines[i] = "# " + lines[i]

for i in range(len(lines)):
    if lines[i].startswith("# KOTLIN_DIR=/usr/lib/kotlinc/bin"):
        lines[i] = lines[i][2:]
        break
else:
    print(f"Couldn't find KOTLIN_DIR line in {kt_run}")
    exit(1)

with open(kt_run, "w") as f:
    f.writelines(lines)
