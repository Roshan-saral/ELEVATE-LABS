resource "aws_vpc" "rosh_vpc" {
  cidr_block = var.roshanscidr
}

resource "aws_subnet" "rosh_sub_1" { # created the subnet 1 as in the architecture
  vpc_id                  = aws_vpc.rosh_vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true #because in the architecture we want a public subnet not a private one and if we want private then remove the map_public_ip_on_launch but we will not have accss to the subnet because it is private
}

resource "aws_subnet" "rosh_sub_2" { # created the subnet 2 as i nthe architecture
  vpc_id                  = aws_vpc.rosh_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "rosh_igw" {
  vpc_id = aws_vpc.rosh_vpc.id
}

resource "aws_route_table" "rosh_RT" {
  vpc_id = aws_vpc.rosh_vpc.id

  route { # we are trying to route the external traffic to the internet gateway
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.rosh_igw.id
  }
}

resource "aws_route_table_association" "rosh_RT_1a" { #for the internet gateway we want to connect or form a relation with the subnet and the route table so that traffic can flow through the subnet. without association we will not be able to have access to the particular subnet.
  subnet_id      = aws_subnet.rosh_sub_1.id
  route_table_id = aws_route_table.rosh_RT.id
}

resource "aws_route_table_association" "rosh_RT_1b" {
  subnet_id      = aws_subnet.rosh_sub_2.id
  route_table_id = aws_route_table.rosh_RT.id
}


resource "aws_security_group" "roshan_web_sg" { #we are creating a security group which is statefull and it is at the instance level.subnet level we have to go for NACL
  name   = "roshan_web_sg"
  vpc_id = aws_vpc.rosh_vpc.id

  ingress { #inbound rule
    description = "HTTP TRAFFIC FROM VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { #inbound rule
    description = "SSH TRAFFIC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress { # outbound rule
    description = "OUTBOUND TRAFFIC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {

    name = "roshan_web_sg"

  }
}

resource "aws_s3_bucket" "rosh_s3" { # Unique bucket creation
  bucket = "roshan20252025-bucketcreation"
}

resource "aws_instance" "ec2-instance-1" {
  ami                    = "ami-02d26659fd82cf299"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.roshan_web_sg.id]
  subnet_id              = aws_subnet.rosh_sub_1.id
  user_data_base64       = base64encode(file("roshansuserdata1.sh")) #make surethat the variable u are using is user_data_base64 not user_data because we will get a warning stating that we have to give the argument as user_data_base64
}

resource "aws_instance" "ec2-instance-2" {
  ami                    = "ami-02d26659fd82cf299"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.roshan_web_sg.id]
  subnet_id              = aws_subnet.rosh_sub_2.id
  user_data_base64       = base64encode(file("roshansuserdata2.sh"))
}

#create alb (Application load balancer)
resource "aws_lb" "roshan-my-alb" { #Elastic load balncing it is a service that we arre using and ima creating an application load balancer(aws_lb)
  name               = "roshan-my-alb"
  internal           = false # because flase means that we are making our alb as public if we want to make it as private then replace false with true.
  load_balancer_type = "application"

  security_groups = [aws_security_group.roshan_web_sg.id]
  subnets         = [aws_subnet.rosh_sub_1.id, aws_subnet.rosh_sub_2.id]

  tags = {
    Name = "ROSHAN_APPLICATION_LOAD_BALANCER_web"
  }
}

resource "aws_lb_target_group" "roshanstg" {
  name     = "roshansTG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.rosh_vpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "roshan_attach1" {
  target_group_arn = aws_lb_target_group.roshanstg.arn
  target_id        = aws_instance.ec2-instance-1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "roshan_attach2" {
  target_group_arn = aws_lb_target_group.roshanstg.arn
  target_id        = aws_instance.ec2-instance-2.id
  port             = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.roshan-my-alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.roshanstg.arn
    type             = "forward"
  }
}

output "loadbalancerdns" {# to get load balancer dns in terminal
  value = aws_lb.roshan-my-alb.dns_name
}





















