# ─── VPC ────────────────────────────────────────────────────────────────────

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-vpc"
  })
}

# ─── INTERNET GATEWAY ───────────────────────────────────────────────────────

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-igw"
  })
}

# ─── PUBLIC SUBNETS ─────────────────────────────────────────────────────────

resource "aws_subnet" "public" {
  count = local.az_count

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name                                        = "${var.project_name}-${var.environment}-public-${local.availability_zones[count.index]}"
    Tier                                        = "public"
    # Required tag for EKS to discover public subnets for external load balancers
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  })
}

# ─── PRIVATE SUBNETS ────────────────────────────────────────────────────────

resource "aws_subnet" "private" {
  count = local.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = local.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name                                        = "${var.project_name}-${var.environment}-private-${local.availability_zones[count.index]}"
    Tier                                        = "private"
    # Required tag for EKS to discover private subnets for internal load balancers
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  })
}

# ─── ELASTIC IPs FOR NAT GATEWAYS ───────────────────────────────────────────

resource "aws_eip" "nat" {
  count  = local.nat_gateway_count
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-eip-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.this]
}

# ─── NAT GATEWAYS ───────────────────────────────────────────────────────────

resource "aws_nat_gateway" "this" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-nat-${local.availability_zones[count.index]}"
  })

  depends_on = [aws_internet_gateway.this]
}

# ─── PUBLIC ROUTE TABLE ─────────────────────────────────────────────────────

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-rt-public"
  })
}

resource "aws_route_table_association" "public" {
  count = local.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ─── PRIVATE ROUTE TABLES (one per AZ for HA) ───────────────────────────────

resource "aws_route_table" "private" {
  count  = local.az_count
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[count.index].id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-rt-private-${local.availability_zones[count.index]}"
  })
}

resource "aws_route_table_association" "private" {
  count = local.az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
