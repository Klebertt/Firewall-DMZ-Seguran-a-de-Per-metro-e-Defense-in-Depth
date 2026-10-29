FROM kathara/base:latest AS kathara-tools
FROM nginx:latest

COPY --from=kathara-tools /usr/sbin/ip /usr/sbin/ip
COPY --from=kathara-tools /lib/x86_64-linux-gnu/libbpf.so.1 /lib/x86_64-linux-gnu/libbpf.so.1
COPY --from=kathara-tools /lib/x86_64-linux-gnu/libelf.so.1 /lib/x86_64-linux-gnu/libelf.so.1
COPY --from=kathara-tools /lib/x86_64-linux-gnu/libmnl.so.0 /lib/x86_64-linux-gnu/libmnl.so.0
COPY --from=kathara-tools /lib/x86_64-linux-gnu/libcap.so.2 /lib/x86_64-linux-gnu/libcap.so.2

ENTRYPOINT []
CMD ["bash"]
