# About this Repo

This is an extended version of the [official Docker Cassandra](https://hub.docker.com/_/cassandra/) image for added support for [rancher](http://rancher.com/).

If run on rancher and setting the environment variable ```RANCHER_ENABLE=true```, it will need no further configuration and can be run in a service. Just use pboos/rancher-cassandra in a container and it will automatically listen to the primary ip and find the other containers in the service to use as seeds. You can scale it to as many containers as you want. They will automatically build a cluster using [Rancher  metadata service](http://docs.rancher.com/rancher/metadata-service/).
