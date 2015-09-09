# Example of simple kb8or deploy

## Step 0
Make sure you have a working kubernetes cluster running with a properly configured ~/.kube/config file
The instructions assume you are in the simple_kb8or_deploy directory

## Step 1 - create namespaces for your application
Currently kb8or will try to deploy to a namespace of the same name as the environment. For example dev. The namespace must exist before you try to deploy with kb8or.

For this example deploy we will just use the dev namespace which you can create by doing:
```bash
kubectl create -f namespaces/dev-namespace.yaml
```

## Step 2 - create a defaults.yaml
This file should contain:
ContainerVersionGlobPath - Gives the path to your version files. It uses a wildcard for the deployment name. The file itself should contain the docker image version to be deployed.
DefaultEnvName - The default environment to deploy to if no environment is specified
EnvFileGlobPath - This uses a wildcard for the environment name. The file itself contains any config specific to the environment being used

## Step 3 - create your version file
This file is referred to in defaults.yaml and you can see an example in versions/digital-storage_container_version
Typically this file would be created as part of your build pipeline

## Step 4 - create deployment file for each project you want to have deploys for
The example is at digital-storage.yaml. As a minimum it must contain:
- A default for whether a private registry is being used for the project
- The path to the kubernetes files to be deployed (usually a replication controller and service)

Note you can specify multiple locations for the kubernetes files if you want to deploy multiple different services together.

## Step 5 - create your environment files
These files contain any configuration specific to different environments. Examples in environments directory.

## Step 6 - create kubernetes files
These files are just like usual kubernetes files except they allow certain substitutions.
- To substitute for values in the environment file do ${variable_name}
- The version will automatically be replaced with the contents of your version file
- The repository will be replaced if you have specified that you want to use a private repository

## Step 7 - run kb8or
When running kb8or you will need to ensure:
- Wherever you docker daemon is, it will need to have access to the volumes you map in. This is important when doing docker in docker!!
- If running directly on a host (not docker in docker) then you don't need to worry about that first point
- The first time you run this it will try to generate a kubeconfig but will fail as it won't know the token, cluster, etc
- Currently the best approach is to map in the volume containing kubeconfig (/root/.kube below). Run. Then update the kubeconfig by hand
- Once you have a correct kubeconfig it will work consistently
```bash
docker run --rm -v /root/.kube:/root/.kube/ -v ${PWD}/simple_kb8or_deploy:/var/lib/deploy quay.io/ukhomeofficedigital/kb8or:v0.1.8 -e dev digital-storage.yaml
```