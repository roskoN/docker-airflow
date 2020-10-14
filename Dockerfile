# VERSION 1.10.10
# AUTHOR: Matthieu "Puckel_" Roisil
# DESCRIPTION: Basic Airflow container
# BUILD: docker build --rm -t puckel/docker-airflow .
# SOURCE: https://github.com/puckel/docker-airflow

FROM python:3.6-slim
LABEL maintainer="Puckel_"

# Never prompts the user for choices on installation/configuration of packages
ENV DEBIAN_FRONTEND noninteractive
ENV TERM linux

# Airflow
ARG AIRFLOW_VERSION=1.10.10
ARG AIRFLOW_HOME=/usr/local/airflow
ARG AIRFLOW_DEPS="redis,postgres,mysql,ldap,aws,password,mongo,spark,jdbc"
ARG PYTHON_DEPS="atlassian-python-api pymongo requests walrus orjson pottery pypika"
ENV AIRFLOW_GPL_UNIDECODE yes

# Define en_US.
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LC_CTYPE en_US.UTF-8
ENV LC_MESSAGES en_US.UTF-8

RUN set -ex \
    && buildDeps=' \
        freetds-dev \
        libkrb5-dev \
        libsasl2-dev \
        libssl-dev \
        libffi-dev \
        libpq-dev \
        git \
    ' \
    && apt-get update -yqq \
    && apt-get upgrade -yqq \
    && apt-get install -yqq --no-install-recommends \
        $buildDeps \
        freetds-bin \
        build-essential \
        default-libmysqlclient-dev \
        apt-utils \
        curl \
        rsync \
        netcat \
        locales \
        wget \
    && sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/g' /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && useradd -ms /bin/bash -d ${AIRFLOW_HOME} airflow \
    && pip install -U pip setuptools wheel \
    && pip install pytz \
    && pip install pyOpenSSL \
    && pip install ndg-httpsclient \
    && pip install pyasn1 \
    && pip install apache-airflow[crypto,celery,postgres,hive,jdbc,mysql,ssh${AIRFLOW_DEPS:+,}${AIRFLOW_DEPS}]==${AIRFLOW_VERSION} \
    && pip install 'celery[redis,librabbitmq,brotli,zstd,lzma,eventlet,gevent]~=4.3' \
    && pip install 'redis~=3.2' \
    && if [ -n "${PYTHON_DEPS}" ]; then pip install ${PYTHON_DEPS}; fi \
    && apt-get purge --auto-remove -yqq $buildDeps \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/* \
        /usr/share/man \
        /usr/share/doc \
        /usr/share/doc-base

COPY script/entrypoint.sh /entrypoint.sh
COPY config/airflow.cfg ${AIRFLOW_HOME}/airflow.cfg
COPY config/log_config.py ${AIRFLOW_HOME}/config/log_config.py
COPY config/__init__.py ${AIRFLOW_HOME}/config/__init__.py

RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "${ARCH}" in \
       aarch64|arm64) \
         ESUM='0ad1ff282ad034a613c64313c885edef5dfbc5dd51f2eda705bbeb7fa822f238'; \
         BINARY_URL='https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u262-b10/OpenJDK8U-jre_aarch64_linux_hotspot_8u262b10.tar.gz'; \
         ;; \
       armhf|armv7l) \
         ESUM='330ce008c6f49ddd6dcf43c7839896bb7fe14843300358a71b441a3f94036f69'; \
         BINARY_URL='https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u262-b10/OpenJDK8U-jre_arm_linux_hotspot_8u262b10.tar.gz'; \
         ;; \
       ppc64el|ppc64le) \
         ESUM='12309354889da2ed9085fda9812c7d2653fa099c36d322af222da11cbb244df7'; \
         BINARY_URL='https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u262-b10/OpenJDK8U-jre_ppc64le_linux_hotspot_8u262b10.tar.gz'; \
         ;; \
       s390x) \
         ESUM='0225d0a8707c0b6a059c58b77dd7387fb439816100d668ba000c4536cef77fc2'; \
         BINARY_URL='https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u262-b10/OpenJDK8U-jre_s390x_linux_hotspot_8u262b10.tar.gz'; \
         ;; \
       amd64|x86_64) \
         ESUM='3ce1f34b279a4f8fc6374f5644739622886dd4bcac4fcb0eb596955bac5ca5a4'; \
         BINARY_URL='https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u262-b10/OpenJDK8U-jre_x64_linux_hotspot_8u262b10.tar.gz'; \
         ;; \
       *) \
         echo "Unsupported arch: ${ARCH}"; \
         exit 1; \
         ;; \
    esac; \
    curl -LfsSo /tmp/openjdk.tar.gz ${BINARY_URL}; \
    echo "${ESUM} */tmp/openjdk.tar.gz" | sha256sum -c -; \
    mkdir -p /opt/java/openjdk; \
    cd /opt/java/openjdk; \
    tar -xf /tmp/openjdk.tar.gz --strip-components=1; \
    rm -rf /tmp/openjdk.tar.gz; \
    chown -R airflow: /opt/java/openjdk

ENV JAVA_HOME=/opt/java/openjdk \
    PATH="/opt/java/openjdk/bin:$PATH"

RUN chown -R airflow: ${AIRFLOW_HOME}
RUN mkdir -p ${AIRFLOW_HOME}/logs \
    && mkdir -p ${AIRFLOW_HOME}/dags \
    && chown -R airflow: ${AIRFLOW_HOME} \
    && chgrp -R 0 ${AIRFLOW_HOME} \
    && chmod -R g=u ${AIRFLOW_HOME} \
    && chmod g=u /etc/passwd \
    && mkdir -p ${AIRFLOW_HOME}/jdbc \
    && wget https://s3.amazonaws.com/redshift-downloads/drivers/jdbc/1.2.37.1061/RedshiftJDBC4-1.2.37.1061.jar -P ${AIRFLOW_HOME}/jdbc


EXPOSE 8080 5555 8793

WORKDIR ${AIRFLOW_HOME}
ENV AIRFLOW_HOME = ${AIRFLOW_HOME}
ENV PYTHONPATH /usr/local/airflow/config/
USER airflow

ENTRYPOINT ["/entrypoint.sh"]
CMD ["webserver"] # set default arg for entrypoint
