FROM bosh/main-base
RUN mkdir /bosh
WORKDIR /bosh
# COPY Gemfile /bosh/Gemfile
# COPY Gemfile.lock /bosh/Gemfile.lock
COPY . /bosh
RUN bash -c 'source /etc/profile.d/chruby.sh && chruby 2.4.2 && bundle install'
