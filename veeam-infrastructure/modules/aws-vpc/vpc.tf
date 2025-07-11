# main.tf for vpc module

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-igw"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Create Public Subnets
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.az_names[count.index]
  map_public_ip_on_launch = true # Instances in this subnet get a public IP

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-subnet-${var.az_names[count.index]}"
    Environment = var.environment
    Project     = var.project_name
    Tier        = "Public"
  }
}

# Create Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.az_names[count.index]

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-subnet-${var.az_names[count.index]}"
    Environment = var.environment
    Project     = var.project_name
    Tier        = "Private"
  }
}

# Create Network Firewall Subnets
# These subnets must be isolated and dedicated for Network Firewall endpoints.
resource "aws_subnet" "firewall" {
  count             = length(var.firewall_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.firewall_subnet_cidrs[count.index]
  availability_zone = var.az_names[count.index]

  tags = {
    Name        = "${var.project_name}-${var.environment}-firewall-subnet-${var.az_names[count.index]}"
    Environment = var.environment
    Project     = var.project_name
    Tier        = "Firewall"
  }
}

# Route table for public subnets (routing to Internet Gateway and then to Network Firewall)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Default route to Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-rt"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Associate public subnets with the public route table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route table for firewall subnets (routing to Internet Gateway for egress)
# Note: In a typical Network Firewall setup, the internet-bound traffic
# from private subnets would be routed to the Firewall Endpoints, and then
# the Firewall Endpoint's route table would send it to the Internet Gateway.
# For simplicity, this example directly routes firewall subnets to IGW for their own egress,
# but the key is to ensure other subnets *send traffic to the firewall first*.
resource "aws_route_table" "firewall" {
  vpc_id = aws_vpc.main.id

  # Route traffic from firewall subnets to the internet
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-firewall-rt"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Associate firewall subnets with the firewall route table
resource "aws_route_table_association" "firewall" {
  count          = length(aws_subnet.firewall)
  subnet_id      = aws_subnet.firewall[count.index].id
  route_table_id = aws_route_table.firewall.id
}


# Route table for private subnets (traffic to Internet via Network Firewall)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # This route will be updated by the network_firewall module
  # to point to the Network Firewall endpoints for 0.0.0.0/0 traffic.
  # For now, it will just have local routes.
  tags = {
    Name        = "${var.project_name}-${var.environment}-private-rt"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Associate private subnets with the private route table
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}