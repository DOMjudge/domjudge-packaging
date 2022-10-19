#!/usr/bin/python3

import pathlib

dj_source = next(pathlib.Path("/domjudge-src").glob("domjudge*"))
c_run = dj_source / "sql/files/defaultdata/c/run"

with open(c_run) as f:
     lines = f.readlines()

for i in range(len(lines)):
    if lines[i].startswith("gcc"):
        lines[i] = "gcc" + " -std=gnu17" + lines[i][3:]
        break
else:
    print(f"Couldn't find gcc line in {c_run}")
    exit(1)

with open(c_run, "w") as f:
    f.writelines(lines)
