### NOTE: If you have previously applied an earlier version of our terraform:

Before pulling the latest changes and running terraform, always take a backup of your data and confirm it is viable.

This public branch contains _breaking changes_ if you have a previous deployment with our private repository. The latest version of Secoda **only** uses Postgres. These changes **will delete** your neo4j instance. Please consult with us before deploying. You must also run this command before applying new tf infrastructure: `terraform state mv 'module.vpc' 'module.vpc[0]'`

# Secoda On-Premise (AWS, Terraform)

This deployment option uses **ECS Fargate**, RDS Postgres, Elasticcache Redis, and AWS Elasticsearch. These files will create a secure, separate VPC that will run Secoda on ECS (via Fargate).

## Initial Steps

1. `cp rename.onprem.tfvars onprem.tfvars` then fill `onprem.tfvars` in:

```bash
docker_password="*****"
```

2. (Optional) If you want to use a valid certificate, decide on the domain for this service in advance. Typically, it is `secoda.yourcompany.com`. Create a signed certificate in AWS (in ACM) for this domain make sure it is in the `AWS_REGION` you are going to run the terraform in.

```bash
docker_password="*****"
certificate_arn = "arn:aws:acm:us-east-1:982277954161:certificate/42238321-4205-4798-81ba-56e6d1098933"
aws_region = "us-east-1"
```

## Deployment

1. Fill in administrator keys for `AWS_ACCESS_KEY` `AWS_SECRET_ACCESS_KEY` and the region you would like to deploy to `AWS_REGION`.

```bash
# Install terraform (for MacOS here)
brew install terraform
# `cd` to this cloned repository.
# Initialize terraform
terraform init
AWS_ACCESS_KEY=<YOUR_KEY> AWS_SECRET_ACCESS_KEY=<YOUR_KEY> AWS_REGION=<REGION> terraform apply -var-file="onprem.tfvars"
```

1. Type `Yes` at the prompt.
2. Once complete, terraform will output the load balancer DNS name. You must create a CNAME record with your DNS provider that points `secoda.yourcompany.com` to the load balancer DNS name.
3. Wait about 5 minutes. Then open `https://secoda.yourcompany.com` to test out the service. It will only listen on **HTTPS**.
4. Optional: we suggest using _Cloudflare ZeroTrust_ to limit access to Secoda.
5. **You're done! 🎊**

## Connecting to Secoda

- Load balancer is publicly accessible by default (DNS name is returned after running `terraform apply`). There will be a delay on first setup as the registration target happens ~5 minutes.
- Containers are in private subnets by default. They cannot be accessed from outside the network (VPC). If you need to do maintenance, we suggest using a solution like Tailscale.
- We suggest using _Cloudflare ZeroTrust_ to limit access to Secoda.

## Network configuration for integrations

By default, this terraform code will put the on-premise version of Secoda in a separate VPC (#1 below).

There are three different ways of connecting your on-premise integrations to Secoda:

1. Whitelisting and setting up security rules for the NAT Gateway EIP to your resource. **(VPC to Internet to VPC)** (Default)
   - Works out the box.
2. AWS VPC Peering and whitelisting security rules for access from the AWS VPC network. **(VPC to VPC)**
   - Requires manual setup or additional terraform code.
3. Put Secoda in the same VPC and setup security rules to your resource. **(intra-VPC)**
   - You can override VPC variables in `onprem.tf` to achieve this.

We are happy to help with any of these steps. (ping @LikeCarter).

## Updating to the latest minor version

NOTE: Ensure no one is entering information into Secoda at the time of update. There will be approximately 3-4 minutes of downtime.

1. Go to ECS > Cluster (Secoda Cluster) > Tasks.
2. Check the _single_ running Secoda task. Click Stop.
3. Wait about 30 seconds for a new task to start automatically. Do not force a new task to start. Hit the refresh button to check. It will pull the latest version of Secoda.

## SSO

1. You can configure SSO by logging into the master realm located here:

```bash
https://secoda.yourcompany.com/auth/admin/master/console/#/realms/secoda
```

1. Once logged in, switch to the `Secoda` realm and proceed with adding SSO.
2. Proceed with either of the following guides (please contact customer support for access to these guides).

- Google
- Microsoft
- Okta
- OneLogin
- SAML2.0

## Troubleshooting (Common Errors)

`MalformedPolicyDocumentException: Policy contains a statement with one or more invalid service principals`: please try using a different AWS administrator account, or create a new one with a different name.

`Subnets can currently only be created in the following availability zones: us-west-1b, us-west-1c`: This is due to using inconsistent regions in the `tfvars` file and the `AWS_REGION` environment variable. Make sure these are consistent.

`Error: error creating ELBv2 Listener (arn:aws:elasticloadbalancing:***): ValidationError: Certificate ARN 'arn:aws:acm:us-west-1:482836992928:certificate/***' is not valid`: This is due to the certificate being in a different region than the deployment.

# Misc.

## Hashicorp Cloud (Optional)

If your state files are stored in Hashicorp cloud (recommended), please complete the following steps. You should be a member of a _Terraform Cloud_ account before proceeding.

In this directory, run `terraform login`. In `versions.tf` please uncomment the following lines and replace `secoda` with your organization name.

```yaml
backend "remote" {
  organization = "secoda"
}
```

## Resources Created

- VPC, Public, Database, Private Subnets
- RDS - Postgres Instance
- OpenSearch - ElasticSearch Instance
- Redis - Elasticache Instance
- ECS Fargate Cluster, Service, and Task Definition
- Load Balancer
- Monitoring Alarms
- IAM Policies and Roles
