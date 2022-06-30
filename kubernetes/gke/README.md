# Secoda On-Premise (GKE, Kubernetes)

This deployment option uses **Google Kubernetes Engine**.

## Initial Steps

1. Please refer to the [Google Cloud documentation](https://cloud.google.com/kubernetes-engine/docs/deploy-app-cluster#standard) for creating a GKE cluster. 

2. Authenticate to Secoda's image registry

```bash
kubectl create secret docker-registry secoda-dockerhub --docker-server=registry.hub.docker.com --docker-username=secodaonprem --docker-password=****** --docker-email=andrew@secoda.co
```

3. Create a Postgres database. We recommend using [Google Cloud SQL](https://cloud.google.com/sql) to achieve this. You could also use any other managed Postgres provider or host it yourself. 

Once your database cluster is created, connect to it and then create two seperate databases on it.

```bash
psql -h your-postgres-ip -U postgres
```

```bash
create database api;
create database auth;
```

You will have to authorize inbound traffic to the database from your GKE cluster and perhaps your own local computer.

4. Update `secoda-secrets.yaml` with your database details. Please ensure all of your credentials are encoded as base64

**api_postgres_connection_string** - it has to be in the format of `postgresql://username:password@host:5432/api` before being encoded as base64

**auth_db_addr** - base64 encoding of your postgres host

**auth_db_database** - base64 encoding of your database name for auth service. It will be called `auth` if you used the commands from step 3

**auth_db_user** - base64 encoding of your postgres db user. If you used cloud sql, this will be `postgres`

**auth_db_schema** - base64 encoding of `public`

**auth_db_password** - base64 encoding of your database password

**doppler_token** - base64 encoding of the doppler token provided to you by Secoda team

**keycloak_admin_password** - base64 encoding of the password to login to the admin panel of Keycloak

**keycloak_user** - base64 encoding of the username for your keycloak admin user

Once you have filled in all the values, please run the following:

```bash
kubectl apply -f secoda-secrets.yaml
```

5. (Optional) in `secoda-frontend.yaml`, `secoda-worker.yaml`, `secoda-api.yaml`, and `secoda-redis.yaml` modify the resources accessible by each pod to increase/decrease the amount of CPU and RAM they can utilize

## Deployment

1. Run the following commands to deploy Secoda

```bash
kubectl apply -f secoda-redis.yaml
kubectl apply -f secoda-frontend.yaml
kubectl apply -f secoda-api.yaml
kubectl apply -f secoda-worker.yaml
kubectl apply -f secoda-nginx.yaml
```

2. Once it is all done, go the port 80 of the `nginx` pod to access Secoda
