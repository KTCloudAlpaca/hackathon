# ===== VPC 설정 =====
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = {
    Name = "accordion-vpc"
  }
}

# ============ 가용영역 A ===================
# ===== Public Subnet A =====
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_sub_a_cidr
  availability_zone       = var.availability_zone_a
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = {
    Name = "accordion-public-subnet-a"
  }
}

# ===== Private Subnet A =====
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_sub_a_cidr
  availability_zone = var.availability_zone_a

  tags = {
    Name = "accordion-private-subnet-a"
  }
}

# ============ 가용영역 C ===================
# ===== Public Subnet C =====
resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_sub_c_cidr
  availability_zone       = var.availability_zone_c
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = {
    Name = "accordion-public-subnet-c"
  }
}

# ===== Private Subnet C =====
resource "aws_subnet" "private_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_sub_c_cidr
  availability_zone = var.availability_zone_c

  tags = {
    Name = "accordion-private-subnet-c"
  }
}

# ============ 가용영역 D ===================
# ===== Public Subnet D =====
resource "aws_subnet" "public_d" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_sub_d_cidr
  availability_zone       = var.availability_zone_d
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = {
    Name = "accordion-public-subnet-d"
  }
}

# ===== Private Subnet D =====
resource "aws_subnet" "private_d" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_sub_d_cidr
  availability_zone = var.availability_zone_d

  tags = {
    Name = "accordion-private-subnet-d"
  }
}

# ===== Internet Gateway =====
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "accordion-igw"
  }
}

# ===== Public Route Table =====
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "accordion-public-rt"
  }
}

# ===== Public Route Table -> Internet Gateway =====
resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# ===== Public Subnet 연결 (A, C, D) =====
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_d" {
  subnet_id      = aws_subnet.public_d.id
  route_table_id = aws_route_table.public.id
}

# ===== NAT Gateway Elastic IPs (A, C, D 3개) =====
resource "aws_eip" "nat_a" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "accordion-nat-eip-a"
  }
}

resource "aws_eip" "nat_c" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "accordion-nat-eip-c"
  }
}

resource "aws_eip" "nat_d" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "accordion-nat-eip-d"
  }
}

# ===== NAT Gateways (Public Subnet A, C, D 각 1개씩 총 3개) =====
resource "aws_nat_gateway" "nat_a" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat_a[0].id
  subnet_id     = aws_subnet.public_a.id

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "accordion-nat-a"
  }
}

resource "aws_nat_gateway" "nat_c" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat_c[0].id
  subnet_id     = aws_subnet.public_c.id

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "accordion-nat-c"
  }
}

resource "aws_nat_gateway" "nat_d" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat_d[0].id
  subnet_id     = aws_subnet.public_d.id

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "accordion-nat-d"
  }
}

# ===== Private Route Tables (A, C, D 3개 개별 분리) =====
resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "accordion-private-rt-a"
  }
}

resource "aws_route_table" "private_c" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "accordion-private-rt-c"
  }
}

resource "aws_route_table" "private_d" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "accordion-private-rt-d"
  }
}

# ===== Private Route -> 각 AZ별 NAT Gateway 매핑 =====
resource "aws_route" "private_internet_a" {
  count = var.enable_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.private_a.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_a[0].id
}

resource "aws_route" "private_internet_c" {
  count = var.enable_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.private_c.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_c[0].id
}

resource "aws_route" "private_internet_d" {
  count = var.enable_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.private_d.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_d[0].id
}

# ===== Private Subnet -> 해당 AZ 라우팅 테이블 1:1 연결 =====
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "private_c" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private_c.id
}

resource "aws_route_table_association" "private_d" {
  subnet_id      = aws_subnet.private_d.id
  route_table_id = aws_route_table.private_d.id
}