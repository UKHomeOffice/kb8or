FROM ruby:2.1
MAINTAINER Lewis Marshall <lewis@technoplusit.co.uk>

# Update and install all of the required packages.
RUN apt-get update && apt-get install -y \
    wget \
    tar

# Download the kubectl binary:
ENV KUBE_VER=1.0.6
ENV KUBE_URL=https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VER}/bin/linux/amd64/kubectl
RUN /bin/bash -l -c "wget ${KUBE_URL} \
                     -O /usr/local/bin/kubectl && \
                     chmod +x /usr/local/bin/kubectl"

RUN mkdir -p ~/.kube

# Add the kb8or files
RUN mkdir /var/lib/kb8or
WORKDIR /var/lib/kb8or
ADD . /var/lib/kb8or/

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1
RUN bundle install
RUN ln -s /var/lib/kb8or/kb8or.rb /usr/local/bin/kb8or

# Add the deploy mount - point
RUN mkdir -p /var/lib/deploy
WORKDIR /var/lib/deploy
VOLUME /var/lib/deploy

ENTRYPOINT ["/var/lib/kb8or/kb8or.rb"]
