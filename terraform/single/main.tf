variable "cluster_name" {}

variable "region" {}
variable "vpc_id" {}
variable "subnet_id" {}
variable "security_group_id" {}

variable "count" {
  default = 1
}

provider "aws" {
  region = "${var.region}"
}

resource "aws_instance" "webops" {
  ami                    = "ami-a8d2d7ce"
  instance_type          = "t2.micro"
  key_name               = "webops-key"
  subnet_id              = "${var.subnet_id}"
  vpc_security_group_ids = ["${var.security_group_id}"]
  count                  = "${var.count}"

  provisioner "local-exec" {
    command = "(echo '[${var.cluster_name}]'; echo '${self.public_ip}') >> ../ansible/inventory"
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

output "ip" {
  value = "${aws_instance.webops.public_ip}"
}
