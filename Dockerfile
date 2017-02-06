FROM jkirkby91/ubuntusrvbase:latest

MAINTAINER James Kirkby <jkirkby91@gmail.com>

RUN groupadd -r memcache && useradd -r -g memcache memcache

# Install packages specific to our project
RUN apt-get update && \
apt-get upgrade -y && \
apt-get install libevent-2.0-5 wget -y --force-yes --fix-missing --no-install-recommends && \
apt-get remove --purge -y software-properties-common build-essential  && \
apt-get autoremove -y && \
apt-get clean && \
apt-get autoclean && \
echo -n > /var/lib/apt/extended_states && \
rm -rf /var/lib/apt/lists/* && \
rm -rf /usr/share/man/?? && \
rm -rf /usr/share/man/??_*

# grab gosu for easy step-down from root
ENV GOSU_VERSION 1.7

RUN set -x \
	&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
	&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
	&& gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
	&& rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu \
	&& gosu nobody true

ENV MEMCACHED_VERSION 1.4.34

ENV MEMCACHED_SHA1 7c7214f5183c6e20c22b243e21ed1ffddb91497e

RUN buildDeps=' \
		gcc \
		libc6-dev \
		libevent-dev \
		make \
		perl \
		wget \
	' \
	&& set -x \
	&& apt-get update && apt-get install -y $buildDeps --no-install-recommends \
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

ENTRYPOINT ["docker-entrypoint.sh"]

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Port to expose (default: 11211)
EXPOSE 11211

# Copy apparmor conf
COPY confs/apparmor/memcached.conf /etc/apparmor/memcached.conf

# Copy memcached conf
COPY confs/memcached/memcached.conf /etc/memcached.conf

# Copy supervisor conf
COPY confs/supervisord/supervisord.conf /etc/supervisord.conf

COPY start.sh /start.sh

RUN chmod 777 /start.sh

RUN mkdir /data && chown memcache:memcache /data

VOLUME /data

WORKDIR /data

USER memcache

# Set entrypoint
CMD ["/bin/bash", "/start.sh"]
