provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  region = "us-west-2"
  alias  = "oregon"
}

// Security

resource "aws_security_group" "my-sec" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
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
    Name = "test-sg"
  }
  #provider = aws.oregon
}

// Key

resource "aws_key_pair" "webserver-key" {
  key_name   = "webserver-key"
  public_key = file("~/.ssh/id_rsa.pub")
  #provider   = aws.oregon
}

// AMI

data "aws_ami" "amzlinux2" {
  most_recent = var.most_recent
  #provider    = aws.oregon
  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }


  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}


// EC2 Instance

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amzlinux2.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.my-sec.id]
  key_name               = aws_key_pair.webserver-key.key_name
  #user_data              = file("install_apache.sh")
  #provider               = aws.oregon


  # user_data              = <<-EOT
  #                                     #! /bin/bash
  #                                     sudo yum -y update
  #                                     sudo yum -y install httpd && sudo systemctl start httpd && sudo systemctl enable httpd
  #                                     echo "<h1>Deployed via Terraform</h1>" | sudo tee /var/www/html/index.html
  #                          EOT

  provisioner "remote-exec" {
    inline = [
      "sudo yum -y install httpd && sudo systemctl start httpd",
      "echo '<h1><center>My Test Website With Help From Terraform Provisioner</center></h1>' > index.html",
      "sudo mv index.html /var/www/html/"
    ]
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/id_rsa")
      host        = aws_instance.web.public_ip
    }
  }

  provisioner "local-exec" {
    command = "echo server IP address is ${self.private_ip}"
  }

  provisioner "file" {
    source      = "./install_apache.sh"
    destination = "/home/ec2-user/install_apache.sh"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/id_rsa")
      host        = aws_instance.web.public_ip
    }
  }

  tags = {
    Name = "web"
  }
}
