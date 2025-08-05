# Download the latest iventoy version iventoy-1.0.20-linux-free.tar.gz

FROM ziggyds/alpine-utils:latest AS init
ARG IVENTOY=1.0.21
WORKDIR /iventoy
RUN echo ${IVENTOY} && \
    wget https://github.com/ventoy/PXE/releases/download/v${IVENTOY}/iventoy-${IVENTOY}-linux-free.tar.gz && \
    tar -xvf *.tar.gz && \
    rm -rf iventoy-${IVENTOY}-linux.tar.gz && \
    mv iventoy-${IVENTOY} iventoy


FROM debian:12-slim

# https://www.iventoy.com/en/doc_portnum.html
# iVentoy GUI HTTP Server Port
EXPOSE 26000/tcp
# iVentoy PXE Service HTTP Server Port
EXPOSE 16000/tcp
# DHCP Server Port
EXPOSE 67/udp 68/udp
# TFTP Server Port
EXPOSE 69/udp
# NBD Server Port
EXPOSE 10809/tcp

WORKDIR /app
# Copy iventoy
COPY --from=init /iventoy/iventoy /app

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD /entrypoint.sh
