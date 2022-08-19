#!/usr/bin/python3

import pathlib

dj_source = next(pathlib.Path("/domjudge-src").glob("domjudge*"))
user_fixture_php = dj_source / "webapp/src/DataFixtures/DefaultData/UserFixture.php"

with open(user_fixture_php, "r") as f:
     lines = f.readlines()

for i in range(len(lines)):
    if lines[i] == "                ->setUsername('admin')\n":
        lines[i] = "                ->setUsername('admin')->setTeam($this->getReference(TeamFixture::DOMJUDGE_REFERENCE))\n"
        break
else:
    print(f"Couldn't find admin line in {user_fixture_php}")
    exit(1)

with open(user_fixture_php, "w") as f:
    f.writelines(lines)
