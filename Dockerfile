FROM ruby:2.5.1-stretch
LABEL  OS="stretch"
LABEL  ruby="2.5.1"
LABEL  sinatra="2.0.3"
LABEL  maintainer="Nathan Zook<testbuild@pierian-spring.net>"

ENV APPNAME todo_180914
RUN groupadd -r $APPNAME && \
  useradd -r -s /bin/false -m -g $APPNAME $APPNAME && \
  mkdir -p /opt/$APPNAME && \
  chown $APPNAME.$APPNAME /opt/$APPNAME

RUN gem install --no-document bundler -v 1.16.1
EXPOSE 8443

USER $APPNAME
WORKDIR /opt/$APPNAME
RUN git clone  https://github.com/NathanZook/$APPNAME .
RUN bundle install --local --deployment
ENTRYPOINT bundle exec /usr/local/bin/ruby -I lib /opt/$APPNAME/lib/nztodo.rb -p 8443

