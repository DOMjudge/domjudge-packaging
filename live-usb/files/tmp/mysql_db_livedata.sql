-- These are extra DOMjudge-live entries for the DOMjudge database.
--
-- You can pipe this file into the 'mysql' command to insert this
-- data, but preferably use 'dj-setup-database'. Database should be set
-- externally (e.g. to 'domjudge').


INSERT INTO `judgehost` (`hostname`, `active`) VALUES ('domjudge-live', 1);

UPDATE `language` SET `allow_submit` = 1 WHERE `langid` IN ('awk', 'hs', 'pas', 'pl', 'sh');

UPDATE `team` SET `authtoken` = MD5('domjudge#domjudge') WHERE `login` = 'domjudge';
