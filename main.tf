# Webserver creation 
resource "aws_launch_template" "example" {
  image_id        = "ami-0e8d228ad90af673b"
  instance_type   = "t2.micro"
  network_interfaces {
    security_groups = [aws_security_group.instance.id]
  }

user_data = base64encode(<<-EOF
                #!/bin/bash
                echo "Hello World" > index.html
                nohup busybox httpd -f -p ${var.server_port} &
                EOF
)
  # Required when using a launch configuration with an autoscaling group
  lifecycle {
    create_before_destroy = true
  }
}

# Creation of the ASG 
resource "aws_autoscaling_group" "example" {
  launch_template {
  id      = aws_launch_template.example.id
  version = "$Latest"
}
  vpc_zone_identifier  = data.aws_subnets.default.ids

  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"

  min_size = 2
  max_size = 10

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

# Allowing traffic on port 8080 with a security group
resource "aws_security_group" "instance" {
  name = "terraform-example-instance"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Creation of a ALB 
resource "aws_lb" "example" {
  name               = "terraform-asg-example"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  # By default return a simple 404 propagate_at_launch
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

resource "aws_security_group" "alb" {
    name = "terraform-example-alb"

    # Allow inbound HTTP requests
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # Allow outbound requests
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# Creation of a target group for the ASG 
resource "aws_lb_target_group" "asg" {
    name = "terraform-asg-example"
    port = var.server_port
    protocol = "HTTP"
    vpc_id = data.aws_vpc.default.id

    health_check {
        path = "/"
        protocol = "HTTP"
        matcher = "200"
        interval = 15
        timeout = 3
        healthy_threshold = 2
        unhealthy_threshold = 2
    }

}

# Listener rule
resource "aws_lb_listener_rule" "asg" {
    listener_arn = aws_lb_listener.http.arn 
    priority = 100

    condition {
        path_pattern {
            values = ["*"]
        }
    }

    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.asg.arn 
    }
}