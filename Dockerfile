FROM alpine:3.2
MAINTAINER Lewis Marshall <lewis@technoplusit.co.uk>

ENV BUILD_PACKAGES bash curl-dev ruby-dev build-base wget tar
ENV RUBY_PACKAGES ruby ruby-io-console ruby-bundler

# Update and install all of the required packages.
# At the end, remove the apk cache
RUN apk update && \
    apk upgrade && \
    apk add $BUILD_PACKAGES && \
    apk add $RUBY_PACKAGES && \
    rm -rf /var/cache/apk/*

# Install gems...
RUN mkdir /var/lib/kb8or
WORKDIR /var/lib/kb8or
ADD Gemfile /var/lib/kb8or/
ADD Gemfile.lock /var/lib/kb8or/
RUN bundle install

# Add the kb8or files
ADD . /var/lib/kb8or/
RUN ln -s /var/lib/kb8or/kb8or.rb /usr/local/bin/kb8or

# Download any binaries:
ADD ./bin/downloads.sh /usr/local/bin/
RUN /usr/local/bin/downloads.sh

RUN mkdir -p ~/.kube

# Add the deploy mount - point
RUN mkdir -p /var/lib/deploy
WORKDIR /var/lib/deploy
VOLUME /var/lib/deploy

ENTRYPOINT ["/var/lib/kb8or/kb8or.rb"]
