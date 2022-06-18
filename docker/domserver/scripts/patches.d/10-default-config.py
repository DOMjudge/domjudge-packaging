#!/usr/bin/python3

import yaml
import pathlib

dj_source = next(pathlib.Path("/domjudge-src").glob("domjudge*"))
config = dj_source / "etc/db-config.yaml"

with open(config) as f:
     list_doc = yaml.safe_load(f)

for category in list_doc:
    if category["category"] == "Authentication":
        for item in category["items"]:
            if item["name"] == "auth_methods":
                 item["default_value"].append("xheaders")

    if category["category"] == "External systems":
        for item in category["items"]:
            if item["name"] == "print_command":
                 item["default_value"] = "/usr/bin/enscript --columns=2 --pages=-10 --landscape --pretty-print  \"--header='[original]'; page $% of $=; time=$C; room='[location]'; team='[teamname]'\" [file]"

with open(config, "w") as f:
    yaml.dump(list_doc, f)
