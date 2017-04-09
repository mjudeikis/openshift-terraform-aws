
#VPC for OCP
module "vpc_base" {
  source = "github.com/unifio/terraform-aws-vpc?ref=master//base"

  enable_dns          = "true"
  enable_hostnames    = "true"
  stack_item_fullname = "OCP"
  stack_item_label    = "ocp"
  vpc_cidr            = "10.20.0.0/16"
}

#Bastion IP for server
resource "aws_eip" "bastion" {
  instance = "${aws_instance.ocp_bastion.id}"
  vpc      = true
}

#NATS IP for 3 private zone internet access
#TODO: we could add different nats for differetn AZ
resource "aws_eip" "nats_ip" {
  vpc      = true
}

#NATS gateway for 3 private subnets
#TODO: we could add different nats for differetn AZ
resource "aws_nat_gateway" "gw_nats" {
  allocation_id = "${aws_eip.nats_ip.id}"
  subnet_id     = "${aws_subnet.ocp_pub.0.id}"
}

#routing table record for public subnet to use gateway
resource "aws_route_table" "public-route-table" {
   vpc_id = "${module.vpc_base.vpc_id}"
   route {
      cidr_block = "0.0.0.0/0"
      nat_gateway_id = "${module.vpc_base.igw_id}"
   }
}

#routing table record for private subnet to use nats gateway
resource "aws_route_table" "private-route-table" {
   vpc_id = "${module.vpc_base.vpc_id}"
   route {
      cidr_block = "0.0.0.0/0"
      nat_gateway_id = "${aws_nat_gateway.gw_nats.id}"
   }
}

#add public route into all subnets tables
resource "aws_route_table_association" "public-rtb" {
   count          = "${var.subnet_count}"
   subnet_id      = "${element(aws_subnet.ocp_pub.*.id, count.index)}"
   route_table_id = "${aws_route_table.public-route-table.id}"
}

#add private routing record to all private subnets
resource "aws_route_table_association" "private-rtb" {
   count          = "${var.subnet_count}"
   subnet_id      = "${element(aws_subnet.ocp_priv.*.id, count.index)}"
   route_table_id = "${aws_route_table.private-route-table.id}"
}

#create all 3 public subnets for OCP
resource "aws_subnet" "ocp_pub" {
  count = "${var.subnet_count}"
  vpc_id            = "${module.vpc_base.vpc_id}"
  availability_zone = "${element(split(",", var.availability_zones), count.index)}"
  cidr_block        = "${cidrsubnet("10.20.0.0/16", 8, count.index+1)}"
  map_public_ip_on_launch = true

  tags {
    Name = "ocp-public-subnet-${count.index}"
    purpose = "${var.label}"
  }
}

#create all 3 private subnets for OCP
resource "aws_subnet" "ocp_priv" {
  count = "${var.subnet_count}"
  vpc_id            = "${module.vpc_base.vpc_id}"
  availability_zone = "${element(split(",", var.availability_zones), count.index)}"
  cidr_block        = "${cidrsubnet("10.20.0.0/16", 8, count.index+4)}"

   tags {
    Name = "ocp-private-subnet-${count.index}"
    purpose = "${var.label}"
  }
}

#TODO: migrage security group creation to more repeatable mode. 
#security groups
resource "aws_security_group" "ocp_elb_master_sg" {
  name        = "ocp_elb_master_sg"
  description = "Externam Master/Console ELB Security group"
  vpc_id            = "${module.vpc_base.vpc_id}"

  tags {
    Name = "ocp_elb_master_sg"
    purpose = "${var.label}"
  }
}

resource "aws_security_group" "ocp_internal_elb_master_sg" {
  name        = "ocp_internal_elb_master_sg"
  description = "Internal Master/API ELB Security group"
  vpc_id            = "${module.vpc_base.vpc_id}"

  tags {
    Name = "ocp_internal_elb_master_sg"
    purpose = "${var.label}"
  }
}

resource "aws_security_group" "ocp_master_sg" {
  name        = "ocp_master_sg"
  description = "Master Security Group"
  vpc_id      = "${module.vpc_base.vpc_id}"

  tags {
    Name = "ocp_master_sg"
    purpose = "${var.label}"
  }
}

resource "aws_security_group" "bastion_sg" {
  name        = "bastion_sg"
  description = "Bastion Security Group"
  vpc_id      = "${module.vpc_base.vpc_id}"

 tags {
    Name = "bastion_sg"
    purpose = "${var.label}"
  }
}

resource "aws_security_group" "ocp_node_sg" {
  name        = "ocp_node_sg"
  description = "Node security Group"
  vpc_id      = "${module.vpc_base.vpc_id}"

 tags {
    Name = "ocp_node_sg"
    purpose = "${var.label}"
  }
}

resource "aws_security_group" "ocp_etcd_sg" {
  name        = "ocp_etcd_sg"
  description = "ETCD Security Group"
  vpc_id      = "${module.vpc_base.vpc_id}"

 tags {
    Name = "ocp_etcd_sg"
    purpose = "${var.label}"
  }
}

resource "aws_security_group" "ocp_router_sg" {
  name        = "ocp_router_sg"
  description = "Router Secuirty Group"
  vpc_id      = "${module.vpc_base.vpc_id}"

 tags {
    Name = "ocp_router_sg"
    purpose = "${var.label}"
  }
}

resource "aws_security_group" "ocp_infra_node_sg" {
  name        = "ocp_infra_node_sg"
  description = "Infra Nodes security Group"
  vpc_id      = "${module.vpc_base.vpc_id}"

 tags {
    Name = "ocp_infra_node_sg"
    purpose = "${var.label}"
  }
}

#TODO: Move rules to array and just cycle as per security group lookup
#ingress security rules form master 
resource "aws_security_group_rule" "ocp_elb_master_sg_ingress" {
  type            = "ingress"
  from_port       = 433
  to_port         = 433
  protocol        = "tcp"
  security_group_id = "${aws_security_group.ocp_elb_master_sg.id}"
  cidr_blocks = ["0.0.0.0/0"]
}

#egress security rules form master 
resource "aws_security_group_rule" "ocp_elb_master_sg_egress" {
  type            = "egress"
  from_port       = 433
  to_port         = 433
  protocol        = "tcp"
  source_security_group_id = "${aws_security_group.ocp_master_sg.id}"
  security_group_id = "${aws_security_group.ocp_elb_master_sg.id}"
}


#egress security rules form master internal
resource "aws_security_group_rule" "ocp_internal_elb_master_sg_ingress" {
  type            = "ingress"
  from_port       = 433
  to_port         = 433
  protocol        = "tcp"
  source_security_group_id = "${aws_security_group.ocp_master_sg.id}"
  security_group_id = "${aws_security_group.ocp_internal_elb_master_sg.id}"
}

#egress security rules form master internal
resource "aws_security_group_rule" "ocp_internal_elb_master_sg_ingress_2" {
  type            = "ingress"
  from_port       = 433
  to_port         = 433
  protocol        = "tcp"
  source_security_group_id = "${aws_security_group.ocp_node_sg.id}"
  security_group_id = "${aws_security_group.ocp_internal_elb_master_sg.id}"
}

resource "aws_security_group_rule" "ocp_internal_elb_master_sg_egress" {
  type            = "egress"
  from_port       = 433
  to_port         = 433
  protocol        = "tcp"
  source_security_group_id = "${aws_security_group.ocp_master_sg.id}"
  security_group_id = "${aws_security_group.ocp_internal_elb_master_sg.id}"
}


resource "aws_security_group_rule" "bastion_sg_ingress" {
  type            = "ingress"
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"
  security_group_id = "${aws_security_group.bastion_sg.id}"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "bastion_sg_egress" {
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.bastion_sg.id}"
}

resource "aws_security_group_rule" "ocp_master_sg_ingress" {
  type            = "ingress"
  from_port       = 8053
  to_port         = 8053
  protocol        = "tcp"
  source_security_group_id = "${aws_security_group.ocp_node_sg.id}"
  security_group_id = "${aws_security_group.ocp_master_sg.id}"
}

resource "aws_security_group_rule" "ocp_master_sg_ingress_2" {
  type            = "ingress"
  from_port       = 8053
  to_port         = 8053
  protocol        = "udp"
  source_security_group_id = "${aws_security_group.ocp_node_sg.id}"
  security_group_id = "${aws_security_group.ocp_master_sg.id}"
}

resource "aws_security_group_rule" "ocp_master_sg_ingress_3" {
  type            = "ingress"
  from_port       = 443
  to_port         = 443
  protocol        = "tcp"
  source_security_group_id = "${aws_security_group.ocp_internal_elb_master_sg.id}"
  security_group_id = "${aws_security_group.ocp_master_sg.id}"
}

resource "aws_security_group_rule" "ocp_master_sg_ingress_4" {
  type            = "ingress"
  from_port       = 443
  to_port         = 443
  protocol        = "tcp"
  source_security_group_id = "${aws_security_group.ocp_elb_master_sg.id}"
  security_group_id = "${aws_security_group.ocp_master_sg.id}"
}

resource "aws_security_group_rule" "ocp_master_sg_ingress_5" {
  type            = "ingress"
  from_port       = 443
  to_port         = 443
  protocol        = "tcp"
  source_security_group_id = "${aws_security_group.ocp_node_sg.id}"
  security_group_id = "${aws_security_group.ocp_master_sg.id}"
}

resource "aws_security_group_rule" "ocp_master_sg_ingress_6" {
  type            = "ingress"
  from_port       = 443
  to_port         = 443
  protocol        = "tcp"
  source_security_group_id = "${aws_security_group.ocp_master_sg.id}"
  security_group_id = "${aws_security_group.ocp_master_sg.id}"
}

resource "aws_security_group_rule" "ocp_master_sg_ingress_7" {
  type            = "ingress"
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"
  source_security_group_id = "${aws_security_group.bastion_sg.id}"
  security_group_id = "${aws_security_group.ocp_master_sg.id}"
}

resource "aws_security_group_rule" "ocp_master_sg_egress" {
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
   security_group_id = "${aws_security_group.ocp_master_sg.id}"
}

###TBC
resource "aws_security_group_rule" "ocp_etcd_sg_ingress" {
  type = "ingress"
  from_port       = 2379
  to_port         = 2379
  protocol        = "tcp"
  source_security_group_id = "${aws_security_group.ocp_etcd_sg.id}"
  security_group_id = "${aws_security_group.ocp_etcd_sg.id}"
}

resource "aws_security_group_rule" "ocp_etcd_sg_ingress_2" {
  type = "ingress"
  from_port       = 2379
  to_port         = 2379
  protocol        = "tcp"
  source_security_group_id = "${aws_security_group.ocp_master_sg.id}"
  security_group_id = "${aws_security_group.ocp_etcd_sg.id}"
}

resource "aws_security_group_rule" "ocp_etcd_sg_ingress_3" {
  type = "ingress"
  from_port       = 2380
  to_port         = 2380
  protocol        = "tcp"
  source_security_group_id = "${aws_security_group.ocp_etcd_sg.id}"
  security_group_id = "${aws_security_group.ocp_etcd_sg.id}"
}

resource "aws_security_group_rule" "ocp_etcd_sg_ingress_4" {
  type            = "ingress"
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"
  source_security_group_id = "${aws_security_group.bastion_sg.id}"
  security_group_id = "${aws_security_group.ocp_etcd_sg.id}"
}

resource "aws_security_group_rule" "ocp_etcd_sg_egress" {
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.ocp_etcd_sg.id}"
}

resource "aws_security_group_rule" "ocp_router_sg_ingress" {
  type            = "ingress"
  from_port       = 433
  to_port         = 433
  protocol        = "tcp"
  security_group_id = "${aws_security_group.ocp_router_sg.id}"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ocp_router_sg_ingress_2" {
  type            = "ingress"
  from_port       = 80
  to_port         = 80
  protocol        = "tcp"
  security_group_id = "${aws_security_group.ocp_router_sg.id}"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ocp_router_sg_egress" {
  type            = "egress"
  from_port       = 433
  to_port         = 433
  protocol        = "tcp"
  source_security_group_id = "${aws_security_group.ocp_infra_node_sg.id}"
  security_group_id = "${aws_security_group.ocp_router_sg.id}"
}

resource "aws_security_group_rule" "ocp_router_sg_egress_2" {
  type            = "egress"
  from_port       = 80
  to_port         = 80
  protocol        = "tcp"
  source_security_group_id = "${aws_security_group.ocp_infra_node_sg.id}"
  security_group_id = "${aws_security_group.ocp_router_sg.id}"
}

resource "aws_security_group_rule" "ocp_infra_node_sg_ingress" {
  type = "ingress"
  from_port       = 80
  to_port         = 80
  protocol        = "tcp"
  source_security_group_id = "${aws_security_group.ocp_router_sg.id}"
  security_group_id = "${aws_security_group.ocp_infra_node_sg.id}"
}

resource "aws_security_group_rule" "ocp_infra_node_sg_ingress_2" {
  type = "ingress"
  from_port       = 443
  to_port         = 443
  protocol        = "tcp"
  source_security_group_id = "${aws_security_group.ocp_router_sg.id}"
  security_group_id = "${aws_security_group.ocp_infra_node_sg.id}"
}

resource "aws_security_group_rule" "ocp_infra_node_sg_ingress_3" {
  type            = "ingress"
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"
  source_security_group_id = "${aws_security_group.bastion_sg.id}"
  security_group_id = "${aws_security_group.ocp_infra_node_sg.id}"
}

resource "aws_security_group_rule" "ocp_infra_node_sg_egress" {
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.ocp_infra_node_sg.id}"
}

resource "aws_security_group_rule" "ocp_node_sg_ingress" {
  type = "ingress"
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"
  source_security_group_id = "${aws_security_group.bastion_sg.id}"
  security_group_id = "${aws_security_group.ocp_node_sg.id}"
}

resource "aws_security_group_rule" "ocp_node_sg_ingress_2" {
  type = "ingress"
  from_port       = 10250
  to_port         = 10250
  protocol        = "tcp"
  source_security_group_id = "${aws_security_group.ocp_master_sg.id}"
  security_group_id = "${aws_security_group.ocp_node_sg.id}"
}

resource "aws_security_group_rule" "ocp_node_sg_ingress_3" {
  type = "ingress"
  from_port       = 4789
  to_port         = 4789
  protocol        = "udp"
  source_security_group_id = "${aws_security_group.ocp_node_sg.id}"
  security_group_id = "${aws_security_group.ocp_node_sg.id}"
}

resource "aws_security_group_rule" "ocp_node_sg_ingress_4" {
  type = "ingress"
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"
  source_security_group_id = "${aws_security_group.bastion_sg.id}"
  security_group_id = "${aws_security_group.ocp_node_sg.id}"
}

resource "aws_security_group_rule" "ocp_node_sg_egress" {
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.ocp_node_sg.id}"
}

# Create a internal load balancer masters
resource "aws_elb" "ocp_internal" {
  name               = "openshift-internal-elb"
  #availability_zones = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  internal = true
  subnets = ["${aws_subnet.ocp_priv.*.id}"]
  instances = ["${aws_instance.ocp_master.*.id}"]
  security_groups = ["${aws_security_group.ocp_internal_elb_master_sg.id}"]

  listener {
    instance_port      = 443
    instance_protocol  = "tcp"
    lb_port            = 443
    lb_protocol        = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 15
    target              = "TCP:443"
    interval            = 30
  }

  tags {
    Name = "ocp-internal-elb"
    purpocp = "${var.label}"
  }
}

# Create a external load balancer masters
resource "aws_elb" "ocp_external" {
  name               = "openshift-external-elb"
  #availability_zones = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  subnets = ["${aws_subnet.ocp_pub.*.id}"]
  instances = ["${aws_instance.ocp_master.*.id}"]
  security_groups = ["${aws_security_group.ocp_elb_master_sg.id}"]

  listener {
    instance_port      = 443
    instance_protocol  = "tcp"
    lb_port            = 443
    lb_protocol        = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 15
    target              = "TCP:443"
    interval            = 30
  }

  tags {
    Name = "ocp-internal-elb"
    purpocp = "${var.label}"
  }
}

# Create a external load balancer masters
resource "aws_elb" "ocp_external_infra" {
  name               = "openshift-external-elb-infra"
  #availability_zones = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  subnets = ["${aws_subnet.ocp_pub.*.id}"]
  instances = ["${aws_instance.ocp_infra.*.id}"]
  security_groups = ["${aws_security_group.ocp_infra_node_sg.id}"]

  listener {
    instance_port      = 443
    instance_protocol  = "tcp"
    lb_port            = 443
    lb_protocol        = "tcp"
  }

  listener {
    instance_port      = 80
    instance_protocol  = "tcp"
    lb_port            = 80
    lb_protocol        = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 15
    target              = "TCP:443"
    interval            = 30
  }

  tags {
    Name = "ocp-internal-elb-infra"
    purpose = "${var.label}"
  }
}

#read primary zone record from our account
data "aws_route53_zone" "primary" {
  name = "${var.ocp_dns_name}"
}

#create all dns records for our app
resource "aws_route53_record" "wildcard_dns" {
  zone_id = "${data.aws_route53_zone.primary.zone_id}"
  name    = "*.apps.${var.ocp_dns_name}"
  type    = "A"

  alias {
    name                   = "${aws_elb.ocp_external_infra.dns_name}"
    zone_id                = "${aws_elb.ocp_external_infra.zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "bastion" {
  zone_id = "${data.aws_route53_zone.primary.zone_id}"
  name    = "bastion.${var.ocp_dns_name}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_eip.bastion.public_ip}"]
}

resource "aws_route53_record" "internal-masters" {
  zone_id = "${data.aws_route53_zone.primary.zone_id}"
  name    = "internal-master.${var.ocp_dns_name}"
  type    = "A"

  alias {
    name                   = "${aws_elb.ocp_internal.dns_name}"
    zone_id                = "${aws_elb.ocp_internal.zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "external-masters" {
  zone_id = "${data.aws_route53_zone.primary.zone_id}"
  name    = "openshift-master.${var.ocp_dns_name}"
  type    = "A"

  alias {
    name                   = "${aws_elb.ocp_external.dns_name}"
    zone_id                = "${aws_elb.ocp_external.zone_id}"
    evaluate_target_health = false
  }
}

#records for all servers
#masters
resource "aws_route53_record" "masters" {
  count = "${var.num_master}"
  zone_id = "${data.aws_route53_zone.primary.zone_id}"
  name    = "master-${count.index}.${var.ocp_dns_name}"
  type    = "A"
  ttl     = "300"
  records = ["${element(aws_instance.ocp_master.*.private_ip, count.index)}"]
}

#infra-nodes
resource "aws_route53_record" "infra-nodes" {
  count = "${var.num_infra}"
  zone_id = "${data.aws_route53_zone.primary.zone_id}"
  name    = "infra-node-${count.index}.${var.ocp_dns_name}"
  type    = "A"
  ttl     = "300"
  records = ["${element(aws_instance.ocp_infra.*.private_ip, count.index)}"]
}

#nodes
resource "aws_route53_record" "nodes" {
  count = "${var.num_infra}"
  zone_id = "${data.aws_route53_zone.primary.zone_id}"
  name    = "node-${count.index}.${var.ocp_dns_name}"
  type    = "A"
  ttl     = "300"
  records = ["${element(aws_instance.ocp_node.*.private_ip, count.index)}"]
}