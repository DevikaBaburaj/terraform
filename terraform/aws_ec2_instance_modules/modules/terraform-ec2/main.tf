locals {
   env = "test"
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
  key_name   = var.key_name
  public_key = var.public_key
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
  subnet_id     = var.subnet_id
  user_data              = var.user_data

  key_name = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.ec2-sec.id]

  ebs_block_device {
    device_name = var.device_name
    volume_size = var.volume_size
    volume_type = var.volume_type
  }

  depends_on = [aws_security_group.alb-sec,aws_security_group.ec2-sec]
  tags = {
    Name = title("${local.env}-WEB")
  }
}


// Target group & ALB

resource "aws_security_group" "alb-sec" {
  vpc_id =  var.vpc_id
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
  name               = var.alb_name
  internal           = var.internal
  load_balancer_type = var.load_balancer_type
  security_groups    = [aws_security_group.alb-sec.id]
#  subnets            = [element(aws_subnet.public_subnet.*.id,0),element(aws_subnet.public_subnet.*.id,1)]
  subnets            = flatten([var.alb_subnets])
  tags = {
    Environment = title("${local.env}-alb")
  }
}

resource "aws_lb_target_group" "alb-tg" {
  name     = var.tg_name
  port     = var.tg_port
  protocol = var.tg_protocol
  deregistration_delay = var.deregistration_delay
  vpc_id   = var.vpc_id
  target_type = var.target_type

  health_check {
    healthy_threshold   = var.healthy_threshold
    interval            = var.interval
    protocol            = var.tg_protocol
    matcher             = var.matcher
    timeout             = var.timeout
    port                = var.tg_port
    path                = var.path
    unhealthy_threshold = var.unhealthy_threshold
    }


  tags = {
    Name = title("${local.env}-TARGET-GROUP")
  }

}

resource "aws_lb_target_group_attachment" "test" {
  count            = length(aws_instance.web.*.id)
  target_group_arn = aws_lb_target_group.alb-tg.arn
  target_id        = element(aws_instance.web.*.id,count.index)
  port             = var.tg_port
}

// EC2 ALB LISTENER

resource "aws_alb_listener" "ec2-listener-http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = var.tg_port
  protocol          = var.tg_protocol

  default_action {
    target_group_arn    = aws_lb_target_group.alb-tg.arn
    type  = "forward"
  }
}

// EC2-ALB SECURITY GROUP
resource "aws_security_group" "ec2-sec" {
  vpc_id =  var.vpc_id
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
