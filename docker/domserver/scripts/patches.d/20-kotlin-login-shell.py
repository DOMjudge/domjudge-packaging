#!/usr/bin/python3

import pathlib

# dj_source = next(pathlib.Path("/domjudge-src").glob("domjudge*"))
# kt_run = dj_source / "sql/files/defaultdata/kt/run"
kt_run = pathlib.Path("run")

with open(kt_run) as f:
     lines = f.readlines()

for i in range(len(lines)):
    if lines[i] == "#!/bin/sh\n":
        lines[i] = lines[i] + ". /etc/profile.d/kotlin.sh\n"

with open(kt_run, "w") as f:
    f.writelines(lines)
