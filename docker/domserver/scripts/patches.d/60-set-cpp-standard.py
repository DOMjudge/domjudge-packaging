#!/usr/bin/python3

import pathlib

dj_source = next(pathlib.Path("/domjudge-src").glob("domjudge*"))
cpp_run = dj_source / "sql/files/defaultdata/cpp/run"

with open(cpp_run) as f:
     lines = f.readlines()

for i in range(len(lines)):
    if lines[i].startswith("g++"):
        lines[i] = "g++" + " -std=gnu++20" + lines[i][3:]
        break
else:
    print(f"Couldn't find g++ line in {cpp_run}")
    exit(1)

with open(cpp_run, "w") as f:
    f.writelines(lines)
