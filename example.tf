provider "aws" {
  profile    = "default"
  region     = "us-east-2"
}

resource "aws_vpc" "example" {
  cidr_block	= "10.0.0.0/24"
}

resource "aws_subnet" "sub" {
  vpc_id	= aws_vpc.example.id
  availability_zone	= "us-east-2a"
  cidr_block	= "10.0.0.0/28"
}
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.example.id}"

  tags = {
    Name = "public"
  }
}

resource "aws_default_route_table" "r" {
  default_route_table_id = "${aws_vpc.example.default_route_table_id}"

  route {
    cidr_block = "0.0.0.0/0"
	gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags = {
    Name = "default table"
  }
}

resource "aws_ecs_cluster" "test" {
  name = "ecs-test"
}
resource "aws_instance" "web" {
  ami           = "ami-035ad8e6117e5fde5"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.sub.id
  associate_public_ip_address = "1"
  key_name = "kiran"
  user_data = <<EOF
		#! /bin/bash
		stop ecs
		echo "ECS_CLUSTER=ecs-test" >> /etc/ecs/ecs.config 
		start ecs
  EOF
  iam_instance_profile = "${aws_iam_instance_profile.test_profile.name}"
  tags = {
    Name = "ECS-test"
  }
}
resource "aws_iam_role" "test_role" {
  name = "ecs_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    tag-key = "ECS-Full-Access"
  }
}

resource "aws_iam_policy" "policy" {
  name        = "ecs_policy"
  path        = "/"
  description = "ECS policy"

  policy = <<EOF
{
		"Version": "2012-10-17",
		"Statement": [{
				"Effect": "Allow",
				"Action": [
					"ecr:GetDownloadUrlForLayer",
					"ecr:BatchGetImage",
					"ecr:DescribeImages",
					"ecr:DescribeRepositories",
					"ecr:ListImages",
					"ecr:BatchCheckLayerAvailability",
					"ecr:GetRepositoryPolicy"
				],
				"Resource": "*"
			},
			{
				"Effect": "Allow",
				"Action": [
					"ecs:DeregisterContainerInstance",
					"ecs:DiscoverPollEndpoint",
					"ecs:Poll",
					"ecs:RegisterContainerInstance",
					"ecs:StartTelemetrySession",
					"ecs:Submit*",
					"ecr:GetAuthorizationToken"
				],
				"Resource": "*"
			}
		]
}
EOF
}
resource "aws_iam_policy_attachment" "test-attach" {
  name       = "test-attachment"
  roles      = ["${aws_iam_role.test_role.name}"]
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_iam_instance_profile" "test_profile" {
  name = "test_profile"
  role = "${aws_iam_role.test_role.name}"
}
