FROM bosh/main-base

RUN wget -q -c https://s3.amazonaws.com/bosh-gnatsd/gnatsd-0.9.6-bosh.13-linux-amd64 -O /usr/local/bin/gnatsd
RUN chmod +x /usr/local/bin/gnatsd

# RUN echo "aed21d73b0155db2871e724e3f1ed033433e7ea2d814406b1451de53edc20d6d /usr/local/bin/gnatsd" | shasum -a 256 -c -

CMD ["gnatsd", "-c", "/config/nats.conf", "-T", "-D"]
