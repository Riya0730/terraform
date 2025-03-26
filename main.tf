terraform {
  required_version = "~>1.1"
  required_providers {
    aws = {
      version = "~>3.1"
    }
  }
}

provider "aws" {
  region     = var.my_region
  access_key = var.access_key
  secret_key = var.secret_key
}

#vpc
resource "aws_vpc" "myvpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "myvpc1"
  }

}

#internet_gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "igww"
  }
}

#websubnet
resource "aws_subnet" "web" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "web"
  }
}

#appsubnet
resource "aws_subnet" "app" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "app"
  }
}

#dbsubnet
resource "aws_subnet" "db" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "db"
  }
}

#pub rt

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.myvpc.id

  # Route for internet access (through the Internet Gateway)
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "pub_rt"
  }
}




#pvt rt
resource "aws_route_table" "pvt_rt" {
  vpc_id = aws_vpc.myvpc.id

  # No need to specify a route to "local" for internal communication within the VPC.
  # Internal VPC traffic is automatically routed.

  tags = {
    Name = "pvt_rt"
  }
}



#rt_association
resource "aws_route_table_association" "web_ass" {
  subnet_id      = aws_subnet.web.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "app_ass" {
  subnet_id      = aws_subnet.app.id
  route_table_id = aws_route_table.pvt_rt.id
}

resource "aws_route_table_association" "db_ass" {
  subnet_id      = aws_subnet.db.id
  route_table_id = aws_route_table.pvt_rt.id
}

#security_grp
resource "aws_security_group" "websg" {
  name   = "websg"
  vpc_id = aws_vpc.myvpc.id
  ingress { # inbound rule
    to_port     = 22
    from_port   = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    to_port     = 80
    from_port   = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    to_port     = 443
    from_port   = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress { #outbound rule
    to_port     = 0
    from_port   = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#app_sg
resource "aws_security_group" "appsg" {
  name   = "appsg"
  vpc_id = aws_vpc.myvpc.id
  ingress {
    to_port     = 9000
    from_port   = 9000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/24"]
  }
  egress { #outbound rule
    to_port     = 0
    from_port   = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#db_sg
resource "aws_security_group" "dbsg" {
  name   = "dbsg"
  vpc_id = aws_vpc.myvpc.id
  ingress {
    to_port     = 3306
    from_port   = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }
  egress { #outbound rule
    to_port     = 0
    from_port   = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#web_ec2
resource "aws_instance" "webec2" {
  ami                         = var.ami # value can be taken from variable.tf file
  instance_type               = var.instance_type
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.websg.id]
  # count         = 2 # 2 number of ec2 are going to be created
  tags = {
    Name = "web" # name of ec2
  }
  subnet_id = aws_subnet.web.id
  key_name  = "tf-key-pair"
}

#key_pair
resource "aws_key_pair" "tf-key-pair" {
  key_name   = "tf-key-pair"
  public_key = tls_private_key.rsa.public_key_openssh
}
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "tf-key" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "tf-key-pair"
}

#app_ec2
resource "aws_instance" "appec2" {
  ami                         = var.ami # value can be taken from variable.tf file
  instance_type               = var.instance_type
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.appsg.id]
  # count         = 2 #  2 number of ec2 are going to be created
  tags = {
    Name = "app" # name of ec2
  }
  subnet_id = aws_subnet.app.id
  key_name  = "tf-key-pair"
}

#RDS
resource "aws_db_instance" "db" {
  allocated_storage    = 10
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  username             = "root"
  password             = "pass1234"
  skip_final_snapshot  = true
  db_subnet_group_name = aws_db_subnet_group.subnetgrp.name
}


resource "aws_db_subnet_group" "subnetgrp" {
  name       = "subnetgrp"
  subnet_ids = [aws_subnet.app.id, aws_subnet.db.id]

  tags = {
    Name = "My DB subnet group"
  }
}
