data "aws_route53_zone" "domain" {
  zone_id = var.r53_id
}

resource "aws_lb" "ecs_balancer" {
  name = "wordpress-${random_string.install.id}"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.sg.id]
  subnets = [aws_subnet.sn1.id, aws_subnet.sn2.id]
  ip_address_type = "dualstack"
}

resource "aws_lb_target_group" "ecs_target" {
  name = "wordpress-${random_string.install.id}"
  target_type = "ip"
  port        = 80
  protocol    = "HTTPS"
  vpc_id = aws_vpc.vpc.id
  health_check {
    interval = 30
    matcher = "200-299"
    path = "/"
    port = "80"
  }
}

resource "aws_security_group" "sg" {
  name = "wordpress-${random_string.install.id}"
  description = "port 80"
  vpc_id = aws_vpc.vpc.id

  ingress {
    description      = "TLS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/22"
  assign_generated_ipv6_cidr_block = true
  tags = {
    Name = "wordpress-${random_string.install.id}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "sn1" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.0.0/23"
  availability_zone = data.aws_availability_zones.available.names[0]
  ipv6_cidr_block = cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, 1)
}

resource "aws_subnet" "sn2" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.2.0/23"
  availability_zone = data.aws_availability_zones.available.names[1]
  ipv6_cidr_block = cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, 2)
}
