FROM debian:stretch-slim

ENV AGENT_NAME=stackdriver-agent

ENV REPO_HOST=packages.cloud.google.com

RUN    apt-get update \
    && apt-get install --no-install-recommends -y \
            curl \
            ca-certificates \
            gnupg2 \
    && curl -sSO https://dl.google.com/cloudagents/add-monitoring-agent-repo.sh \
    && bash add-monitoring-agent-repo.sh --also-install \
    && rm -rf /var/lib/apt/lists/*

    # && echo 'deb http://packages.cloud.google.com/apt google-cloud-monitoring-jessie main' > /etc/apt/sources.list.d/google-cloud-monitoring.list \
    # && curl --connect-timeout 5 -s -f "https://${REPO_HOST}/apt/doc/apt-key.gpg" | apt-key add - \
    # && apt-get -qq update \
    # && apt-get install $AGENT_NAME --no-install-recommends -y

COPY entrypoint.sh /entrypoint.sh

CMD ["/entrypoint.sh"]
