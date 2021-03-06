# daemon runs in the background
# run something like tail /var/log/blocd/current to see the status
# be sure to run with volumes, ie:
# docker run -v $(pwd)/blocd:/var/lib/blocd -v $(pwd)/wallet:/home/bloc --rm -ti bloc:0.2.2
ARG base_image_version=0.10.0
FROM phusion/baseimage:$base_image_version

ADD https://github.com/just-containers/s6-overlay/releases/download/v1.21.2.2/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C /

ADD https://github.com/just-containers/socklog-overlay/releases/download/v2.1.0-0/socklog-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/socklog-overlay-amd64.tar.gz -C /

ARG BLOC_BRANCH=master
ENV BLOC_BRANCH=${BLOC_BRANCH}

# install build dependencies
# checkout the latest tag
# build and install
RUN apt-get update && \
    apt-get install -y \
      build-essential \
      python-dev \
      gcc-4.9 \
      g++-4.9 \
      git cmake \
      libboost1.58-all-dev && \
    git clone https://github.com/furiousteam/BLOC.git /src/bloc && \
    cd /src/bloc && \
    git checkout $BLOC_BRANCH && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_CXX_FLAGS="-g0 -Os -fPIC -std=gnu++11" .. && \
    make -j$(nproc) && \
    mkdir -p /usr/local/bin && \
    cp src/BLOCd /usr/local/bin/BLOCd && \
    cp src/walletd /usr/local/bin/walletd && \
    cp src/zedwallet /usr/local/bin/zedwallet && \
    cp src/miner /usr/local/bin/miner && \
    strip /usr/local/bin/BLOCd && \
    strip /usr/local/bin/walletd && \
    strip /usr/local/bin/zedwallet && \
    strip /usr/local/bin/miner && \
    cd / && \
    rm -rf /src/bloc && \
    apt-get remove -y build-essential python-dev gcc-4.9 g++-4.9 git cmake libboost1.58-all-dev librocksdb-dev && \
    apt-get autoremove -y && \
    apt-get install -y  \
      libboost-system1.58.0 \
      libboost-filesystem1.58.0 \
      libboost-thread1.58.0 \
      libboost-date-time1.58.0 \
      libboost-chrono1.58.0 \
      libboost-regex1.58.0 \
      libboost-serialization1.58.0 \
      libboost-program-options1.58.0 \
      libicu55

# setup the blocd service
RUN useradd -r -s /usr/sbin/nologin -m -d /var/lib/blocd blocd && \
    useradd -s /bin/bash -m -d /home/bloc bloc && \
    mkdir -p /etc/services.d/blocd/log && \
    mkdir -p /var/log/blocd && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/blocd/run && \
    echo "fdmove -c 2 1" >> /etc/services.d/blocd/run && \
    echo "cd /var/lib/blocd" >> /etc/services.d/blocd/run && \
    echo "export HOME /var/lib/blocd" >> /etc/services.d/blocd/run && \
    echo "s6-setuidgid blocd /usr/local/bin/BLOCd" >> /etc/services.d/blocd/run && \
    chmod +x /etc/services.d/blocd/run && \
    chown nobody:nogroup /var/log/blocd && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/blocd/log/run && \
    echo "s6-setuidgid nobody" >> /etc/services.d/blocd/log/run && \
    echo "s6-log -bp -- n20 s1000000 /var/log/blocd" >> /etc/services.d/blocd/log/run && \
    chmod +x /etc/services.d/blocd/log/run && \
    echo "/var/lib/blocd true blocd 0644 0755" > /etc/fix-attrs.d/blocd-home && \
    echo "/home/bloc true bloc 0644 0755" > /etc/fix-attrs.d/bloc-home && \
    echo "/var/log/blocd true nobody 0644 0755" > /etc/fix-attrs.d/blocd-logs

VOLUME ["/var/lib/blocd", "/home/bloc","/var/log/blocd"]

ENTRYPOINT ["/init"]
CMD ["/usr/bin/execlineb", "-P", "-c", "emptyenv cd /home/bloc export HOME /home/bloc s6-setuidgid bloc /bin/bash"]
