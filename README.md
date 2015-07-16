# kb8or
Continuous Deployment Tool for deploying with kubernetes

## Features
Will deploy kubernetes from files intelligently...

1. Will monitor for health of containers (not just fire and forget)
2. Supports private registry override (will support differing environments)
3. Container version manipulation (from version files - e.g. version artefacts files) 

## Pre-requisites
1. Requires a kubernetes cluster
2. Requires Ruby
3. Requires the "kubectl" client
4. kubectl config options to be set (so e.g. `kubectl get pods` will work unfettered).

## Install
`bundle install`

## Usage
### Help
`./kb8or.rb --help`

### Deploy an 'environment':
`./kb8or.rb mydeploy.yaml`

### Sample file:
```yaml
---

ContainerVersionGlobPath: ../artefacts/*_container_version
PrivateRegistry: 10.250.1.203:5000
UsePrivateRegistry: false
NoAutomaticUpgrade: true

Deploys:
  - path: ../containers/cimgt/docker_registry/kb8
    NoAutomaticUpgrade: true
  - path: ../containers/cimgt/jenkins/kb8
    NoAutomaticUpgrade: true
  - path: ../containers/cimgt/cimgt_proxy/kb8
    UsePrivateRegistry: true
```
