# Envoy Gateway basicauth example

You can use Envoy Gateway to setup a basic auth layer before forwarding onto your service

## Prerequeiste
This example re-uses the existing gateway and example app deployed in `envoy-gateway/README.md` please make sure you've deployed these resources before continuing

1. Create basic auth credentials for each user - append to file

# Build the file
htpasswd -csb /tmp/pass alice password1
htpasswd -b  /tmp/pass bob password2

# Create the secret from the file 
kubectl create secret generic basic-auth-secret \
  --from-file=.htpasswd=/tmp/pass


2. Apply the securitypolicy file

`kubectl apply -f security-policy-basicauth.yaml`

make sure secret and security policy both in namespace that's the same as the httproute it applies to

Now you'll see that a basic login screen pops up before you can access the hello world page - `http://my.example.com` 