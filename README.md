# AWS Networking — High Availability VPC for EKS

Terraform module that provisions a production-ready, highly available VPC designed to host an Amazon EKS cluster.

## Architecture

```
VPC (configurable CIDR)
├── Availability Zone A
│   ├── Public Subnet   → Internet Gateway → Internet
│   ├── Private Subnet  → NAT Gateway A    → Internet
│   └── NAT Gateway A   (Elastic IP)
├── Availability Zone B
│   ├── Public Subnet   → Internet Gateway → Internet
│   ├── Private Subnet  → NAT Gateway B    → Internet
│   └── NAT Gateway B   (Elastic IP)
└── Availability Zone C
    ├── Public Subnet   → Internet Gateway → Internet
    ├── Private Subnet  → NAT Gateway C    → Internet
    └── NAT Gateway C   (Elastic IP)
```

**EKS worker nodes run in private subnets.** Public subnets are used only for load balancers and NAT Gateways.

## EKS Subnet Tags

Subnets are tagged so EKS and the AWS Load Balancer Controller can auto-discover them:

| Tag | Subnet | Purpose |
|-----|--------|---------|
| `kubernetes.io/cluster/<cluster-name>` = `shared` | Both | EKS cluster discovery |
| `kubernetes.io/role/elb` = `1` | Public | External load balancers |
| `kubernetes.io/role/internal-elb` = `1` | Private | Internal load balancers |

## Usage

```bash
# 1. Copy and fill in your variables
cp terraform.tfvars.example terraform.tfvars

# 2. Initialize Terraform
terraform init

# 3. Preview the plan
terraform plan

# 4. Apply
terraform apply
```

## Variables

| Name | Description | Required |
|------|-------------|----------|
| `aws_region` | AWS region | yes |
| `project_name` | Project name for naming/tagging | yes |
| `environment` | Environment (dev/staging/prod) | yes |
| `cluster_name` | EKS cluster name (for subnet tags) | yes |
| `vpc_cidr` | VPC CIDR block | yes |
| `public_subnet_cidrs` | List of public subnet CIDRs (≥2) | yes |
| `private_subnet_cidrs` | List of private subnet CIDRs (≥2) | yes |
| `single_nat_gateway` | Use 1 NAT GW instead of one-per-AZ | no (default: false) |
| `additional_tags` | Extra tags for all resources | no |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | VPC ID |
| `vpc_cidr_block` | VPC CIDR |
| `public_subnet_ids` | Public subnet IDs |
| `private_subnet_ids` | Private subnet IDs |
| `nat_gateway_ids` | NAT Gateway IDs |
| `nat_gateway_public_ips` | NAT Gateway public IPs |
| `availability_zones` | AZs used |

## Cost Note

With `single_nat_gateway = false` (default), one NAT Gateway is created per AZ for full HA. Each NAT Gateway costs ~$0.045/hr. Set `single_nat_gateway = true` for non-production environments to reduce cost.

## Requirements

| Tool | Version |
|------|---------|
| Terraform | >= 1.5.0 |
| AWS Provider | ~> 5.0 |
