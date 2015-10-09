# Elasticsearch Example

This example can deploy an Elasticsearch stack from a single ResourceController [template file ./kb8/es-template-rc.yaml]([./kb8/es-template-rc.yaml])

The services and service accounts will be deployed first (kb8or knows they are often dependencies) from [./kb8/](./kb8/).

The actual deployment is in [Deployment file ./kb8_deploy.yaml](./kb8_deploy.yaml).
