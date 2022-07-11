# Secoda On-Premise (GKE, Kubernetes)

This deployment option uses **Google Kubernetes Engine**.

## Initial Steps

1. Please refer to the [Google Cloud documentation](https://cloud.google.com/kubernetes-engine/docs/deploy-app-cluster#standard) for creating a GKE cluster. 

2. Authenticate to Secoda's image registry

```bash
kubectl create secret docker-registry secoda-dockerhub --docker-server=https://index.docker.io/v1/ --docker-username=secodaonpremise --docker-password=<CUSTOMER_SPECIFIC_PASSWORD> --docker-email=carter@secoda.co
```

```bash
REGION=northamerica-northeast1
gcloud compute zones list --filter=region:$REGION

gcloud container clusters create secoda \
    --release-channel regular \
    --zone $REGION \
    --node-locations $REGION-b,$REGION-c
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

4. Update `values.yaml` with your database details.

**apiPostgresConnectionString** - it has to be in the format of `postgresql://<USERNAME>:<PASSWORD>@<HOST>:5432/secoda`

**authDbUrl** - the db host, this should be the same as the host in `apiPostgresConnectionString`

**authDbPassword** - your database password, this should be the same as the password in the `apiPostgresConnectionString`

**keycloakAdminPassword** - we suggest using `openssl rand -hex 20 | cut -c 1-16`

**keycloakSecret** - the result of this command `openssl rand -hex 20 | cut -c 1-32`

**apiSecret** - the result of this command `uuidgen | tr '[:upper:]' '[:lower:]'`

You may need to run `brew upgrade openssl` to generate these.

**privateKey** - `openssl genrsa -out secoda.private.pem 2048 && echo "Copy the following:" && cat secoda.private.pem | tr -d \\n`

**publicKey** - `openssl rsa -in secoda.private.pem -pubout > secoda.public.pem && echo "Copy the following:" && cat secoda.public.pem | tr -d \\n`

5. (Optional) in `values.yaml` modify the resources accessible by each pod to increase/decrease the amount of CPU and RAM they can utilize

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

Replace the host in `lb.yaml` with `secoda.<COMPANY>.com`.

## Deploy

```
helm install secoda helm
```
