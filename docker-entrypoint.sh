#!/bin/sh
set -e

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
	set -- memcached "$@"
fi

# allow the container to be started with `--user`
if [ "$1" = 'memcached' -a "$(id -u)" = '0' ]; then
	chown -R memcache .
	exec gosu memcache "$0" "$@"
fi

exec "$@"