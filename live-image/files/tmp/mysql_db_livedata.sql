-- These are extra DOMjudge-live entries for the DOMjudge database.
--
-- You can pipe this file into the 'mysql' command to insert this
-- data, but preferably use 'dj-setup-database'. Database should be set
-- externally (e.g. to 'domjudge').

-- Enable most languages available:
UPDATE `language` SET `allow_submit` = 1 WHERE `langid` IN ('adb', 'awk', 'bash', 'csharp', 'f95', 'pas', 'pl', 'py', 'py2', 'py3', 'sh');

-- Associate admin user to team 'DOMjudge':
REPLACE INTO `userrole` (`userid`, `roleid`)
  SELECT `userid`, `roleid` FROM `user` INNER JOIN `role`
  WHERE `username` = 'admin' AND `role` = 'team';

UPDATE `user`, `team` SET `user`.`teamid` = `team`.`teamid`
  WHERE `user`.`username` = 'admin' AND `team`.`name` = 'DOMjudge';

-- Reduce low disk space warning, since we don't have much by default:
UPDATE `configuration` SET `value` = '131072'
  WHERE `name` = 'diskspace_error';

