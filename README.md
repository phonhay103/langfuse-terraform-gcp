![GitHub Banner](https://github.com/langfuse/langfuse-k8s/assets/2834609/2982b65d-d0bc-4954-82ff-af8da3a4fac8)

# GCP Langfuse Terraform module

> This module is a pre-release version and its interface may change. 
> Please review the changelog between each release and create a GitHub issue for any problems or feature requests.

This repository contains a Terraform module for deploying [Langfuse](https://langfuse.com/) - the open-source LLM observability platform - on GCP.
This module aims to provide a production-ready, secure, and scalable deployment using managed services whenever possible.

![gcp-architecture](https://github.com/user-attachments/assets/a8fb739f-1757-451e-9808-e77ebfa2d334)


## Usage

1. Enable required APIs on your Google Cloud Account:
- Certificate Manager API
- Cloud DNS API
- Compute Engine API
- Container File System API
- Google Cloud Memorystore for Redis API
- Kubernetes Engine API
- Network Connectivity API
- Service Networking API

2. Set up the module with the settings that suit your need. Providing a `domain` is optional but recommended for production environments.

```hcl
module "langfuse" {
  source = "github.com/langfuse/langfuse-terraform-gcp?ref=0.1.2"

  # Optional: Domain name if you want DNS and TLS configuration
  domain = "langfuse.example.com"

  # Optional use a different name for your installation
  # e.g. when using the module multiple times on the same GCP project
  name   = "langfuse"

  # Optional: Configure the VPC
  subnetwork_cidr = "10.0.0.0/16"

  # Optional: Configure the Langfuse Helm chart version
  langfuse_chart_version = "1.2.15"
}

provider "kubernetes" {
  host                   = module.langfuse.cluster_host
  cluster_ca_certificate = module.langfuse.cluster_ca_certificate
  token                  = module.langfuse.cluster_token
}

provider "helm" {
  kubernetes {
    host                   = module.langfuse.cluster_host
    cluster_ca_certificate = module.langfuse.cluster_ca_certificate
    token                  = module.langfuse.cluster_token
  }
}
```

2. Apply the GKE Cluster and DNS zone (if a domain is provided). This avoids an error around missing dependencies on the [kubernetes_manifest](https://github.com/hashicorp/terraform-provider-kubernetes/issues/1775).

```bash
terraform init
terraform apply --target module.langfuse.google_container_cluster.this
# Only if you provided a domain:
terraform apply --target 'module.langfuse.google_dns_managed_zone.this[0]'
```

3. If you provided a domain, set up the Nameserver delegation on your DNS provider. You can find the nameservers using the following command. Replace `langfuse` with your zone name, e.g. `langfuse-example-com`.

```bash
$ gcloud dns managed-zones describe langfuse --format="get(nameServers)"
```

4. Apply the full stack

```bash
terraform apply
```

5. Start using Langfuse by navigating to your instance:
   - If you provided a domain: `https://<domain>` in your browser.
   - If you didn't provide a domain: Use the external IP of the LoadBalancer (you can find it via `kubectl get svc -n langfuse`).

### Known issues

1. Getting an `ERR_SSL_VERSION_OR_CIPHER_MISMATCH` error after installation on the HTTPS endpoint.

Since Google Cloud takes a while (~20 Minutes) to provision new certificates, an invalid TLS certificate is presented for a while after initial installation of this module. Please use `gcloud compute ssl-certificates list` to check the current provisioning status. If it is still in `PROVISIONING` state this issue is expected. E.g.

```bash
$ gcloud compute ssl-certificates list
NAME      TYPE     CREATION_TIMESTAMP             EXPIRE_TIME  REGION  MANAGED_STATUS
langfuse  MANAGED  2025-04-06T03:41:54.791-07:00                       PROVISIONING
    <hostname>: PROVISIONING
```

When the certificate becomes active the ingress controller should pick it up and present a valid TLS certificate:

```bash
$ gcloud compute ssl-certificates list
NAME      TYPE     CREATION_TIMESTAMP             EXPIRE_TIME                    REGION  MANAGED_STATUS
langfuse  MANAGED  2025-04-06T03:41:54.791-07:00  2025-07-05T03:41:56.000-07:00          ACTIVE
    <hostname>: ACTIVE
```

## Features

This module creates a complete Langfuse stack with the following components:

- VPC with public and private subnets
- GKE cluster with node pools
- Cloud SQL PostgreSQL instance
- Cloud Memorystore Redis instance
- Cloud Storage bucket for storage
- TLS certificates and Cloud DNS configuration
- Required IAM roles and firewall rules
- GKE Ingress Controller for ingress
- Filestore CSI Driver for persistent storage

## Requirements

| Name        | Version |
|-------------|---------|
| terraform   | >= 1.0  |
| google      | >= 5.0  |
| google-beta | >= 5.0  |
| kubernetes  | >= 2.10 |
| helm        | >= 2.5  |

## Providers

| Name        | Version |
|-------------|---------|
| google      | >= 5.0  |
| google-beta | >= 5.0  |
| kubernetes  | >= 2.10 |
| helm        | >= 2.5  |
| random      | >= 3.0  |
| tls         | >= 3.0  |

## Resources

| Name                                        | Type     |
|---------------------------------------------|----------|
| google_container_cluster.langfuse           | resource |
| google_container_node_pool.default          | resource |
| google_sql_database_instance.postgres       | resource |
| google_sql_database.langfuse                | resource |
| google_sql_user.langfuse                    | resource |
| google_redis_instance.redis                 | resource |
| google_storage_bucket.langfuse              | resource |
| google_compute_managed_ssl_certificate.cert | resource |
| google_dns_managed_zone.zone                | resource |
| google_dns_record_set.langfuse              | resource |
| google_service_account.gke                  | resource |
| google_project_iam_member.gke               | resource |
| google_compute_firewall.gke                 | resource |
| google_compute_firewall.postgres            | resource |
| google_compute_firewall.redis               | resource |
| google_compute_network.vpc                  | resource |
| google_compute_subnetwork.subnet            | resource |
| google_kms_key_ring.langfuse                | resource |
| google_kms_crypto_key.langfuse              | resource |
| kubernetes_namespace.langfuse               | resource |
| kubernetes_secret.langfuse                  | resource |
| helm_release.ingress_nginx                  | resource |
| helm_release.cert_manager                   | resource |
| random_password.database                    | resource |
| tls_private_key.langfuse                    | resource |

## Inputs

| Name                                | Description                                                                                    | Type   | Default                 | Required |
|-------------------------------------|------------------------------------------------------------------------------------------------|--------|-------------------------|:--------:|
| name                                | Name to use for or prefix resources with                                                       | string | "langfuse"              |    no    |
| domain                              | Domain name used to host langfuse on (e.g., langfuse.company.com)                              | string | null                    |    no    |
| use_encryption_key                  | Wheter or not to use an Encryption key for LLM API credential and integration credential store | bool   | true                    |    no    |
| kubernetes_namespace                | Namespace to deploy langfuse to                                                                | string | "langfuse"              |    no    |
| subnetwork_cidr                     | CIDR block for Subnetwork                                                                      | string | "10.0.0.0/16"           |    no    |
| database_instance_tier              | The machine type to use for the database instance                                              | string | "db-perf-optimized-N-2" |    no    |
| database_instance_edition           | The edition to use for the database instance                                                   | string | "ENTERPRISE_PLUS"       |    no    |
| database_instance_availability_type | The availability type to use for the database instance                                         | string | "REGIONAL"              |    no    |
| cache_tier                          | The service tier of the instance                                                               | string | "STANDARD_HA"           |    no    |
| cache_memory_size_gb                | Redis memory size in GB                                                                        | number | 1                       |    no    |
| deletion_protection                 | Whether or not to enable deletion_protection on data sensitive resources                       | bool   | true                    |    no    |
| langfuse_chart_version              | Version of the Langfuse Helm chart to deploy                                                   | string | "1.2.15"                 |    no    |

## Outputs

| Name                   | Description                      |
|------------------------|----------------------------------|
| cluster_name           | GKE Cluster Name                 |
| cluster_host           | GKE Cluster endpoint             |
| cluster_ca_certificate | GKE Cluster CA certificate       |
| cluster_token          | GKE Cluster authentication token |

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. Here are some ways you can contribute:
- Add support for new cloud providers
- Improve existing configurations
- Add monitoring and alerting templates
- Improve documentation
- Report issues

## Support

- [Langfuse Documentation](https://langfuse.com/docs)
- [Langfuse GitHub](https://github.com/langfuse/langfuse)
- [Join Langfuse Discord](https://langfuse.com/discord)

## License

MIT Licensed. See LICENSE for full details.
