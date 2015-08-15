FROM kinsamanka/docker-qemu-chroot:rpi-base

MAINTAINER Stefan Unterhauser <stefan@unterhauser.name>

# Install instructions from https://cwiki.apache.org/confluence/display/COUCHDB/Debian

ENV COUCHDB_VERSION 1.6.1

RUN proot -0 -b /etc/resolv.conf -r /opt/rootfs -q qemu-arm-static /bin/bash -c \
  'groupadd -r couchdb && useradd -d /var/lib/couchdb -g couchdb couchdb'

# download dependencies, compile and install couchdb
RUN proot -0 -b /etc/resolv.conf -r /opt/rootfs -q qemu-arm-static /bin/bash -c \
  'apt-get update -y \
  && apt-get install -y --no-install-recommends \
    build-essential ca-certificates curl \
    libmozjs185-dev libmozjs185-1.0 libnspr4 libnspr4-0d libnspr4-dev libcurl4-openssl-dev libicu-dev \
  && echo deb http://packages.erlang-solutions.com/debian wheezy contrib >> /etc/apt/sources.list \
  && curl -sSL http://packages.erlang-solutions.com/debian/erlang_solutions.asc | apt-key add - && apt-get update \
  && apt-get install -y --no-install-recommends erlang-nox=1:17.1 erlang-dev=1:17.1 \
  && curl -sSL http://apache.openmirror.de/couchdb/source/$COUCHDB_VERSION/apache-couchdb-$COUCHDB_VERSION.tar.gz -o couchdb.tar.gz \
  && curl -sSL https://www.apache.org/dist/couchdb/source/$COUCHDB_VERSION/apache-couchdb-$COUCHDB_VERSION.tar.gz.asc -o couchdb.tar.gz.asc \
  && curl -sSL https://www.apache.org/dist/couchdb/KEYS -o KEYS \
  && gpg --import KEYS && gpg --verify couchdb.tar.gz.asc \
  && mkdir -p /usr/src/couchdb \
  && tar -xzf couchdb.tar.gz -C /usr/src/couchdb --strip-components=1 \
  && cd /usr/src/couchdb \
  && ./configure --with-js-lib=/usr/lib --with-js-include=/usr/include/mozjs \
  && make && make install \
  && apt-get purge -y perl binutils cpp make build-essential libnspr4-dev libcurl4-openssl-dev libicu-dev \
  && apt-get autoremove -y \
  && apt-get update && apt-get install -y libicu48 --no-install-recommends \
  && rm -rf /var/lib/apt/lists/* /usr/src/couchdb /couchdb.tar.gz* /KEYS /esl.deb'

# grab gosu for easy step-down from root
RUN proot -0 -b /etc/resolv.conf -r /opt/rootfs -q qemu-arm-static /bin/bash -c \
  'gpg --keyserver pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
  && curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/1.2/gosu-$(dpkg --print-architecture)" \
  && curl -o /usr/local/bin/gosu.asc -SL "https://github.com/tianon/gosu/releases/download/1.2/gosu-$(dpkg --print-architecture).asc" \
  && gpg --verify /usr/local/bin/gosu.asc \
  && rm /usr/local/bin/gosu.asc \
  && chmod +x /usr/local/bin/gosu'

# permissions
RUN proot -0 -b /etc/resolv.conf -r /opt/rootfs -q qemu-arm-static /bin/bash -c \
  'chown -R couchdb:couchdb \
    /usr/local/lib/couchdb /usr/local/etc/couchdb \
    /usr/local/var/lib/couchdb /usr/local/var/log/couchdb /usr/local/var/run/couchdb \
  && chmod -R g+rw \
    /usr/local/lib/couchdb /usr/local/etc/couchdb \
    /usr/local/var/lib/couchdb /usr/local/var/log/couchdb /usr/local/var/run/couchdb \
  && mkdir -p /var/lib/couchdb'

# Expose to the outside
RUN proot -0 -b /etc/resolv.conf -r /opt/rootfs -q qemu-arm-static /bin/bash -c \
  'sed -e "s/^bind_address = .*$/bind_address = 0.0.0.0/" -i /usr/local/etc/couchdb/default.ini'

COPY ./docker-entrypoint.sh /entrypoint.sh
COPY ./docker-entrypoint.sh /opt/rootfs/entrypoint.sh

# Define mountable directories.
VOLUME ["/usr/local/var/log/couchdb", "/usr/local/var/lib/couchdb"]

EXPOSE 5984
WORKDIR /var/lib/couchdb

ENTRYPOINT ["/entrypoint.sh"]
CMD ["couchdb"]
