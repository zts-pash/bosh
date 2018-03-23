FROM bosh/main

# Copy nginx blobs and packaging
RUN mkdir -p nginx patches
COPY ./nginx ./nginx
COPY ./patches ./patches

RUN chmod +x ./nginx/packaging

# Install nginx
RUN CPPFLAGS="-I/usr/include" LDFLAGS="-I/usr/lib" BOSH_INSTALL_TARGET=/usr/local/nginx ./nginx/packaging

CMD ["/usr/local/nginx/sbin/nginx", "-c", "/etc/nginx/nginx.conf"]
