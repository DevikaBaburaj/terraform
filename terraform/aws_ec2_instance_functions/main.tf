provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

locals {
  env = "test"
}

// VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = title("${local.env}-vpc")

  }
}

// PUBLIC SUBNETS
resource "aws_subnet" "public_subnet" {
  count                   = length(var.pub_cidr_block) 
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = element(var.pub_cidr_block, count.index)
  map_public_ip_on_launch = true
  availability_zone       = element(var.az, count.index)
  tags = {
    Name = title("${local.env}-public-subnet-1")

  }
}

// PRIVATE SUBNETS
resource "aws_subnet" "private_subnet" {
  count             = length(var.priv_cidr_block)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = element(var.priv_cidr_block, count.index)
  availability_zone = element(var.az, count.index)
  tags = {
    Name = title("${local.env}-public-subnet-2")

  }
}

// IGW
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = title("${local.env}-igw")

  }
}

// EIP
resource "aws_eip" "nat_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.ig]
  tags = {
    Name = title("${local.env}-eip")

  }
}

// NAT
resource "aws_nat_gateway" "nat" {
  count         = var.nat_gateway_count
  allocation_id = element(aws_eip.nat_eip.*.id, count.index)
  subnet_id     = element(aws_subnet.public_subnet.*.id, count.index)
  depends_on    = [aws_internet_gateway.ig]
  tags = {
    Name = title("${local.env}-nat")
  }
}

// PUBLIC ROUTE
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = title("${local.env}-public-route-table")

  }
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig.id
}

// PRIVATE ROUTE
resource "aws_route_table" "private" {
  count  = length(aws_nat_gateway.nat.*.id)
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = title("${local.env}-private-route-table")

  }
}

resource "aws_route" "private_nat_gateway" {
  count                  = var.nat_gateway_count
  route_table_id         = element(aws_route_table.private.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.nat.*.id, count.index)
}

// PUBLIC ROUTE TABLE ASSOCIATION
resource "aws_route_table_association" "public_subnet" {
  count          = length(aws_subnet.public_subnet.*.id)
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

// PRIVATE ROUTE TABLE ASSOCIATION
resource "aws_route_table_association" "private_subnet" {
  count          = length(aws_subnet.private_subnet.*.id)
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}

// AMI
data "aws_ami" "amzlinux2" {
  most_recent = true
  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }


  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

// KEY
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("~/.ssh/id_rsa.pub")
}


// IAM ROLE
resource "aws_iam_role" "s3-role" {
  name = "s3-ec2-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "AmazonES3BucketPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.s3-role.name
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.s3-role.name
}

// EC2 INSTANCE
resource "aws_instance" "web" {
  count         = "${var.instance_type == "t2.micro" ? 1 : 0}"
  ami           = data.aws_ami.amzlinux2.id
  instance_type = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
  subnet_id     = element(aws_subnet.private_subnet.*.id,0)
  user_data              = file("install_apache.sh")

  key_name = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.ec2-sec.id]

  ebs_block_device {
    device_name = "/dev/sdf"
    volume_size = max(10,30,20)
    volume_type = "gp2"
  }

  depends_on = [aws_security_group.alb-sec,aws_security_group.ec2-sec]
  tags = {
    Name = title("${local.env}-WEB")
  }
}


// Target group & ALB

resource "aws_security_group" "alb-sec" {
  vpc_id =  aws_vpc.vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = title("${local.env}-alb-sg")
  }
}
resource "aws_lb" "alb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb-sec.id]
#  subnets            = [element(aws_subnet.public_subnet.*.id,0),element(aws_subnet.public_subnet.*.id,1)]
  subnets            = flatten([aws_subnet.public_subnet.*.id])
  tags = {
    Environment = title("${local.env}-alb")
  }
}

resource "aws_lb_target_group" "alb-tg" {
  name     = "tf-lb-tg"
  port     = 80
  protocol = "HTTP"
  deregistration_delay = 30
  vpc_id   = aws_vpc.vpc.id
  target_type = "instance"

  health_check {
    healthy_threshold   = "3"
    interval            = "40"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "30"
    port                = "80"
    path                = "/"
    unhealthy_threshold = "2"
    }


  tags = {
    Name = title("${local.env}-TARGET-GROUP")
  }

}

resource "aws_lb_target_group_attachment" "test" {
  count            = length(aws_instance.web.*.id)
  target_group_arn = aws_lb_target_group.alb-tg.arn
  target_id        = element(aws_instance.web.*.id,count.index)
  port             = 80
}

// EC2 ALB LISTENER

resource "aws_alb_listener" "ec2-listener-http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn    = aws_lb_target_group.alb-tg.arn
    type  = "forward"
  }
}

// EC2-ALB SECURITY GROUP
resource "aws_security_group" "ec2-sec" {
  vpc_id =  aws_vpc.vpc.id
  ingress {
    description = "Allow SSH traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = title("${local.env}-ec2-sg")
  }
}

resource "aws_security_group_rule" "example" {
  type              = "ingress"
  from_port         = "80"
  to_port           = "80"
  protocol          = "tcp"
  source_security_group_id = aws_security_group.alb-sec.id
  security_group_id = aws_security_group.ec2-sec.id
}
