// first create an HTTP server: 80 TCP, 22 TCP, CIDR ["0.0.0.0/0"]
// then create a security group with the above config

// meant to replace the default vpc
resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

// LB SG
resource "aws_security_group" "elb_sg" {
  name = "elb_sg"
  // vpc_id = "vpc-075343a660b9eb15c"
  // using the default value
  vpc_id = aws_default_vpc.default.id

  // IN -> ingress: where to allow traffic from
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.cidr
  }

  // IN -> ingress for ssh
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.cidr
  }

  // OUT -> egress: what can you do from this server
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

}

// create the load balancer
resource "aws_elb" "elb" {
  name = "elb"
  subnets = data.aws_subnet_ids.default_subnets.ids
  security_groups = [aws_security_group.elb_sg.id]
  instances = values(aws_instance.http_servers).*.id

  // configure a port 
  listener {
    instance_port = 80
    instance_protocol = http
    lb_port = 80
    lb_protocol = http
  }
}

resource "aws_security_group" "http_server_sg" {
  name = "http_server_sg"
  // vpc_id = "vpc-075343a660b9eb15c"
  // using the default value
  vpc_id = aws_default_vpc.default.id

  // IN -> ingress: where to allow traffic from
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.cidr
  }

  // IN -> ingress for ssh
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.cidr
  }

  // OUT -> egress: what can you do from this server
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    name = "http_server_sg"
  }
}

// create a virtual server
resource "aws_instance" "http_servers" {
  // ami                    = "ami-033b95fb8079dc481"
  // from data.aws_ami
  ami                    = data.aws_ami.latest_aws_linux_2.id
  key_name               = var.ec2_key
  instance_type          = var.ec2_instance_type
  vpc_security_group_ids = [aws_security_group.http_server_sg.id]
  // get this from vpc on aws
  for_each  = data.aws_subnet_ids.default_subnets.ids
  subnet_id = each.value

  // tags = {
  //   name : "http_servers_${each.value}"
  // }

  connection {
    # indicate the kinda connection you want to use
    type = var.ec2_connection_type
    # where do you want to connect to? a public or private ip?
    host = self.public_ip
    # whiich ec2 user do you want to use? aws, by default, automatically assigns ec2-user to a newly created instance
    user = var.ec2_user
    # configure a private key
    private_key = file(var.aws_key_pair)
  }
  # create, start and send a file to the server
  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd -y",
      "sudo service httpd start",
      "echo i recreated this and it is being displayed via my aws server situated at ${self.public_dns}  |  sudo tee /var/www/html/index.html"
    ]
  }
}