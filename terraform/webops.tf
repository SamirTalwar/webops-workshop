variable "region" {}
variable "vpc_id" {}
variable "subnet_id" {}

variable "count" {
  default = 1
}

variable "cloudflare_email" {}
variable "cloudflare_token" {}

variable "domain" {}
variable "subdomain" {}

provider "cloudflare" {
  email = "${var.cloudflare_email}"
  token = "${var.cloudflare_token}"
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

resource "aws_instance" "webops" {
  ami                    = "ami-a8d2d7ce"
  instance_type          = "t2.micro"
  key_name               = "webops-key"
  subnet_id              = "${var.subnet_id}"
  vpc_security_group_ids = ["${aws_security_group.webops.id}"]
  count                  = "${var.count}"

  provisioner "local-exec" {
    command = "if [[ ! -f ../ansible/inventory ]]; then echo '[aws]' > ../ansible/inventory; fi"
  }

  provisioner "local-exec" {
    command = "echo '${self.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/webops' >> ../ansible/inventory"
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file("~/.ssh/webops")}"
    }

    inline = [
      "sudo apt-get update -qq",
      "sudo apt-get install -qy python",
    ]
  }
}

resource "cloudflare_record" "webops" {
  domain = "${var.domain}"
  name   = "${var.subdomain}"
  value  = "${aws_instance.webops.public_ip}"
  type   = "A"
  ttl    = 120
}
