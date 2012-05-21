<?php
	if (!include($credfile)) {
		user_error("Cannot read database credentials file " . $credfile,
			E_USER_ERROR);
	}

	global $DB;

	$DB = new db ($dbname, $dbserver, $dbuser, $dbpass);

	$DB->q('SET NAMES %s', DJ_CHARACTER_SET_MYSQL);
