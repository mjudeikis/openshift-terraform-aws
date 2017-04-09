#define values are mandatory and not defaultable
variable "aws_access_key" {}
variable "aws_secret_key" {}

variable "num_nodes" { default = "3" }
variable "num_master" { default = "3" }
variable "num_infra" { default = "3" }
variable "subnet_count" { default = "3" }

variable "keypair" {default = "id_rsa"}

variable "master_instance_type" {default = "t2.small"}
variable "node_instance_type" {default = "t2.small"}
variable "infra_node_instance_type" {default = "t2.small"}
variable "bastion_instance_type" {default = "t2.small"}

variable "ocp_dns_name" { default = "example.com" }

variable "ebs_root_block_size" {default = "50"}

#defaultable variables 
variable "public_key_path" {
  description = "public key path"
}

variable "label" {
  description = "common label for resources"
  default = "ocp-infra"
}

variable "key_name" {
  description = "Desired name of AWS key pair"
  default = "id_rsa"
}

variable "aws_region" {
  description = "AWS region to launch servers."
  default     = "eu-west-1"
}

variable "availability_zones" {
	default = "eu-west-1a,eu-west-1b,eu-west-1c"
	description = "The availability zones where resources are going to be created."
}

# RHEL 7
variable "aws_amis" {
  default = {
    eu-west-1 = "ami-02ace471"
  }
}
