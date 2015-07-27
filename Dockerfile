FROM ruby:2.0.0-p645-slim
MAINTAINER Lewis Marshall <lewis@technoplusit.co.uk>

# Update and install all of the required packages.
RUN apt-get update && apt-get install -y \
    wget \
    tar

# TODO: could make these just mount points (to stay compatible with platform)
# Download the fleetctl binary:
RUN FLEET_URL=https://github.com/coreos/fleet/releases/download/v0.10.2/fleet-v0.10.2-linux-amd64.tar.gz && \
    export FLEET_TAR=$(basename ${FLEET_URL}) && \
    wget -O /tmp/${FLEET_TAR} ${FLEET_URL} && \
    cd /tmp && \
    tar -xzvf ${FLEET_TAR} && \
    cp $(basename ${FLEET_TAR} .tar.gz)/fleetctl /usr/local/bin/fleetctl

# Download the kubectl binary:
ENV KUBE_VER=0.20.2
ENV KUBE_URL=https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VER}/bin/linux/amd64/kubectl
RUN /bin/bash -l -c "wget ${KUBE_URL} \
                     -O /usr/local/bin/kubectl && \
                     chmod +x /usr/local/bin/kubectl"

# Add the kb8or files
RUN mkdir /var/lib/kb8or
WORKDIR /var/lib/kb8or
ADD . /var/lib/kb8or/
RUN bundle install
RUN ln -s /var/lib/kb8or/kb8or.rb /usr/local/bin/kb8or

# Add the deploy mount - point
RUN mkdir -p /var/lib/deploy
WORKDIR /var/lib/deploy
VOLUME /var/lib/deploy

CMD bash