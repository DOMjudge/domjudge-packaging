<?php
	if (!include($credfile)) {
		user_error("Cannot read database credentials file " . $credfile,
			E_USER_ERROR);
	}

	global $DB;

	$DB = new db ($dbname, $dbserver, $dbuser, $dbpass, null, DJ_MYSQL_CONNECT_FLAGS);
