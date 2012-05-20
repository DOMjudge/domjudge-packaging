-- Clean up DOMjudge remains that dbconfig-common doesn't clean
-- automatically

-- In MySQL < 5.0.2, 'DROP USER' only removes the user, not its privileges:
REVOKE ALL PRIVILEGES, GRANT OPTION FROM
	'domjudge_jury'@'localhost',
	'domjudge_jury'@'%';
DROP USER 
	'domjudge_jury'@'localhost',
	'domjudge_jury'@'%';

FLUSH PRIVILEGES;
