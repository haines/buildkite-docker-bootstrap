FROM buildpack-deps:stretch

ENV DOCKER_VERSION=17.12.1

RUN set -x \
 && apt_repository="deb [arch=amd64] https://download.docker.com/linux/debian stretch stable" \
 \
 && build_dependencies=' \
      apt-transport-https \
      software-properties-common \
    ' \
 && apt-get update \
 && apt-get install -y --no-install-recommends $build_dependencies \
 \
 && curl -fsSL https://download.docker.com/linux/debian/gpg \
    | apt-key add - \
 && add-apt-repository "$apt_repository" \
 \
 && apt-get update \
 && apt-cache policy docker-ce \
 && apt-get install -y --no-install-recommends \
      docker-ce="${DOCKER_VERSION}~ce-0~debian" \
 \
 && add-apt-repository --remove "$apt_repository" \
 && apt-get purge -y --auto-remove $build_dependencies \
 && rm -Rf /var/lib/apt/lists/* \
 \
 && docker --version

RUN set -x \
 && mkdir /var/lib/buildkite-agent \
 && useradd \
      --create-home \
      --shell /bin/bash \
      --user-group \
      buildkite-agent \
 && chown buildkite-agent:buildkite-agent /var/lib/buildkite-agent

USER buildkite-agent
