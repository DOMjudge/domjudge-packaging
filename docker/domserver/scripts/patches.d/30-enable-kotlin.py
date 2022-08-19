#!/usr/bin/python3

import pathlib

dj_source = next(pathlib.Path("/domjudge-src").glob("domjudge*"))
language_fixture_php = dj_source / "webapp/src/DataFixtures/DefaultData/LanguageFixture.php"

with open(language_fixture_php, "r") as f:
     lines = f.readlines()

for i in range(len(lines)):
    if lines[i] == "            ['kt',     'kotlin',     'Kotlin',      ['kt'],                      true,  'Main class', false,  true,   1,     'kt'],\n":
        lines[i] = "            ['kt',     'kotlin',     'Kotlin',      ['kt'],                      true,  'Main class', true,   true,   1,     'kt'],\n"
        break
else:
    print(f"Couldn't find kotlin line in {language_fixture_php}")
    exit(1)

with open(language_fixture_php, "w") as f:
    f.writelines(lines)
