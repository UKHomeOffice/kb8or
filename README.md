# kb8or
Continuous Deployment Tool for deploying with [Kubernetes](http://kubernetes.io/).

## Features
1. Will deploy any Kubernetes YAML files by creating / re-creating or do rolling update as required
2. Monitors for success (including restarts) of applications (where [kubectl client](http://kubernetes.io/v1.0/docs/getting-started-guides/aws/kubectl.html) doesn't). 
3. Reports on failures and display logs and errors for failing resources
3. Container images AND resource version management
4. Application environment specific variables (for deployments to dev, pre-prod, production)

## Pre-requisites
1. A running Kubernetes cluster
2. Either locally with; [Ruby](https://www.ruby-lang.org/en/documentation/installation/) 2.x, bundler, [kubectl client](http://kubernetes.io/v1.0/docs/getting-started-guides/aws/kubectl.html) client.
3. Or with Docker (no install).

In order to run this in a container you'll need docker installed:

* [Windows](https://docs.docker.com/windows/started)
* [OS X](https://docs.docker.com/mac/started/)
* [Linux](https://docs.docker.com/linux/started/)

It is currently hosted here: https://quay.io/repository/ukhomeofficedigital/kb8or

## Local Install

   Or locally:
   
   Requires Ruby and the [kubectl client](http://kubernetes.io/v1.0/docs/getting-started-guides/aws/kubectl.html).
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
3. Each deploy will be loaded and settings will be updated
4. kubectl will be used to setup the Kb8or specific context settings (typically set per environment)
4. Any .yaml files in the path specfified will be parsed and environment settings replaced. 

### Examples:

See [example/Example.md](example/Example.md)

## Contributing

Feel free to submit pull requests and issues. If it's a particularly large PR, you may wish to discuss it in an issue first.

Please note that this project is released with a [Contributor Code of Conduct](code_of_conduct.md). 
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
