# DOMjudge Docker container for contributors

This directory contains the necessary files to create a Docker image which can be used by DOMjudge maintainers to work on DOMjudge without having to set up a DOMjudge development environment.

The container includes the following:

* A setup script that will:
 * Set up a DOMjudge maintainer installation from a mounted volume.
 * Set up or update the database.
 * Set up the webserver.
 * Create a chroot.
* PHP-FPM and nginx for running the web interface.
* Two running judgedaemons using a chroot.
* Scripts for reading the log files of the webserver and the judgedaemons.
* A script to create a dummy DOMjudge user and submit all test submissions.
* Scripts for enabling and disabling Xdebug.

This container does not include:

* MySQL / MariaDB; the [MariaDB](https://hub.docker.com/r/_/mariadb/) Docker container does this better than we ever could.
* The DOMjudge source code itself. The [DOMjudge repository](https://github.com/domjudge/domjudge) should be cloned on the target machine somewhere and a volume should be created for it.

## Using the image

This image is available on the [Docker Hub](https://hub.docker.com) as `domjudge/domjudge-contributor`.

Before starting the container, make sure you have a MySQL / MariaDB database somewhere. The easiest way to get one up and running is to use the [MariaDB](https://hub.docker.com/r/_/mariadb/) Docker container:

```bash
docker run -it --name dj-mariadb -e MYSQL_ROOT_PASSWORD=rootpw -e MYSQL_USER=domjudge -e MYSQL_PASSWORD=djpw -e MYSQL_DATABASE=domjudge -p 13306:3306 mariadb --max-connections=1000
```

This will start a MariaDB container, set the root password to `rootpw`, create a MySQL user named `domjudge` with password `djpw` and create an empty database named `domjudge`. It will also expose the server on port `13306` on your local machine, so you can use your favorite MySQL GUI to connect to it. If you want to save the MySQL data after removing the container, please read the [MariaDB](https://hub.docker.com/r/_/mariadb/) Docker Hub page for more information.

Next, if you are on Linux make sure you have cgroups enabled. See the [DOMjudge documentation about setting up a judgehost](https://www.domjudge.org/docs/manual/master/install-judgehost.html#linux-control-groups) for information about how to do this. Docker on Windows and macOS actually use a small Linux VM which already has these options set.

Now you can run DOMjudge itself using the following command:

```bash
docker run -v [path-to-domjudge-checkout]:/domjudge -v /sys/fs/cgroup:/sys/fs/cgroup:ro --link dj-mariadb:mariadb -it -e MYSQL_HOST=mariadb -e MYSQL_USER=domjudge -e MYSQL_DATABASE=domjudge -e MYSQL_PASSWORD=djpw -e MYSQL_ROOT_PASSWORD=rootpw -p 12345:80 --name domjudge --privileged domjudge/domjudge-contributor
```

Make sure you replace `[path-to-domjudge-checkout]` with the path to your local DOMjudge checkout. On recent macOS and Windows Docker builds, you should add `:cached` at the end of the `/domjudge` volume (i.e. `-v [path-to-domjudge-checkout]:/domjudge:cached`) to speed up the webserver a lot.

The above command will start the container, set up DOMjudge for a maintainer install, set up the database and create a chroot to be used by the judgedaemons. It will then start nginx, PHP-FPM and two judgedaemons using supervisord.

You can now access the web interface on [http://localhost:12345/](http://localhost:12345/). Use username `admin` and the password from `etc/initial_admin_password.secret` to log in. Note that for DOMjudge 6.0.0 and higher the webserver configuration will be set up such that the debug front controller will be used.

### Environment variables

The following environment variables are supported by the container:

* `CONTAINER_TIMEZONE` (defaults to `Europe/Amsterdam`): allows you to change the timezone used inside the container.
* `MYSQL_HOST` (defaults to `mariadb`): set the host to connect to for MySQL. Can be hostname or IP. Docker will add hostnames for any containers you `--link`, so in the example above, the MariaDB container will be available under the hostname `mariadb`.
* `MYSQL_USER` (defaults to `domjudge`): set the user to use for connecting to MySQL.
* `MYSQL_PASSWORD` (defaults to `domjudge`): set the password to use for connecting to MySQL.
* `MYSQL_ROOT_PASSWORD` (defaults to `domjudge`): set the root password to use for connecting to MySQL.
* `MYSQL_DATABASE` (defaults to `domjudge`): set the database to use.
* `FPM_MAX_CHILDREN` (defaults to `40`): the maximum number of PHP FPM children to spawn.
* `DJ_SKIP_MAKE` (defaults to `0`): set to `1` to skip the maintainer setup and install commands. This will speed up the startup process of the container and is useful if this is already done before.
* `DJ_DB_INSTALL_BARE` (defaults to `0`): set to `1` to do a `bare-install` for the database instead of a normal `install`.

#### Passwords through files

In order to not specify sensitive information through environment variables, the variables `MYSQL_PASSWORD_FILE` and `MYSQL_ROOT_PASSWORD_FILE` can be used to set a path to a file to read the passwords from. This is suitable to use together with [docker compose's secrets](https://docs.docker.com/compose/compose-file/#secrets-configuration-reference):

```yml
...
services:
    domjudge-contributor:
        image: domjudge/domjudge-contributor:${DOMJUDGE_VERSION}
        secrets:
            - domjudge-mysql-pw
        ...
        environment:
            MYSQL_PASSWORD_FILE: /run/secrets/domjudge-mysql-pw
        ...
```

### Commands

This container supports a few commands. You can run all commands using the following syntax:

```bash
docker exec -it domjudge [command]
```

If you have named your container something other than `domjudge`, be sure to change it in the command as well.

The following commands are available:

* `nginx-access-log`: tail the access log of nginx.
* `nginx-error-log`: tail the error log of nginx.
* `judgedaemon-log 0` and `judgedaemon-log 1`: tail the log of the first / second judgeaemon.
* `symfony-log`: for DOMjudge using Symfony (i.e. 6.x and higher), tail the symfony log.
* `submit-test-programs`: submit all test programs (by executing `make check test-stress` in the `tests` directory of the DOMjudge installation. This will also add a `dummy` user to your database if it does not exist yet. It's password will be set to `dummy`.
* `xdebug-enable`: enable Xdebug debugging. See note below
* `xdebug-disable`: disable Xdebug debugging. See note below
* `switch-php <version>`: switch to using the given PHP version.

Of course, you can always run `docker exec -it domjudge bash` to get a bash shell inside the container.

To restart any of the services, run the following:

```bash
docker exec -it domjudge supervisorctl restart [service]
```

where `[service]` is one of `nginx`, `php`, `judgedaemon0` or `judgedaemon1`.

### Xdebug

Xdebug is not enabled by default, because it will slow down requests quite a bit. You can enable it by running `docker-compose exec xdebug-enable` and disable it again
by running `docker-compose exec xdebug-disable`.

Xdebug has the following settings:

* `xdebug.remote_autostart=1`: such that you do not have to set a cookie or GET parameter to start debugging.
* `xdebug.remote_enable=1`: enable remote debugging.
* `xdebug.remote_host=host.docker.internal`: connect to the Docker host for debugging.
* `xdebug.idekey=IDE`: the IDE key to use; you should set this in your IDE of choice.

### Accessing the judgings

Because the chroot script copies some special devices into every chroot used for judging and Docker does not support having these special devices on volumes, a bind-mount is created for `/domjudge/output/judgings`. Thus, if you want to access the contents of this directory, use `docker exec -it domjudge bash` to get access into the container and go to that directory.

## Building the image

If you want to build the image yourself, you can just run

```bash
docker build -t domjudge/domjudge-contributor .
```

inside this directory.
