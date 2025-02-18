# system-post-install

Run script interactively after a fresh system installation.

> [!IMPORTANT]
> This repository's intention is purely personal. You can, however, fork it and
> use it as a template/starter-pack to build your own. If you do, I'm interested
> in your feedbacks.

## Features

- detect operating system and install software accordingly
- one script to run them all. *Allows to simply curl this script to run all*
- install software, ...

> [!NOTE]
> Most of the magic is in branches. Each branch corresponding to one supported
> distribution/version.

## Usage

```shell
wget --quiet https://raw.githubusercontent.com/juliendufresne/system-post-install/refs/heads/main/bootstrap
# or
# curl -fsSL https://raw.githubusercontent.com/juliendufresne/system-post-install/refs/heads/main/bootstrap
chmod u+x bootstrap
./bootstrap
rm bootstrap
```

## Development

```bash
# from project root dir
docker build --build-arg image=ubuntu:noble -t system-install docker
# or 
#docker build --build-arg image=fedora:latest -t system-install docker
docker run -it --rm -v .:/app system-install bash
```
