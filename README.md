# kb8or
Continuous Deployment Tool for deploying with kubernetes

## Features
Will deploy kubernetes from files intelligently...

1. Will monitor for health of containers (not just fire and forget)
2. Supports private registry override (will support differing environments)
3. Container version manipulation (from version files - e.g. version artefacts files)
4. Environment specific variables (for deployments to dev, pre-prod, production)

## Pre-requisites
1. Requires a kubernetes cluster
2. Either:

  2. Localy
     
     2. Requires Ruby

     3. The "kubectl" client
     
     4. ssh client (For tunnel option)
  
  3. Docker

## Install

1. Can be simply run as a container (no install)
2. Or locally:
   
   Requires Ruby and the "kubectl" client
   `bundle install`
   
   
## Usage

### As a container:
`docker run -it --rm -v ${PWD}:/var/lib/deploy quay.io/ukhomeofficedigital/kb8or --help`
### Locally:
`./kb8or.rb --help`

### Deploy an 'environment':

Deploy to "default" environment (usually vagrant):
`./kb8or.rb mydeploy.yaml`

Deploy to specific environment:
`./kb8or.rb mydeploy.yaml --env pre-production`

A deployment will do the following:

1. Any defaults.yaml will be loaded (from the same directory)
2. Any environment file will then be parsed (based on EnvFileGlobPath set in defaults)
3. Each deploy will be loaded and setting will be updated
4. kubectl will be run to setup the Kb8Server settings (typically set per environment)
4. Any .yaml files in the path specfified will be parsed and environment settings replaced. 

### Examples:

See [example/Example.md](example/Example.md)
