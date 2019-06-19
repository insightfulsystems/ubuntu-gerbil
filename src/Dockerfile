ARG BASE
FROM ${BASE} AS runtime
ARG ARCH

ENV DEBIAN_FRONTEND=noninteractive

RUN cd /usr/local \
 && git clone https://github.com/vyzo/gerbil.git \
 && cd gerbil/src \
 && sed -i -e 's/mysql #f/mysql #t/g' ./std/build-features.ss \
 && sed -i -e 's/yaml #f/yaml #t/g' ./std/build-features.ss \
 && sed -i -e 's/leveldb #f/leveldb #t/g' ./std/build-features.ss \
 && sed -i -e 's/lmdb #f/lmdb #t/g' ./std/build-features.ss \
 && ./build.sh 

ENV PATH "/usr/local/gerbil/bin:$PATH"
ENV GERBIL_HOME "/usr/local/gerbil"

ARG VCS_REF
ARG VCS_URL
ARG BUILD_DATE
LABEL org.label-schema.vcs-ref=${VCS_REF} \
      org.label-schema.vcs-url=${VCS_URL} \
org.label-schema.build-date=${BUILD_DATE}

CMD gxi
