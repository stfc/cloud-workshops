## Envoy Gateway Examples

> [!NOTE]
> We're still developing these examples, please let us know if there are any issues/bugs by raising an issue

In this directory you will find some example Envoy Gateway resources to help you get started with setting up Gateway API and Envoy Gateway resources. 

See helper confluence doc for migrating to Gateway API: <TOOD: link>

## Envoy Gateway Installation

Install gateway API using the helm chart onto your cluster -  
helm install eg oci://docker.io/envoyproxy/gateway-helm -n envoy-gateway-system --create-namespace

or follow the instructions here for your preferred installation method: https://gateway.envoyproxy.io/docs/install

This will install all the CRDs (custom resource definitions) that you need to be able to setup Gateway envoy onto your cluster

## Deploy Example

clone the repo, cd into envoy-gateway:
``` 
    git clone https://github.com/stfc/cloud-workshops.git
    cd envoy-gateway
```

### Prerequisites

1. A CAPI cluster on STFC Cloud
2. A Floating IP available on your project

### Gateway Setup steps 

Under `gateway` you will find an example resources for EnvoyProxy, Gateway and GatewayClass. 

Edit envoyproxy.yaml and add your floating IP as the value for `loadBalancerIP` 

Then apply all the files

```
cd gateway
kubectl apply -f gateway.yaml
kubectl apply -f gatewayclass.ymal
kubectl apply -f envoyproxy.yaml
```

This will setup Envoy Gateway on your cluster. It will provision an Octavia Loadbalancer that will route network traffic to your cluster. 

The Gateway will listen for HTTP traffic only, 

You can then apply the example deployment under `app` folder to deploy a simple "hello world" webpage to show that routing works

```
cd ../app
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f httproute.yaml
```

You'll need to add this entry to your /etc/hosts: 

```
<your floating IP> my.example.com
```

And you can then connect to it via your web-browser: http://my.example.com

## Extras

Once you've deployed a working example, we've also written some more advanced docs on Envoy Gateway in the `extras` folder

Please contribute to this repo if you have any other examples to help others use Envoy Gateway on the STFC Cloud!
