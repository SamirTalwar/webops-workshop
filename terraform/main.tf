variable "region" {}
variable "vpc_id" {}
variable "subnet_id" {}

variable "count" {
  default = 1
}

provider "aws" {
  region = "${var.region}"
}

resource "aws_security_group" "webops" {
  name        = "webops"
  description = "WebOps workshop"
  vpc_id      = "${var.vpc_id}"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Mosh
  ingress {
    from_port   = 60000
    to_port     = 61000
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP and HTTPS
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "webops" {
  key_name   = "webops-key"
  public_key = "${file("~/.ssh/webops.pub")}"
}

module "blue" {
  source            = "./single"
  cluster_name      = "blue"
  region            = "${var.region}"
  vpc_id            = "${var.vpc_id}"
  subnet_id         = "${var.subnet_id}"
  security_group_id = "${aws_security_group.webops.id}"
  count             = "${var.count}"
}

module "green" {
  source            = "./single"
  cluster_name      = "green"
  region            = "${var.region}"
  vpc_id            = "${var.vpc_id}"
  subnet_id         = "${var.subnet_id}"
  security_group_id = "${aws_security_group.webops.id}"
  count             = "${var.count}"
}
