FROM ghcr.io/muhkuh-sys/mbs_ubuntu_2204_x86_64:latest

ARG USER=user
ARG UID=1000

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y python-is-python3 python3-pip \
    && python3 -m pip install gitpython

# Add our own user with our own user id
RUN useradd -u ${UID} -ms /bin/bash ${USER} \
    && passwd -d ${USER} \
    && adduser ${USER} sudo

USER ${USER}
WORKDIR /home/${USER}