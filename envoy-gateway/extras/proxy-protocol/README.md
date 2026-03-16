# Envoy Gateway getting the Real IP

## Background

Kubernetes applications using load balancers or Gateway Envoy will have the load balancer IP instead of the client. This can make it hard to identify original traffic source for things like traffic logs and analytics.

The load balancer cannot modify the x-forwarded-for header either, because the traffic is encrypted over HTTPS too.

## Proxy Protocol

OpenStack provides support for the proxy protocol, which allows for the load balancer to prepend client connection information (including the original IP) to the data stream without decrypting HTTPS traffic. This means Envoy Proxy can extract the real client IP and populate the x-real-ip header correctly.

To enable this we must create a ClientTrafficPolicy resource - see proxy-protocol.yaml 

## Pre-Requisites

This example re-uses the existing gateway and example app deployed in `envoy-gateway/README.md` please make sure you've deployed these resources before continuing

Edit `gateway/envoyproxy.yaml` add `loadbalancer.openstack.org/proxy-protocol: "true"` to the service annotation and re-apply it

Edit OpenStack Controller Manager settings: Located at https://github.com/stfc/cloud-capi-values/blob/master/values.yaml#L172 (this is always required). 

```
addons: 
  openstack: 
    cloudConfig:
      LoadBalancer:
        enable-ingress-hostname: true
```

Then upgrade (note the latter step is required even if the directly manage Nginx through their own chart/CRDs where the values can be transplanted), as per [Cluster API Upgrade](https://stfc.atlassian.net/wiki/spaces/CLOUDKB/pages/285704256) on the management cluster.

See more Loadbalancer options here here: https://github.com/kubernetes/cloud-provider-openstack/blob/master/docs/openstack-cloud-controller-manager/using-openstack-cloud-controller-manager.md#load-balancer



## Installation

Simply apply the ClientTrafficPolicy: 

`kubectl apply -f proxy-protocol.yaml` 

You'll want to deploy it in the same namespace as the gateway you're targetting - and set the appropriate gateway name in `targetRefs`

## Verification

This can easily be verified by applying the `verify-deployment.yaml` file. This will allow an inbound connection and will print the connection information. 

`kubectl apply -f verify-deployment.yaml`

This will create a new route to `http://whoami.example.com` which you will need to add to your /etc/hosts before you can access the webpage via curl

`curl http://whoami.example.com`