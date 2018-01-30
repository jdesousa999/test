provider "aws" {
	region 		= "eu-west-3"
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  default = 8080
}
variable "ssh_port" {
  description = "The port the ssh server will listen on"
  default = 22
}

resource "aws_security_group" "instance" {
  name = "terraform-example-instance"
  ingress {
    from_port   = "${var.server_port}"
    to_port     = "${var.server_port}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = "${var.ssh_port}"
    to_port     = "${var.ssh_port}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_security_group" "elb" {
  name = "terraform-example-elb"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
/*
resource "aws_instance" "example" {
	ami 		= "ami-bfff49c2"
	instance_type	= "t2.micro"
	vpc_security_group_ids = ["${aws_security_group.instance.id}"]
        key_name        = "paris"
	user_data	= <<-EOF
			#!/bin/bash
			echo "Hello, World" > index.html
			nohup busybox httpd -f -p 8080 &
			EOF

	tags {
		Name	= "terraform-example"
	}
}
*/
resource "aws_launch_configuration" "example" {
  image_id        = "ami-63b4021e"
  instance_type   = "t2.micro"
  security_groups = ["${aws_security_group.instance.id}"]
  key_name        = "paris"

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_autoscaling_group" "example" {
  launch_configuration = "${aws_launch_configuration.example.id}"
  availability_zones = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]

  min_size = 2
  max_size = 10

  load_balancers = ["${aws_elb.example.name}"]
  health_check_type = "ELB"

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}


resource "aws_elb" "example" {
  name               = "terraform-asg-example"
  availability_zones = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = "${var.server_port}"
    instance_protocol = "http"
  }
}

output "elb_dns_name" {
  value = "${aws_elb.example.dns_name}"
}

