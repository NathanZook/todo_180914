FROM ruby:2.5.1-stretch
LABEL  OS="stretch"
LABEL  ruby="2.5.1"
LABEL  sinatra="2.0.3"
LABEL  maintainer="Nathan Zook<testbuild@pierian-spring.net>"

RUN wget http://ftp.us.debian.org/debian/pool/main/a/authbind/authbind_2.1.2_amd64.deb && \
  dpkg -i authbind_2.1.2_amd64.deb && \
  rm authbind_2.1.2_amd64.deb

ENV APPNAME todo_180914
ENV PORT 443
RUN groupadd -r $APPNAME && \
  useradd -r -s /bin/false -m -g $APPNAME $APPNAME && \
  mkdir -p /opt/$APPNAME && \
  chown $APPNAME.$APPNAME /opt/$APPNAME && \
  touch /etc/authbind/byport/$PORT && \
  chown root.$APPNAME /etc/authbind/byport/$PORT && \
  chmod ug+x /etc/authbind/byport/$PORT


RUN gem install --no-document bundler -v 1.16.1
EXPOSE $PORT

USER $APPNAME
WORKDIR /opt/$APPNAME
RUN git clone https://github.com/NathanZook/$APPNAME .
RUN bundle install --local --deployment
ENTRYPOINT authbind --deep bundle exec /usr/local/bin/ruby -I lib /opt/$APPNAME/lib/nztodo.rb -p $PORT

