#!/usr/bin/env sh

# directory/volumes where your code should be
if [ -d /app ]
then
    # directory where to copy it to have the right
    if [ -n "$( ls -A /home/appuser/app )" ]
    then
        rm -r /home/appuser/app/.* /home/appuser/app/*
    fi
    cp -r /app/ /home/appuser/
fi

exec "$@"
