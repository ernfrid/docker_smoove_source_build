FROM debian:stretch-slim as builder-base
LABEL maintainer "Dave Larson <delarson@wustl.edu>"
RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends \
        build-essential \
        make \
        cmake \
        autoconf \
        automake \
        libtool \
        gawk \
        git-core \
        bzip2 \
        libbz2-dev \
        liblzma-dev \
        libssl1.0-dev \
        libcurl4-openssl-dev \
        ca-certificates \
        curl \
        zlib1g-dev


FROM builder-base as lumpy-2f3fccb-build
LABEL maintainer "Dave Larson <delarson@wustl.edu>"
RUN LUMPY_COMMIT=2f3fccb0e6ef8732ff2f5c4e2c12a7a0b8ae2784 \
    && git clone --single-branch --recursive --depth 5 https://github.com/arq5x/lumpy-sv \
    && cd lumpy-sv \
    && git checkout $LUMPY_COMMIT \
    && make -j 3 \
    && mkdir -p /opt/hall-lab/lumpy-2f3fccb/bin \
    && cp ./bin/* /opt/hall-lab/lumpy-2f3fccb/bin
    
FROM builder-base as svtyper-0.7.0-build
LABEL maintainer "Dave Larson <delarson@wustl.edu>"

COPY --from=halllab/python2.7-build:v1 /opt/hall-lab/python-2.7.15 /opt/hall-lab/python-2.7.15
ENV PATH=/opt/hall-lab/python-2.7.15/bin:${PATH}
RUN SVTYPER_VERSION=0.7.0 \
    && git clone https://github.com/hall-lab/svtyper \
    && cd svtyper \
    && git checkout v$SVTYPER_VERSION \
    && sed -i '/numpy/d' setup.py \
    && sed -i '/scipy/d' setup.py \
    && pip install .
RUN find /opt/hall-lab/python-2.7.15/ -depth \( -name '*.pyo' -o -name '*.pyc' -o -name 'test' -o -name 'tests' \) -exec rm -rf '{}' + ;
RUN find /opt/hall-lab/python-2.7.15/lib/python2.7/site-packages/ -name '*.so' -print -exec sh -c 'file "{}" | grep -q "not stripped" && strip -s "{}"' \;

# Smoove build...
# Largely copied from https://github.com/brentp/smoove/blob/master/.travis.yml
FROM golang:1.11-stretch as smoove-1c887ec-binary-build
RUN SMOOVE_COMMIT=1c887ec97154d54b068c2bf1158bd86c259a266b \
    && go get github.com/brentp/smoove \
    && cd src/github.com/brentp/smoove/ \
    && git checkout $SMOOVE_COMMIT \
    && sed -i 's/const Version = ".\+"/const Version = "$SMOOVE_COMMIT"/' smoove.go \
    && go get ./... \
    && go build cmd/smoove/smoove.go
    
FROM builder-base as smoove-1c887ec-build
WORKDIR /opt/hall-lab/smoove-1c887ec/bin
COPY --from=smoove-1c887ec-build /go/src/github.com/brentp/smoove/smoove /opt/hall-lab/smoove-1c887ec/bin
RUN MOSDEPTH_VERSION=0.2.4 \
    && GSORT_VERSION=0.0.6 \
    && curl -L -o mosdepth https://github.com/brentp/mosdepth/releases/download/v$MOSDEPTH_VERSION/mosdepth \
    && chmod a+x mosdepth \
    && curl -L -o gsort https://github.com/brentp/gsort/releases/download/v$GSORT_VERSION/gsort_linux_amd64 \
    && chmod a+x gsort

FROM debian:stretch-slim
LABEL maintainer "Dave Larson <delarson@wustl.edu>"

COPY --from=lumpy-2f3fccb-build /opt/hall-lab/lumpy-2f3fccb/bin /opt/hall-lab/lumpy-2f3fccb/bin
COPY --from=svtyper-0.7.0-build /opt/hall-lab/python-2.7.15 /opt/hall-lab/python-2.7.15
COPY --from=halllab/htslib-1.9-build:v1 /build/deb-build/opt/hall-lab/htslib-1.9 /opt/hall-lab/htslib-1.9
COPY --from=halllab/samtools-1.9-build:v1 /build/deb-build/opt/hall-lab/samtools-1.9 /opt/hall-lab/samtools-1.9
COPY --from=halllab/bcftools-1.9-build:v1 /build/deb-build/opt/hall-lab/bcftools-1.9 /opt/hall-lab/bcftools-1.9
COPY --from=smoove-1c887ec-build /opt/hall-lab/smoove-1c887ec/bin /opt/hall-lab/smoove-1c887ec/bin

ENV PATH=/opt/hall-lab/smoove-1c887ec/bin:/opt/hall-lab/python-2.7.15/bin:/opt/hall-lab/lumpy-2f3fccb/bin:/opt/hall-lab/htslib-1.9/bin:/opt/hall-lab/samtools-1.9/bin:/opt/hall-lab/bcftools-1.9/bin:$PATH
ENV LD_LIBRARY_PATH=/opt/hall-lab/htslib-1.9/lib:$LD_LIBRARY_PATH

RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends \
        libssl1.1 \
        libcurl3 \
        libncurses5 \
        libbz2-1.0 \ 
        liblzma5 \ 
        libssl1.0.2 \
        zlib1g

CMD ["/bin/bash"]
