# DOMjudge Docker containers

This directory contains the necessary files to create Docker images which can be used to run DOMjudge

There is one container for running the domserver and one for running a judgehost.

The domserver container contains:

* A setup script that will:
 * Set up or update the database.
 * Set up the webserver.
* PHP-FPM and nginx for running the web interface.
* Scripts for reading the log files of the webserver.

The judgehost container contains a working judgehost with cgroup support and a chroot for running the submissions. C, C++ and Java are currently supported.

These containers do not include MySQL / MariaDB; the [MariaDB](https://hub.docker.com/r/_/mariadb/) Docker container does this better than we ever could.

## Using the images

These images are available on the [Docker Hub](https://hub.docker.com) as `domjudge/domserver` and `domjudge/judgehost`.

### MariaDB container

Before starting the containers, make sure you have a MySQL / MariaDB database somewhere. The easiest way to get one up and running is to use the [MariaDB](https://hub.docker.com/r/_/mariadb/) Docker container:

```bash
docker run -it --name dj-mariadb -e MYSQL_ROOT_PASSWORD=rootpw -e MYSQL_USER=domjudge -e MYSQL_PASSWORD=djpw -e MYSQL_DATABASE=domjudge -p 13306:3306 mariadb --max-connections=1000
```

This will start a MariaDB container, set the root password to `rootpw`, create a MySQL user named `domjudge` with password `djpw` and create an empty database named `domjudge`. It will also expose the server on port `13306` on your local machine, so you can use your favorite MySQL GUI to connect to it. If you want to save the MySQL data after removing the container, please read the [MariaDB](https://hub.docker.com/r/_/mariadb/) Docker Hub page for more information.

### DOMserver container

Next, if you are on Linux make sure you have cgroups enabled. See the [DOMjudge documentation about setting up a judgehost](https://www.domjudge.org/docs/admin-manual-3.html#ss3.7) for information about how to do this. Docker on Windows and macOS actually use a small Linux VM which already has these options set.

Now you can run the domserver using the following command:

```bash
docker run --link dj-mariadb:mariadb -it -e MYSQL_HOST=mariadb -e MYSQL_USER=domjudge -e MYSQL_DATABASE=domjudge -e MYSQL_PASSWORD=djpw -e MYSQL_ROOT_PASSWORD=rootpw -p 12345:80 --name domserver domjudge/domserver:latest
```

If you want a specific DOMjudge version instead of the latest, replace `latest` with the DOMjudge version (e.g. `5.3.0`).

The above command will start the container and set up the database. It will then start nginx and PHP-FPM using supervisord.

You can now access the web interface on [http://localhost:12345/](http://localhost:12345/). Use username `admin` and password `admin` to log in. Note that for DOMjudge 6.0.0 and higher the webserver configuration will be set up such that the debug front controller will be used.

Make sure you change the password of the `judgehost` account in the webinterface to something and write down the value.

#### Environment variables

The following environment variables are supported by the `domserver` container:

* `CONTAINER_TIMEZONE` (defaults to `Europe/Amsterdam`): allows you to change the timezone used inside the container.
* `MYSQL_HOST` (defaults to `mariadb`): set the host to connect to for MySQL. Can be hostname or IP. Docker will add hostnames for any containers you `--link`, so in the example above, the MariaDB container will be available under the hostname `mariadb`.
* `MYSQL_USER` (defaults to `domjudge`): set the user to use for connecting to MySQL.
* `MYSQL_PASSWORD` (defaults to `domjudge`): set the password to use for connecting to MySQL.
* `MYSQL_ROOT_PASSWORD` (defaults to `domjudge`): set the root password to use for connecting to MySQL.
* `MYSQL_DATABASE` (defaults to `domjudge`): set the database to use.
* `DJ_DB_INSTALL_BARE` (defaults to `0`): set to `1` to do a `bare-install` for the database instead of a normal `install`.

#### Passwords through files

In order to not specify sensitive information through environment variables, the variables `MYSQL_PASSWORD_FILE` and `MYSQL_ROOT_PASSWORD_FILE` can be used to set a path to a file to read the passwords from. This is suitable to use together with [docker compose's secrets](https://docs.docker.com/compose/compose-file/#secrets-configuration-reference):

```yml
...
services:
    domserver:
        image: domjudge/domserver:${DOMJUDGE_VERSION}
        secrets:
            - domjudge-mysql-pw
        ...
        environment:
            MYSQL_PASSWORD_FILE: /run/secrets/domjudge-mysql-pw
        ...
```

#### Commands

The `domserver` container supports a few commands. You can run all commands using the following syntax:

```bash
docker exec -it domserver [command]
```

If you have named your container something other than `domserver`, be sure to change it in the command as well.

The following commands are available:

* `nginx-access-log`: tail the access log of nginx.
* `nginx-error-log`: tail the error log of nginx.
* `symfony-log`: for DOMjudge using Symfony (i.e. 6.x and higher), tail the symfony log.

Of course, you can always run `docker exec -it domserver bash` to get a bash shell inside the container.

To restart any of the services, run the following:

```bash
docker exec -it domserver supervisorctl restart [service]
```

where `[service]` is one of `nginx` or `php`,


### Judgehost container

To run a single judgehost, run the following command:

```bash
docker run -it --privileged -v /sys/fs/cgroup:/sys/fs/cgroup:ro --name judgehost-0 --link domserver:domserver --hostname judgedaemon-0 -e DAEMON_ID=0 domjudge/judgehost:latest
```

Again, replace `latest` with a specific version if desired. Make sure the version matches the version of the domserver.

This will start up a judgehost that is locked to the first CPU core of your machine.

If the judgedaemon stops for whatever reason, you should be able to see the error it produced in the shell where you started the judgehost. If you want to restart the judgehost, run `docker start judgehost-0`, where `judgehost-0` is the value you passed to `--name` in the `docker run` command.

#### Environment variables

The following environment variables are supported by the `judgehost` container:

* `CONTAINER_TIMEZONE` (defaults to `Europe/Amsterdam`): allows you to change the timezone used inside the container.
* `DOMSERVER_BASEURL` (defaults to `http://domserver/`): base URL where the domserver can be found. The judgehost uses this to connect to the API. **Do not add `api` yourself, as the container will do this!**
* `JUDGEDAEMON_USERNAME` (defaults to `judgehost`): username used to connect to the API.
* `JUDGEDAEMON_PASSWORD` (defaults to `password`): password used to connect to the API. This should be the value of the `judgehost` password you wrote down earlier. Like with the mysql passwords, you can also set `JUDGEDAEMON_PASSWORD_FILE` to a path containing the password instead.
* `DAEMON_ID` (defaults to `0`): ID of the daemon to use for this judgedaemon. If you start multiple judgehosts on one (physical) machine, make sure each one has a different `DAEMON_ID`.
* `FPM_MAX_CHILDREN` (defaults to `40`): the maximum number of PHP FPM children to spawn.

## Building the images

If you want to build the images yourself, you can just run

```bash
./build.sh version
```

where `version` is the DOMjudge version to create the images for, e.g. `5.3.0`.
