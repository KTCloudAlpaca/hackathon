# ===== VPC 설정 =====
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = {
    Name = "accordion-vpc"
  }
}

#============가용영역 A ===================
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
#===============================

#============가용영역 C ===================
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
#===============================

#============가용영역 D ===================
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

# ===== Private Subnet D (Worker Auto Scaling용) =====
resource "aws_subnet" "private_d" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_sub_d_cidr
  availability_zone = var.availability_zone_d

  tags = {
    Name = "accordion-private-subnet-d"
  }
}
#===============================

# ===== Internet Gateway # VPC의 인터넷 출입구 =====
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

# ===== Public Subnet A -> Public Route Table =====
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

# ===== Public Subnet C -> Public Route Table =====
resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public.id
}

# ===== Public Subnet D -> Public Route Table =====
resource "aws_route_table_association" "public_d" {
  subnet_id      = aws_subnet.public_d.id
  route_table_id = aws_route_table.public.id
}


# ===== NAT Gateway A용 Elastic IP =====
resource "aws_eip" "nat_a" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "accordion-nat-eip-a"
  }
}

# ===== NAT Gateway C용 Elastic IP =====
resource "aws_eip" "nat_c" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "accordion-nat-eip-c"
  }
}

# ===== NAT G/W Private EC2의 outbound 통신용 =====
resource "aws_nat_gateway" "nat_a" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat_a[0].id
  subnet_id     = aws_subnet.public_a.id

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "accordion-nat-a"
  }
}

# ===== NAT Gateway C outbound 통신용 =====
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

# ===== Private Route Table A =====
resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "accordion-private-rt-a"
  }
}

# ===== Private Route Table C (C/D 공유) =====
resource "aws_route_table" "private_c" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "accordion-private-rt-c"
  }
}

# ===== Private A -> NAT Gateway A =====
resource "aws_route" "private_internet_a" {
  count = var.enable_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.private_a.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_a[0].id
}

# ===== Private C -> NAT Gateway C =====
resource "aws_route" "private_internet_c" {
  count = var.enable_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.private_c.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_c[0].id
}

# ===== Private D -> NAT Gateway D =====
resource "aws_route" "private_internet_d" {
  count = var.enable_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.private_c.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_d[0].id
}

# ===== Private Subnet A -> Private Route Table A =====
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

# ===== Private Subnet C -> Private Route Table C =====
resource "aws_route_table_association" "private_c" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private_c.id
}

# ===== Private Subnet D -> Private Route Table C =====
resource "aws_route_table_association" "private_d" {
  subnet_id      = aws_subnet.private_d.id
  route_table_id = aws_route_table.private_c.id
}


# ===== NAT G/W 리소스 잘못 교체 방지 =====
# 이부분은 잘 모르지만 일단 적어두고 나중에 찾아보겠습니다!!!
# Terraform에게 기존 리소스의 관리 주소가 변경되었다는 사실을 알려주는 역할
# moved {
#   from = aws_eip.nat_a
#   to   = aws_eip.nat_a[0]
# }

# moved {
#   from = aws_nat_gateway.nat_a
#   to   = aws_nat_gateway.nat_a[0]
# }

# moved {
#   from = aws_route.private_internet
#   to   = aws_route.private_internet[0]
# }