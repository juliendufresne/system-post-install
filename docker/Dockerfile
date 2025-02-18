ARG image=ubuntu:noble
#ARG image=fedora:latest
FROM $image

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN <<EOF
set -eux
declare sudogroup=sudo
if command -v apt-get &>/dev/null
then
    apt-get -qq -y --update --no-install-recommends install sudo
    rm -r /var/lib/apt/lists/*
elif command -v dnf &>/dev/null
then
    sudogroup=wheel
    dnf -q -y --refresh install sudo
elif command -v yum &>/dev/null
then
    sudogroup=wheel
    yum -q -y --refresh install sudo
fi

declare user=appuser

groupadd $user
useradd --create-home --home-dir /home/$user --gid $user --groups $sudogroup --shell /bin/bash $user
# username:password
echo "$user:a" | chpasswd
EOF

# must correspond to the $user in the script above
USER appuser

VOLUME /app

RUN mkdir /home/appuser/app
WORKDIR /home/appuser/app

COPY --link --chown=appuser:appuser --chmod=755 docker-entrypoint.sh /home/appuser/docker-entrypoint.sh

ENTRYPOINT ["/home/appuser/docker-entrypoint.sh"]

CMD ["/bin/bash"]
