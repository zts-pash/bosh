FROM bosh/main

ENV BOSH_INSTALL_TARGET=.
ENV CPPFLAGS="-I/usr/include"
ENV LDFLAGS="-I/usr/lib"

# Copy nginx blobs and packaging
RUN mkdir -p nginx patches
COPY ./nginx ./nginx
COPY ./patches ./patches

RUN chmod +x ./nginx/packaging

# Install nginx
RUN CPPFLAGS="-I/usr/include" LDFLAGS="-I/usr/lib" ./nginx/packaging
