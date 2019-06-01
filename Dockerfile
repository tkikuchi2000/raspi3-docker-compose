# Dockerfile to build docker-compose for aarch64
FROM arm32v7/python:3.6.5-stretch as builder
# Add env
ENV LANG C.UTF-8

# Enable cross-build for aarch64
#EnableQEMU COPY qemu-arm-static /usr/bin
RUN apt-get update && apt-get install -qq --no-install-recommends unzip

# Set the versions
ARG DOCKER_COMPOSE_VER
# docker-compose requires pyinstaller 3.3.1 (check github.com/docker/compose/requirements-build.txt)
# If this changes, you may need to modify the version of "six" below
ENV PYINSTALLER_VER 3.3.1
# "six" is needed for PyInstaller. v1.11.0 is the latest as of PyInstaller 3.3.1
ENV SIX_VER 1.11.0

# Install dependencies
# RUN apt-get update && apt-get install -y
RUN pip install --upgrade pip
RUN pip install six==$SIX_VER

# Compile the pyinstaller "bootloader"
# https://pyinstaller.readthedocs.io/en/stable/bootloader-building.html
WORKDIR /build/pyinstallerbootloader
RUN curl -fsSL https://github.com/pyinstaller/pyinstaller/releases/download/v$PYINSTALLER_VER/PyInstaller-$PYINSTALLER_VER.tar.gz | tar xvz >/dev/null \
    && cd PyInstaller*/bootloader \
    && python3 ./waf all

# Clone docker-compose
WORKDIR /build/dockercompose
RUN curl -fsSL https://github.com/docker/compose/archive/$DOCKER_COMPOSE_VER.zip > $DOCKER_COMPOSE_VER.zip \
    && unzip $DOCKER_COMPOSE_VER.zip

# Run the build steps (taken from github.com/docker/compose/script/build/linux-entrypoint)
RUN cd compose-$DOCKER_COMPOSE_VER && mkdir ./dist \
    && pip install -q -r requirements.txt -r requirements-build.txt

RUN cd compose-$DOCKER_COMPOSE_VER \
    && echo "unknown" > compose/GITSHA \
    && pyinstaller docker-compose.spec \
    && mkdir /dist \
    && mv dist/docker-compose /dist/docker-compose

FROM arm32v7/debian:stretch-slim

COPY --from=builder /dist/docker-compose /tmp/docker-compose

# Copy out the generated binary
RUN mkdir /dist
VOLUME /dist
CMD /bin/cp /tmp/docker-compose /dist/docker-compose
