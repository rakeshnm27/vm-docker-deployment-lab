
# Look up the existing VPC
data "aws_vpc" "existing" {
  id = var.vpc_id
}

# Look up the existing Internet Gateway
data "aws_internet_gateway" "existing" {
  filter {
    name   = "attachment.vpc-id"
    values = [var.vpc_id]
  }
}

locals {
  public_subnets = {
    for index, cidr in var.public_subnet_cidrs :
    tostring(index) => {
      cidr = cidr
      az   = var.availability_zones[index]
    }
  }

  private_subnets = {
    for index, cidr in var.private_subnet_cidrs :
    tostring(index) => {
      cidr = cidr
      az   = var.availability_zones[index]
    }
  }
}

# Public subnets for the Application Load Balancer
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = data.aws_vpc.existing.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${each.value.az}"
    Type = "Public"
  }
}

# Private subnets for application EC2 instances
resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id                  = data.aws_vpc.existing.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-private-${each.value.az}"
    Type = "Private"
  }
}

# Public route table
resource "aws_route_table" "public" {
  vpc_id = data.aws_vpc.existing.id

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Route public subnet traffic through the existing IGW
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = data.aws_internet_gateway.existing.id
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

# Single NAT Gateway in the first public subnet
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["0"].id

  tags = {
    Name = "${var.project_name}-nat-gateway"
  }

  # Ensure the public subnet has a route to the IGW
  depends_on = [
    aws_route.public_internet
  ]
}

# Private route table
resource "aws_route_table" "private" {
  vpc_id = data.aws_vpc.existing.id

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# Route private subnet outbound traffic through NAT Gateway
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
