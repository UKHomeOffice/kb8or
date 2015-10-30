# kb8or

[![Build Status](https://travis-ci.org/UKHomeOffice/kb8or.svg?branch=master)](https://travis-ci.org/UKHomeOffice/kb8or)

Continuous Deployment Tool for deploying with [Kubernetes](http://kubernetes.io/).

## Features
1. Will deploy any Kubernetes YAML files by creating / re-creating or do rolling update as required
2. Monitors for success (including restarts) of applications (where [kubectl client](http://kubernetes.io/v1.0/docs/getting-started-guides/aws/kubectl.html) doesn't). 
3. Reports on failures and display logs and errors for failing resources
3. Container images AND resource version management
4. Application environment specific variables (for deployments to dev, pre-prod, production)

## Pre-requisites
1. A running Kubernetes cluster
2. Either  
   1. [Ruby](https://www.ruby-lang.org/en/documentation/installation/) 2.x, bundler, [kubectl client](http://kubernetes.io/v1.0/docs/getting-started-guides/aws/kubectl.html) client.  
   2. [Docker](#docker-prerequisites).

## Install (if not using Docker)
   
1. Download the [kubectl client](http://kubernetes.io/v1.0/docs/getting-started-guides/aws/kubectl.html).
2. `bundle install`
   
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

1. Any (defaults.yaml) will be loaded (from the same directory as the deployment)
2. Any environment data will then be parsed (based on EnvFileGlobPath set in config)
3. Each deploy will be loaded and settings will be updated
4. kubectl will be used to setup the Kb8or specific context settings (typically set per environment)
4. Any Kubernetes .yaml files in the path specified will be parsed and deployed / updated as required.

### Schema

All features and configurable options are described in the [Schema Documentation](./docs/schema.md).

### Examples:

* For a walk through of features see [docs/example/Example.md](docs/example/Example.md).
* Example of creation of multiple ResourceControllers from a [templated Elasticsearch](docs/example/elasticsearch/Example.md) resource.

## Docker-prerequisites

In order to run this in a container you'll need docker installed:

* [Windows](https://docs.docker.com/windows/started)
* [OS X](https://docs.docker.com/mac/started/)
* [Linux](https://docs.docker.com/linux/started/)

It is currently hosted here: https://quay.io/repository/ukhomeofficedigital/kb8or

## Contributing

Feel free to submit pull requests and issues. If it's a particularly large PR, you may wish to discuss it in an issue first.

Please note that this project is released with a [Contributor Code of Conduct](CONTRIBUTING.md). 
By participating in this project you agree to abide by its terms.

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/your/project/tags).

To create a new version:

1. update the [version](version) file.
2. Push a tag of the same version name to build Docker image at https://quay.io/repository/ukhomeofficedigital/kb8or

## Authors

* **Lewis Marshall** - *Initial work* - [Lewis Marshall](https://github.com/lewismarshall)

See also the list of [contributors](https://github.com/UKHomeOffice/kb8or/contributors) who participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

* [Kubernetes](http://kubernetes.io/)
