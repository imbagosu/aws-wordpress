# Create a VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "MAIN-VPC"
  }
}

resource "aws_subnet" "public" {
  count                   = var.public_subnet_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet("192.168.0.0/16", 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count                   = var.private_subnet_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 2) # Different CIDR for private
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "MAIN-IGW"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.main.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "MAIN-NATGW"
  }
}

resource "aws_eip" "main" {
  vpc = true
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route" "private" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

data "aws_availability_zones" "available" {}

# NACL for public subnets
resource "aws_network_acl" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Public NACL"
  }
}

# Allow inbound HTTP traffic
resource "aws_network_acl_rule" "public_in_http" {
  network_acl_id = aws_network_acl.public.id
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  rule_number    = 100
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

# Allow inbound SSH traffic from trusted IP
resource "aws_network_acl_rule" "public_in_ssh" {
  network_acl_id = aws_network_acl.public.id
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  rule_number    = 110
  cidr_block     = var.trusted_ssh_cidr # Replace with your trusted IP
  from_port      = 22
  to_port        = 22
}

# Allow outbound traffic
resource "aws_network_acl_rule" "public_out_all" {
  network_acl_id = aws_network_acl.public.id
  egress         = true
  protocol       = "-1" # All protocols
  rule_action    = "allow"
  rule_number    = 100
  cidr_block     = "0.0.0.0/0"
}

# NACL for private subnets
resource "aws_network_acl" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Private NACL"
  }
}

# Allow inbound MySQL traffic from public subnets
resource "aws_network_acl_rule" "private_in_mysql" {
  network_acl_id = aws_network_acl.private.id
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  rule_number    = 100
  cidr_block     = var.public_subnets_cidr_blocks
  from_port      = 3306
  to_port        = 3306
}

# Allow outbound traffic
resource "aws_network_acl_rule" "private_out_all" {
  network_acl_id = aws_network_acl.private.id
  egress         = true
  protocol       = "-1" # All protocols
  rule_action    = "allow"
  rule_number    = 100
  cidr_block     = "0.0.0.0/0"
}

# Associate Public NACL with public subnets
resource "aws_network_acl_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  network_acl_id = aws_network_acl.public.id
}

# Associate Private NACL with private subnets
resource "aws_network_acl_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  network_acl_id = aws_network_acl.private.id
}
