## TLS Handling Strategies with Envoy Gateway

Envoy Gateway (built on Envoy) supports multiple ways to handle TLS depending on where you want encryption to start, end, and be validated.

This document covers:

1. TLS Passthrough (L4)

2. TLS Termination + Re-encryption
    a. Insecure with Backend (skip verification)
    b. With system certs 

3. mTLS (mutual TLS)

## Pre-Requisites
This example re-uses the existing gatewayclass and envoyproxy deployed in `envoy-gateway/README.md` please make sure you've deployed these resources before continuing

## TLS Passthrough

TLS will not be terminated at the gateway - instead it is passed directly to the backend service
Gateway operates at Layer 4 (TCP)

Backend handles TLS termination, certificate verification and SNI routing (if needed)

```Client -> (TLS) -> Gateway (no decryption) -> Service -> Pod (TLS handled here)```

This will provide end-to-end encryption if TLS logic is setup for your app behind the gateway
- You will need to setup custom TLS handling if you want to use this

you will need a gateway with a listener with mode: passthrough:

```
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: example-passthrough
spec:
  gatewayClassName: envoy
  # sets up listener on port 443 and mode: passthrough
  listeners:
    - name: tls-passthrough
      protocol: TLS
      port: 443
      tls:
        mode: Passthrough
      hostname: "example.com"
      allowedRoutes:
        namespaces:
          from: Same
```

A TCPRoute: 

```
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TCPRoute
metadata:
  name: passthrough-route
  namespace: default
spec:
  parentRefs:
  - name: example-passthrough
  rules:
  - backendRefs:
    - name: example-tls-svc
      port: 443
```

We don't recommend using this method as you miss out on all the extra features gateway API provides when using HTTPRoute:  

1. No Gateway-level TLS featues 
   - no way to configure TLS or setup mTLS from gatway -> backend

2. No observability at HTTP level
    - no request logs, paths status codes
    - no metrics like latency, error rates per endpoint etc.

3. No security features, header filtering, rate limiting, auth at gateway etc. 

the extra processing steps for re-encryption is well worth the added features you get... 

## Re-encryption - with Skip Verification 

We setup a HTTPRoute with termination at the gateway, then we rencrypt the traffic using TLS certs given by the backend service. BUT we don't verify the backend cert - this is useful when using self-signed certs for internal traffic

This allows us to use letsencrypt to encrypt traffic from client -> gateway. We can use cert-manager to manage these certs and generate HTTP-01 challenges: 

Read more here: https://cert-manager.io/docs/usage/gateway/

install cert-manager - https://cert-manager.io/docs/installation/
```
helm install \
  cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true
```

This is equivalent to Nginx annotation: 
`nginx.ingress.kubernetes.io/force-ssl-redirect: "true"`

We've provided you with example letsencrypt clusterissuer, gateway, httproute and example deployment to show you how it works...

```
kubectl apply -f clusterIssuer.yaml
kubectl apply -f gateway.yaml
kubectl apply -f httproute.yaml
kubectl apply -f deployment.yaml
```

Choose one of two methods below for either secure or insecure TLS for the backend

### Skip TLS Verify using Envoy Gateway Backend 

Envoy Gateway Backend API is considered a security risk and is not enabled by default. To enable backend, you need to configure the envoy gateway helm chart and reinstall it

Follow the steps here: https://gateway.envoyproxy.io/v1.5/install/install-helm/#enable-backend-api

The Backend resource can attach to a K8s service, allowing you to configure how traffic is managed. 

Here you can specify `spec.tls.insecureSkipVerify: true`  to prevent verifying the backend TLS cert - works well if you're using self-signed certs.

learn more here: https://gateway.envoyproxy.io/contributions/design/backend/

You can test this out using our examples

1. generate a self-signed cert
```
openssl req -x509 -new -nodes -key /tmp/tls.key -sha256 -days 60 -out /tmp/tls.crt -subj "/CN=tls.example.com
```

2. create a k8s secret to hold cert
```
# delete existing certs if exist as they conflict
kubectl delete -f internal-tls.yaml

kubectl create secret tls backend-tls --cert="/tmp/tls.crt" --key="/tmp/tls.key" --dry-run=client -o yaml | kubectl apply -f - echo
```

3. apply the test deployment 
```
kubectl apply -f deployment.yaml
```

5. apply the backend 
```
# delete existing backendTLSPolicy as it conflicts
kubectl delete -f backendTLSPolicy.yaml

kubectl apply -f backend.yaml
```

6. test the connection by connecting to tls.example.com 
- you'll need to add tls.example.com to your `/etc/hosts`

We don't recommend this method, setting up insecure verification for internal TLS means that any service can masquerade as your service. Especially because CAPI internal networks use a VLAN rather than a physical separate network

### Re-encryption - with system certs  

To setup proper backend TLS, we need verifiable backend certs. 

We use BackendTLSPolicy which attaches to our service and manages how we verify incoming certificates and what SNI we are expecting

We can use cert-manager to setup a clusterIssuer that can issue internal TLS certs to encrypt east-west (backend) traffic on your cluster. 

We will also need to install trust-manager -  https://cert-manager.io/docs/trust/trust-manager/. Trust manager will create and manage certificate bundles (stored as configMaps on each namespace) that we can mount onto pods/backendTLSPolicies to sign/verify internal certificates

In our example we setup a self-signed root-CA. But you can mount your own well-known root-CA secret for your internal clusterIssuer to use for added security.

deploy internal-tls.yaml and backendTLSPolicy.yaml : 

1. apply the internal-tls cert-manager setup
```
# delete existing secret if exists
kubectl delete secret backend-tls

kubectl apply -f internal-tls.yaml
```

2. apply the backendTLSPolicy
```
# delete existing backend resource
kubectl delete -f backend.yaml

kubectl apply -f backendTLSPolicy.yaml 
``` 

3. test the connection by connecting to tls.example.com 
- you'll need to add tls.example.com to your `/etc/hosts`


## Backend Mutual TLS - mTLS

In normal TLS - client verifies the server identity. but for added security, the server can verify the client's identity. 

In this case the service can verify that the request is being forwarded from the gateway and not something masqeurading as the gateway. 

If you want to setup mTLS:

1. You'll need to setup your backend service to require mTLS
2. You'll need to create another certificate for your gateway:
- then provide it via `clientCertificateRef` in backendTLSPolicy - see backendTLSPolicy.yaml comments
- You can sign this with the same internal clusterIssuer and mount the Trustmanager Bundle onto your pod.. but this is left as an exercise to the user
  
Mutual TLS may be a overkill and may not be worth it - many out-of-the-box services may not even setup client verification...
