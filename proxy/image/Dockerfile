FROM kathara/base:latest

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends squid \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT []
CMD ["bash"]
