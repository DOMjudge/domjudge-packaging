-- These are extra DOMjudge-live entries for the DOMjudge database.
--
-- You can pipe this file into the 'mysql' command to insert this
-- data, but preferably use 'dj-setup-database'. Database should be set
-- externally (e.g. to 'domjudge').


UPDATE `language` SET `allow_submit` = 1 WHERE `langid` IN ('adb', 'awk', 'bash', 'csharp', 'f95', 'hs', 'lua', 'pas', 'pl', 'py', 'py2', 'py3', 'sh');

