# Stage 1: Builder to prepare Flink and dependencies
FROM flink:1.20.3-scala_2.12 AS flink-builder

# Stage 2: Final image
FROM quay.io/jupyter/datascience-notebook:python-3.12

USER root

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    sssd libltdl7 libkrb5-3 libgssapi-krb5-2 gnupg2 unixodbc unixodbc-dev odbcinst tdsodbc libkrb5-dev libssl-dev ca-certificates dirmngr gpg-agent wget curl \
    openjdk-11-jdk-headless nodejs npm && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH
ENV FLINK_HOME=/opt/flink

# Copy Flink from builder and create symlink
COPY --from=flink-builder ${FLINK_HOME} ${FLINK_HOME}
RUN ln -s ${FLINK_HOME}/bin/flink /usr/local/bin/flink && mkdir -p ${FLINK_HOME}/plugins/s3-fs-hadoop

# Download compatible Paimon, Flink SQL Client, and S3 connector JARs into /opt/flink/lib
RUN wget -O ${FLINK_HOME}/lib/paimon-flink-1.20-1.3.1.jar https://repo.maven.apache.org/maven2/org/apache/paimon/paimon-flink-1.20/1.3.1/paimon-flink-1.20-1.3.1.jar && \
    wget -O ${FLINK_HOME}/lib/paimon-s3-1.3.1.jar https://repo.maven.apache.org/maven2/org/apache/paimon/paimon-s3/1.3.1/paimon-s3-1.3.1.jar && \
    wget -O ${FLINK_HOME}/lib/flink-sql-client-1.20.3.jar https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-client/1.20.3/flink-sql-client-1.20.3.jar && \
    wget -O ${FLINK_HOME}/lib/flink-shaded-hadoop-2-uber-2.8.3-10.0.jar https://repo.maven.apache.org/maven2/org/apache/flink/flink-shaded-hadoop-2-uber/2.8.3-10.0/flink-shaded-hadoop-2-uber-2.8.3-10.0.jar && \
    wget -O ${FLINK_HOME}/plugins/s3-fs-hadoop/flink-s3-fs-hadoop-1.20.3.jar https://repo.maven.apache.org/maven2/org/apache/flink/flink-s3-fs-hadoop/1.20.3/flink-s3-fs-hadoop-1.20.3.jar

# Consolidate Flink config and permissions
RUN mkdir -p /home/jovyan/.flink/logs /home/jovyan/.flink/pids && \
    npm install -g configurable-http-proxy cross-spawn@^7.0.5 glob@^10.5.0 requirejs@^2.3.7 && \
    npm cache clean --force && \
    chown -R ${NB_UID}:${NB_GID} ${FLINK_HOME} /home/jovyan/.flink

# Set Flink environment variables
ENV FLINK_LOG_DIR=/home/jovyan/.flink/logs
ENV FLINK_PID_DIR=/home/jovyan/.flink/pids

USER ${NB_UID}

# Install Python dependencies
COPY --chown=${NB_UID}:${NB_GID} requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

WORKDIR ${HOME}
