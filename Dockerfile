FROM ruby:2.6.5
MAINTAINER David Kirwan <dkirwan@redhat.com>


RUN mkdir /app
WORKDIR /app

ADD . /app
RUN bundle install --path /app/bundle/

RUN chmod 755 /app/asset_monitoring.rb

ENTRYPOINT ["bundle", "exec", "rackup", "--host", "0.0.0.0", "-p", "8080"]
