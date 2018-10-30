# Docker Container for TravisCI Builds

This directory contains the necessary files to create Docker images used for
building and testing domjudge on TravisCI. This is basically our way to get a
newer environment when running there rather than the ubuntu 14.04 environment
they provide.

## Building the images

If you want to build the images yourself, you can just run

```bash
./build.sh version
```

where `version` is the tag you want docker to assign to the image.
