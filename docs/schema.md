# Documentation of kb8or Schema and related features

### Contents

1. [Variables](#variables)
2. [Scope](#scope)
3. [Settings](#settings)  
  3.1 [ContainerVersionGlobPath](#containerversionglobpath)    
  3.2 [EnvFileGlobPath](#envfileglobpath)  
  3.3 [DefaultEnvName](#defaultenvname)  
  3.4 [Kb8Server](#kb8server)  
  3.5 [MultiTemplate](#multitemplate)  
  3.6 [NoAutomaticUpgrade](#noautomaticupgrade)  
  3.7 [NoControllerOk](#nocontrollerok)  
  3.8 [NoRollingUpdate](#norollingupdate)  
  3.9 [Path](#path)  
  3.10 [PrivateRegistry](#privateregistry)  
  3.11 [RecreateServices](#recreateservices)  
4. [Functions](#functions)

## Variables Parsing in Kubernetes Resources

kb8or does not use plain text temperating. Instead, all files must be parsable YAML. This allows for complex 
nested variable definitions e.g.
 
```yaml
mysql_volume:
  name: mysql
  emptyDir: {}
```

This can then be consumed in a Kubernetes resource definition with:

```yaml
      volumes:
        - name: checking-secrets
          secret:
            secretName: checking-secrets
        - ${ mysql_volume }
```

Variables can also be used within other variables and include files.

## Scope

Most [variables](#variables) and [settings](#settings) will work in Defaults.yaml, environment files, deployment files 
or included files.

## Settings

### ContainerVersionGlobPath

#### Scope: Default.yaml, Deployment.yaml 
 
This specifies where kb8or will look for files with container versions for any container used in a deploy.
Specify a wildcard where the container name will be. 
The file itself should contain the docker image version to be deployed.

#### Example:

The example below will load all files at the path below and replace any container image versions with the versions
 specified in the files.
```yaml
# Will match ../artefacts/mysql_container_version
#            ../artefacts/myapp_container_version
ContainerVersionGlobPath: ../artefacts/*_container_version
```

Note the Pod or ReplicationController template does NOT require a special image for this to work e.g. the text 
 `replace.me` below will be replaced with the version in a file called `../artefacts/checking_container_version`

```yaml
    containers:
      - name: checking
        image: set.by.kb8or/checking:replace.me
```

### EnvFileGlobPath

#### Scope: Default.yaml

This option will allow separate environment files to be used for variables. It specifies where to look for these file
relative to the Default.yaml. The file names found will be used as possible environment names.

#### Example

When the option `-e production` is specified, the environment file ./environments/production.yaml will be loaded for 
environment specific variables.
```yaml
EnvFileGlobPath: ./environments/*.yaml
```

### DefaultEnvName

#### Scope: Default.yaml

Specifies a default environment when no `-e` option is specified. 

#### Example

This example here will load the variables from the file ./environments/vagrant.yaml 

```yaml
DefaultEnvName: vagrant
```

### Kb8Server

#### Scope: Default.yaml, a_deployment.yaml

Details which Kubernetes server should be used to deploy to.

#### Example

The example below will create a ./kube/config entry for the server with the environment name which will then be used for 
deployments. The server entry can be created in advance and augmented with other parameters where required. See 
[kubectl config set-cluster](https://cloud.google.com/container-engine/docs/kubectl/config-set-cluster).

```yaml
Kb8Server: https://10.101.0.1:443
```

### MultiTemplate

#### Scope: 'Path:' within a_deployment.yaml

Will deploy multiple matching Kubernetes resources based on a single template.

#### Simple Example

The example below will create two ReplicationControllers from the same template.
The template specified by the "Name:" tag of "MultiTemplate" must exist in the directory  
../containers/nfidd/elastic_search with any file name (*.yaml) but a matching "metadata:", "name:".
 
*Note* all the resources in this directory which are NOT ReplicationController resources will be deployed (or updated) 
*before* the resource controller.
 
```yaml
Deploys:
  - Path: ../containers/nfidd/elastic_search
    UsePrivateRegistry: false
    MultiTemplate:
      Name: es-template
      Items:
      - Name: es-master
        Vars:
          es_tier: "master"
          es_master: "true"
          es_client: "false"
          es_data: "true"
          es_replicas: 1
      - Name: es-client
        Vars:
          es_tier: "client"
          es_master: "false"
          es_client: "true"
          es_data: "false"
          es_replicas: 2
```

#### Example of EnumVar

The example below will deploy three ReplicationControllers from the template es-template.
The variable `az` will be replaced with each ReplicationController with the values as specified by the 
```yaml
Deploys:
  - path: ../containers/nfidd/elastic_search
    UsePrivateRegistry: false
    MultiTemplate:
      Name: es-template
      - Name: es-data
        EnumVar:
          Name: az
          Values:
          - eu-west-1a
          - eu-west-1b
          - eu-west-1c
        Vars:
          es_tier: "data"
          es_master: "false"
          es_client: "false"
          es_data: "true"
          es_replicas: 1
          node_selector:
            aws_az: "${ az }"
```
#### Complete Example

A complete example of this feature is given with sample files here: [elasticsearch example](./example/elasticsearch/Example.md).

### NoAutomaticUpgrade

#### Scope: 'Path:' within a_deployment.yaml

Will prevent a Pod or ReplicationController from being updated after creation. Normally this shouldn't be required but
a typical use case would be not updating the ReplicationController for Jenkins when this deployment is being run from 
one of the Pods that are controlled.
 
#### Example

```yaml
Deploys:
  - Path: ../containers/ci/jenkins
    NoAutomaticUpgrade: true
```

### NoControllerOk

#### Scope: 'Path:' within a_deployment.yaml

Normally a deployment path is expected to have a ReplicationController. Kb8or will error when one isn't found.

#### Example

The example below illustrates the deployment of a directory where a single pod that manages a mysql upgrade resides.
```yaml
Deploys:
  - path: ../containers/fdcs/mysql_management/kb8
    NoControllerOk: true
```

A section of the mysql pod is shown below. Note the `restartPolicy: Never`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mysqlmaint
  labels:
    name: mysqlmaint
spec:
  restartPolicy: Never
  containers:
  - name: mysqlmaint
```

### NoRollingUpdate

#### Scope: 'Path:' within a_deployment.yaml

A rolling update is performed for ReplicationControllers automatically. When multiple Pods may not be able to run at the
 same time e.g. where a [hostPath](http://kubernetes.io/v1.0/docs/user-guide/volumes.html#hostpath) is used, this 
 setting will cause a delete / create instead.

#### Example

```yaml
Deploys:
  - path: ../containers/fdcs/mysql
    NoRollingUpdate: true
```

### Path

#### Scope: within a_deployment.yaml

Specifies where to load Kubernetes resource files from. It can be relative to the deployment file. All parsing and other
Settings can be specified and create a new deployment context here.

#### Example

```yaml
Deploys:
  - path: ../containers/fdcs
```

### PrivateRegistry

#### Scope: Default.yaml, a_deployment.yaml, 'Path:' within a_deployment.yaml

Normally container images will be pulled with this substituted value when a "container version file" is found, see [ContainerVersionGlobPath](#containerversionglobpath).

#### Example

```yaml
PrivateRegistry: https://private-reg.notprod.com:50000
```

### RecreateServices

#### Scope: Default.yaml, a_deployment.yaml, 'Path:' within a_deployment.yaml

Services are not normally updated after creation (as this would cause a service disruption). This behaviour can be
overridden with this tag.

#### Example

```yaml
Deploys:
  - path: ../containers/fdcs
    RecreateServices: true
```

### UsePrivateRegistry

#### Scope: Default.yaml, a_deployment.yaml, 'Path:' within a_deployment.yaml

Can manage when the container source is updated with the value in [PrivateRegistry](#privateregistry).

#### Example

```yaml

UsePrivateRegistry: false

Deploys:
  - path: ../containers/fdcs
    UsePrivateRegistry: true
```

## Functions

Functions can be used to pull in other content or transform the yaml before replacing it.
 
### Fn::FileIncludePaths

#### Scope Environment file, a_kubernets_resource.yaml

This can be used to include other files within an environment or deployment file.

#### Example

```yaml
# We'll get these from S3, and encrypt in Amazon using IAM...
FileIncludePaths:
  - ../tmp/kb8or/ci_secrets_certs.yaml
  - ../tmp/kb8or/ci_secrets.yaml
```

### Fn::OptionalHashItem

#### Scope Environment file, a_kubernets_resource.yaml

This allows an item to be removed from a 
       
#### Example

The example *template* below would replace the Fn::OptionalHashItem: with the hash item variable "${node_selector}" or delete the 
key.
```yaml
      volumes:
      - name: storage
        source:
          emptyDir: {}
      nodeSelector: 
        Fn::OptionalHashItem: ${ node_selector }
```

Given the values below:
```yaml
az: eu-west-1a

node_selector:
  aws_az: "${ az }"
```

The result would be:
```yaml
      volumes:
      - name: storage
        source:
          emptyDir: {}
      nodeSelector: 
        aws_az: "eu-west-1a"
```

But given the values (and the same template above):
```yaml
az: eu-west-1a

node_selector:

```

The result would be:
```yaml
      volumes:
      - name: storage
        source:
          emptyDir: {}
      nodeSelector: 

```
