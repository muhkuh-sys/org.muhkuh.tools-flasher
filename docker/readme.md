The flasher sources are built with the Muhkuh build system (MBS), CMake and Python.

The easiest way to build the sources is with a docker image based on the 
[MBS docker image](https://github.com/muhkuh-sys/mbs-docker-images) from Muhkuh.

## Linux

On Linux, the MBS build container can be started with the compose-linux.yml file,
which will map the root of the repository to the current working directory.
The Linux user and current working directory will be the same as the host.

To start the container and attach to it, run the following commands from the project root directory:
```
export UID
docker compose -f docker/compose-linux.yml up -d
docker compose -f docker/compose-linux.yml exec build bash
```

To build the flasher, execute the build_artifact.py script from the container interactive shell:
```
python3 build_artifact.py ubuntu 22.04 x86_64
```

## Windows

On Windows, the MBS build container can be started with the compose-windows.yml file,
which will map the root of the repository to a temporary working folder - '/tmp/src'.

To start the container and attach to it, run the following commands from the project root directory:
```
docker compose -f docker/compose-windows.yml up -d
docker compose -f docker/compose-windows.yml exec build bash
```

On Windows, you also have to disable git safe directory.
To do so, run the following command from the container interactive shell
(you need to do this only the first time when the container is created and started):
```
git config --global --add safe.directory /tmp/src
```

To build the flasher, execute the build_artifact.py script from the container interactive shell:
```
python3 build_artifact.py windows x86_64
```