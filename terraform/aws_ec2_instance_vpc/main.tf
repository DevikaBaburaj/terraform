provider "aws" {
  region = "us-east-1"
  profile = "default"
}

// VPC

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "test-vpc"
    
  }
}

// PUBLIC SUBNETS

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.0.0/18"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
 tags = {
    Name = "test-public-subnet-1"

  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.64.0/18"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"
 tags = {
    Name = "test-public-subnet-2"

  }
}

//PRIVATE SUBNET

resource "aws_subnet" "private_subnet_1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.128.0/18"
  availability_zone       = "us-east-1a"
 tags = {
    Name = "test-private-subnet-1"

  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.192.0/18"
  availability_zone       = "us-east-1b"
 tags = {
    Name = "test-private-subnet-2"

  }
}

// IGW

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "test-igw"
    
  }
}

// EIP

resource "aws_eip" "nat_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.ig]
   tags = {
    Name        = "test-eip"

  }
}
// NAT

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id
  depends_on    = [aws_internet_gateway.ig]
  tags = {
    Name = "test-nat"
  }
}

// PUBLIC ROUTE

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name        = "test-public-route-table"
    
  }
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig.id
}

// PRIVATE ROUTE

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name        = "test-private-route-table"
    
  }
}

resource "aws_route" "private_nat_gateway" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}


// PUBLIC ROUTE TABLE ASSOCIATION

resource "aws_route_table_association" "public_subnet_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_subnet_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public.id
}

// PRIVATE ROUTE TABLE ASSOCIATION

resource "aws_route_table_association" "private_subnet_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_subnet_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private.id
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
  ami           = data.aws_ami.amzlinux2.id
  instance_type = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
  subnet_id     = aws_subnet.private_subnet_1.id
  user_data              = file("install_apache.sh")

  key_name = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.ec2-sec.id]
  
  ebs_block_device {
    device_name = "/dev/sdf"
    volume_size = 60
    volume_type = "gp2"
  }

  depends_on = [aws_security_group.alb-sec,aws_security_group.ec2-sec]
  tags = {
    Name = "WEB"
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
    Name = "alb-sg"
  }
}
resource "aws_lb" "alb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb-sec.id]
  subnets            = [aws_subnet.public_subnet_1.id,aws_subnet.public_subnet_2.id]

  tags = {
    Environment = "test"
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
    Name = "test-TARGET-GROUP"
  }

}

resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = aws_lb_target_group.alb-tg.arn
  target_id        = aws_instance.web.id
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
    Name = "ec2-sg"
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
