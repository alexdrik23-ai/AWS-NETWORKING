# Fetch all available AZs in the selected region
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Use only as many AZs as subnets provided
  az_count = min(
    length(var.public_subnet_cidrs),
    length(var.private_subnet_cidrs),
    length(data.aws_availability_zones.available.names)
  )

  availability_zones = slice(data.aws_availability_zones.available.names, 0, local.az_count)

  # NAT Gateway count: one per AZ or just one depending on var
  nat_gateway_count = var.single_nat_gateway ? 1 : local.az_count

  # Project/Environment/ManagedBy are already applied by provider default_tags.
  # Only carry additional_tags here to avoid duplicate-key plan diffs.
  common_tags = var.additional_tags
}
