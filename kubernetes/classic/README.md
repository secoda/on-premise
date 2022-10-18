# Secoda On-Premise (GKE, Kubernetes)

This deployment option uses **Google Kubernetes Engine**.

## Initial Steps

1. Please refer to the [Google Cloud documentation](https://cloud.google.com/kubernetes-engine/docs/deploy-app-cluster#standard) for creating a GKE cluster. 

2. Authenticate to Secoda's image registry

```bash
kubectl create secret docker-registry secoda-dockerhub --docker-server=https://index.docker.io/v1/ --docker-username=secodaonprem --docker-password=<CUSTOMER_SPECIFIC_PASSWORD> --docker-email=andrew@secoda.co
```

```bash
REGION=northamerica-northeast1
gcloud compute zones list --filter=region:$REGION

gcloud container clusters create secoda \
    --release-channel regular \
    --zone $REGION \
    --node-locations $REGION-b,$REGION-c \
    --machine-type=t2d-standard-1
```

Customer support will provide you with an organization-specific `--docker-password`.

3. Create a Postgres database. We recommend using [Google Cloud SQL](https://cloud.google.com/sql) to achieve this. You could also use any other managed Postgres provider, or host it yourself. 


Once your database cluster is created, connect to it and then create two seperate databases on it.

```bash
psql -h <HOST> -U postgres
```

```bash
create database keycloak;
create database secoda;
```

You will have to authorize inbound traffic to the database from your GKE cluster and perhaps your own local computer.

4. Update `secoda-secrets.yaml` with your database details. Please ensure all of your credentials are encoded as base64

### NOTE: 
When using the `base64` command line tool to encode data, `-n` must be used, or encoding will be done including new line character, `echo -n 'input' | openssl base64`.

**api_postgres_connection_string** - it has to be in the format of `postgresql://<USERNAME>:<PASSWORD>@<HOST>:5432/secoda` before being encoded as base64

**auth_db_url** - base64 encoding of your postgres host, in this format `jdbc:postgresql://<HOST>/keycloak`

**auth_db_password** - base64 encoding of your database password, this should be the same as the password in the `api_postgres_connection_string`

**keycloak_admin_password** - we suggest using, already in b64 `openssl rand -hex 20 | cut -c 1-16 | base64`

**keycloak_secret** - the result of this command, already in b64 `openssl rand -hex 20 | cut -c 1-32 | base64`

**api_secret** - the result of this command, already in b64 `uuidgen | tr '[:upper:]' '[:lower:]' | base64`

You may need to run `brew upgrade openssl` to generate these.

**private_key** - `openssl genrsa -out secoda.private.pem 2048 && echo "Copy the following:" && cat secoda.private.pem | base64 | tr -d \\n | base64`

**public_key** - `openssl rsa -in secoda.private.pem -pubout > secoda.public.pem && echo "Copy the following:" && cat secoda.public.pem | base64 | tr -d \\n | base64`

5. (Optional) in `secoda-frontend.yaml`, `secoda-worker.yaml`, `secoda-api.yaml`, and `secoda-redis.yaml` modify the resources accessible by each pod to increase/decrease the amount of CPU and RAM they can utilize


## TLS/HTTPS Configuration (Required)
 
Here, we use a self-signed certificate, but we suggest using a valid Google-managed certificate.

Create the self-signed certifcate:

```bash
openssl genrsa -out ingress.key 2048

openssl req -new -key ingress.key -out ingress.csr \
    -subj "/CN=secoda.<COMPANY>.com"

openssl x509 -req -days 365 -in ingress.csr -signkey ingress.key \
    -out ingress.crt
```

Create the k8s secret.

```bash
kubectl create secret tls lb \
    --cert ingress.crt --key ingress.key
```

Replace the host in `secoda-lb.yaml` with `secoda.<COMPANY>.com`.

Create the load balancer.

```
kubectl apply -f secoda-lb.yaml
```

Point an A record at the IP from the above describe command.

## Deployment

1. Run the following commands to deploy Secoda

```bash
kubectl apply -f secoda-lb.yaml
kubectl apply -f secoda-secrets.yaml
kubectl apply -f secoda-redis.yaml
kubectl apply -f secoda-frontend.yaml
kubectl apply -f secoda-api.yaml
kubectl apply -f secoda-worker.yaml
kubectl apply -f secoda-nginx.yaml
kubectl apply -f secoda-auth.yaml
```

2. Once it is all done, access your DNS name.
