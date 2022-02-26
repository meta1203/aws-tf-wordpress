data "aws_route53_zone" "domain" {
  name = var.r53_domain
  private_zone = false
}

resource "aws_route53_record" "subdomains" {
  count = length(var.r53_subdomain)
  
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = "${var.r53_subdomain[count.index]}${data.aws_route53_zone.domain.name}"
  type    = "A"

  alias {
    name = aws_lb.ecs_balancer.dns_name
    zone_id = aws_lb.ecs_balancer.zone_id
    evaluate_target_health = true
  }
}

resource "aws_lb" "ecs_balancer" {
  name = "wordpress-${random_string.install.id}"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.sg.id]
  subnets = aws_subnet.sn.*.id
  ip_address_type = "dualstack"
}

resource "aws_lb_target_group" "ecs_target" {
  name = "wordpress-${random_string.install.id}"
  target_type = "ip"
  port        = 80
  protocol    = "HTTP"
  vpc_id = aws_vpc.vpc.id

  slow_start = 300
  health_check {
    interval = 60
    matcher = "200-299"
    path = "/"
    port = "80"
  }

  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_lb_listener" "ecs_listener" {
  load_balancer_arn = aws_lb.ecs_balancer.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_target.arn
  }

  certificate_arn = aws_acm_certificate.wp_cert.arn
  # depends_on = [aws_acm_certificate_validation.wp_cert]
}

# resource "aws_lb_listener_certificate" "cert" {
#   listener_arn    = aws_lb_listener.ecs_listener.arn
#   certificate_arn = aws_acm_certificate.wp_cert.arn
  # depends_on = [aws_acm_certificate_validation.wp_cert]
#}

resource "aws_security_group" "sg" {
  name = "wordpress-${random_string.install.id}"
  description = "port 80"
  vpc_id = aws_vpc.vpc.id

  ingress {
    description      = "TLS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "EFS"
    from_port        = 2049
    to_port          = 2049
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "MySQL"
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "wordpress-${random_string.install.id}"
  }
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/20"
  assign_generated_ipv6_cidr_block = true
  enable_dns_hostnames = true # ???
  
  tags = {
    Name = "wordpress-${random_string.install.id}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id
  
  tags = {
    Name = "wordpress-${random_string.install.id}"
  }
}

resource "aws_route_table" "vpc_routing" {
  vpc_id = aws_vpc.vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "wordpress-${random_string.install.id}"
  }
}

resource "aws_subnet" "sn" {
  count = length(data.aws_availability_zones.available.names)
  
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.${count.index * 2}.0/23"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  ipv6_cidr_block = cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, count.index)

  tags = {
    Name = "wordpress-${random_string.install.id}-${count.index}"
  }
}

resource "aws_route_table_association" "a" {
  count = length(aws_subnet.sn)
  subnet_id      = aws_subnet.sn[count.index].id
  route_table_id = aws_route_table.vpc_routing.id
}

resource "aws_acm_certificate" "wp_cert" {
  domain_name = data.aws_route53_zone.domain.name
  validation_method = "DNS"
  subject_alternative_names = formatlist("%s%s", var.r53_subdomain, data.aws_route53_zone.domain.name)

  tags = {
    Environment = "test"
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_route53_record.subdomains]
}

# resource "aws_route53_record" "cert_validations" {
#  count = length(aws_acm_certificate.wp_cert.domain_validation_options)

#  zone_id = data.aws_route53_zone.domain.zone_id
#  name    = element(aws_acm_certificate.wp_cert.domain_validation_options.*.resource_record_name, count.index)
#  type    = element(aws_acm_certificate.wp_cert.domain_validation_options.*.resource_record_type, count.index)
#  records = [element(aws_acm_certificate.wp_cert.domain_validation_options.*.resource_record_value, count.index)]
#  ttl     = 60
#}

#resource "aws_acm_certificate_validation" "wp_cert" {
#  certificate_arn = aws_acm_certificate.wp_cert.arn
#  validation_record_fqdns = aws_route53_record.cert_validations.*.fqdn
#}
