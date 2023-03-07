# Renew Certificates

The CA certificates used in the **tls** operations of these pods need to be periodically renewed. Specifically, there are four which need to be updated:
1. [./jsonnet/vendor/github.com/observatorium/observatorium/configuration/tests/manifests/observatorium-xyz-tls-configmap.yaml](./jsonnet/vendor/github.com/observatorium/observatorium/configuration/tests/manifests/observatorium-xyz-tls-configmap.yaml)
2. [./jsonnet/vendor/github.com/observatorium/observatorium/configuration/tests/manifests/observatorium-xyz-tls-dex.yaml](./jsonnet/vendor/github.com/observatorium/observatorium/configuration/tests/manifests/observatorium-xyz-tls-dex.yaml)
3. [./jsonnet/vendor/github.com/observatorium/observatorium/configuration/tests/manifests/observatorium-xyz-tls-secret.yaml](./jsonnet/vendor/github.com/observatorium/observatorium/configuration/tests/manifests/observatorium-xyz-tls-secret.yaml)
4. [./jsonnet/vendor/github.com/observatorium/observatorium/configuration/tests/manifests/test-ca-tls.yaml](./jsonnet/vendor/github.com/observatorium/observatorium/configuration/tests/manifests/test-ca-tls.yaml)

**observatorium-xyz-tls-configmap.yaml** needs to be updated next on **Mar 5 16:41:00 2028 GMT**  
**observatorium-xyz-tls-dex.yaml** needs to be updated next on **Mar 6 16:41:00 2024 GMT**  
**observatorium-xyz-tls-secret.yaml** needs to be updated next on **Mar 6 16:41:00 2024 GMT**  
**test-ca-tls.yaml** needs to be updated next on **Mar 5 16:41:00 2028 GMT**  

To generate new CA certificates, clone the observatorium project https://github.com/observatorium/observatorium, then run:

```bash
$ make ./configuration/tests/manifests --always-make
```

After the certs are generated, copy the newly generated certs into **observatorium-operator**.