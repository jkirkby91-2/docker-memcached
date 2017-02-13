FROM jkirkby91/ubuntusrvbase:latest

MAINTAINER James Kirkby <jkirkby91@gmail.com>

RUN groupadd -r memcache && useradd -r -g memcache memcache

ENV MEMCACHED_VERSION 1.4.34

ENV MEMCACHED_SHA1 7c7214f5183c6e20c22b243e21ed1ffddb91497e

RUN buildDeps=' \
		gcc \
		libc6-dev \
		make \
		perl \
		wget \
	' \
	&& set -x \
	&& apt-get update && apt-get install -y $buildDeps libevent-dev --no-install-recommends \
	&& rm -rf /var/lib/apt/lists/* \
	&& wget -O memcached.tar.gz "http://memcached.org/files/memcached-$MEMCACHED_VERSION.tar.gz" \
	&& echo "$MEMCACHED_SHA1  memcached.tar.gz" | sha1sum -c - \
	&& mkdir -p /usr/src/memcached \
	&& tar -xzf memcached.tar.gz -C /usr/src/memcached --strip-components=1 \
	&& rm memcached.tar.gz \
	&& cd /usr/src/memcached \
	&& ./configure \
	&& make -j$(nproc) \
	&& make install \
	&& cd / && rm -rf /usr/src/memcached \
	&& apt-get purge -y --auto-remove $buildDeps

COPY docker-entrypoint.sh /usr/local/bin/

RUN ln -s usr/local/bin/docker-entrypoint.sh /entrypoint.sh # backwards compat

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Port to expose (default: 11211)
EXPOSE 11211

# Copy apparmor conf
COPY confs/apparmor/memcached.conf /etc/apparmor.d/memcached.conf

# Copy memcached conf
COPY confs/memcached/memcached.conf /etc/memcached.conf

# Copy supervisor conf
COPY confs/supervisord/supervisord.conf /etc/supervisord.conf

COPY start.sh /start.sh

RUN chmod 777 /start.sh

RUN chown memcache:memcache /srv

VOLUME /srv

WORKDIR /srv

USER memcache

ENTRYPOINT ["docker-entrypoint.sh"]

# Set entrypoint
CMD ["/bin/bash", "/start.sh"]
