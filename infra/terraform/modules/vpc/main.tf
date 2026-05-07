# Create VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.tags["ProjectName"]}-vpc"
  })
}

# Create Public Subnets
resource "aws_subnet" "public_subnet" {
  for_each                = var.public_sub_cidr
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = each.value
  map_public_ip_on_launch = true
  availability_zone       = var.azs[index(keys(var.public_sub_cidr), each.key)]

  tags = merge(var.tags, {
    Name                                               = "${var.tags["ProjectName"]}-${each.key}"
    "kubernetes.io/role/elb"                           = "1"
    "kubernetes.io/cluster/${var.tags["ProjectName"]}" = "shared"
  })
}

# Create Private Subnets
resource "aws_subnet" "private_subnet" {
  for_each          = var.private_sub_cidr
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value
  availability_zone = var.azs[index(keys(var.private_sub_cidr), each.key)]

  tags = merge(var.tags, {
    Name                                               = "${var.tags["ProjectName"]}-${each.key}"
    "kubernetes.io/role/internal-elb"                  = "1"
    "kubernetes.io/cluster/${var.tags["ProjectName"]}" = "shared"
  })
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = merge(var.tags, {
    Name = "${var.tags["ProjectName"]}-igw"
  })
}

# Create NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = values(aws_subnet.public_subnet)[0].id
  depends_on    = [aws_internet_gateway.igw]

  tags = merge(var.tags, {
    Name = "${var.tags["ProjectName"]}-nat-gateway"
  })
}

# Create Public route table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(var.tags, {
    Name = "${var.tags["ProjectName"]}-public-route-table"
  })
}

# Create Private route table
resource "aws_route_table" "private_rt" {
  vpc_id     = aws_vpc.vpc.id
  depends_on = [aws_nat_gateway.nat_gateway]
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = merge(var.tags, {
    Name = "${var.tags["ProjectName"]}-private-route-table"
  })
}

# Create Public Subnet association with public route table
resource "aws_route_table_association" "public_rt_association" {
  for_each       = var.public_sub_cidr
  route_table_id = aws_route_table.public_rt.id
  subnet_id      = aws_subnet.public_subnet[each.key].id
}

# Create Private Subnet association with private route table
resource "aws_route_table_association" "private_rt_association" {
  for_each       = var.private_sub_cidr
  route_table_id = aws_route_table.private_rt.id
  subnet_id      = aws_subnet.private_subnet[each.key].id
}