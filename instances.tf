#todo:
#subnets indexes need to rotate from 1-3 and back if we have more nodes than 3

resource "aws_instance" "ocp_bastion" {
    count = 1
    ami = "${var.aws_ami}"
    instance_type = "${var.bastion_instance_type}"
    security_groups = [ "${aws_security_group.bastion_sg.id}" ]
    availability_zone = "${element(split(",", var.availability_zones), count.index)}"
    key_name = "${var.keypair}"
    associate_public_ip_address = true
    subnet_id = "${aws_subnet.ocp_pub.0.id}"
  
    tags {
      Name = "ocp-bastion"
      purpose = "${var.label}"
    }

	root_block_device = {
		volume_type = "gp2"
		volume_size = "${var.ebs_root_block_size}"
    delete_on_termination = true
	}
}

resource "aws_instance" "ocp_master" {
    count = "${var.num_master}"
    ami = "${var.aws_ami}"
    instance_type = "${var.master_instance_type}"
    security_groups = [ "${aws_security_group.ocp_master_sg.id}" ]
    availability_zone = "${element(split(",", var.availability_zones), count.index)}"
    key_name = "${var.keypair}"
    associate_public_ip_address = false
    subnet_id = "${element(aws_subnet.ocp_priv.*.id, count.index)}"

    tags {
      Name = "ocp-master-${count.index}"
      purpose = "${var.label}"
    }

	root_block_device = {
		volume_type = "gp2"
		volume_size = "${var.ebs_root_block_size}"
    delete_on_termination = true
	}
}

resource "aws_instance" "ocp_infra" {
    count = "${var.num_infra}"
    ami = "${var.aws_ami}"
    instance_type = "${var.node_instance_type}"
    security_groups = [ "${aws_security_group.ocp_infra_node_sg.id}" ]
    availability_zone = "${element(split(",", var.availability_zones), count.index)}"
    key_name = "${var.keypair}"
    associate_public_ip_address = false
    subnet_id = "${element(aws_subnet.ocp_priv.*.id, count.index)}"
    
    tags {
      Name = "ocp-infra-${count.index}"
      purpose = "${var.label}"
    }

	root_block_device = {
		volume_type = "gp2"
		volume_size = "${var.ebs_root_block_size}"
    delete_on_termination = true
	}
}

resource "aws_instance" "ocp_node" {
    count = "${var.num_nodes}"
    ami = "${var.aws_ami}"
    instance_type = "${var.infra_node_instance_type}"
    security_groups = [ "${aws_security_group.ocp_node_sg.id}" ]
    availability_zone = "${element(split(",", var.availability_zones), count.index)}"
    key_name = "${var.keypair}"
    associate_public_ip_address = false
    subnet_id = "${element(aws_subnet.ocp_priv.*.id, count.index)}"
    
     
    tags {
      Name = "ocp-nodes-${count.index}"
      purpose = "${var.label}"
    }

	root_block_device = {
		volume_type = "gp2"
		volume_size = "${var.ebs_root_block_size}"
    delete_on_termination = true
	}
}
  