# Openshift on AWS using Terraform 

This provides a template for creating Openshift Infrastructure on AWS using terraform
Based on:
https://access.redhat.com/documentation/en-us/reference_architectures/2017/html/deploying_openshift_container_platform_3.4_on_amazon_web_services/
# This is work-in-progress

TODO:

```
    Validate if all security rules is as expected
    Add SSH key clone from terraform host to bastion for seamless ssh using bastion host
    Make SG creation from array
    Make SG Rules creation from array
    Add multiple NATS for 3 AZ as not it runs in 1 public one.
    Update subnet to use CIDR from VPC
    Add S3 creation for Container registry
    Add ETCD instance creation if we want to run it outside masters. 
    Add EBS to nodes for container runtime config
    Change Default so you could bring your own SG, subnets, VPC, etc for more controlled AWS env.
    Add Ansible part for:
        Subscription managment
        Pre-req 
        cluster install
    
    Now because we provision SH and Subnets dynamically each time we execute terraform plan/apply ALL infra is redeployed. Need to find more better way we could scale infra without destroying it each time.
    Add node scalability magic
```

Create file terraform.tfvars with:

```
key_name="id_rsa-rh"
public_key_path="~/.ssh/id_rsa.pub"

aws_access_key = "xxxxxxxxx"
aws_secret_key = "xxxxxxxxxxxxxxxx"
ocp_dns_name = "containers.ninja."
```

and any other values you want to overwrite from variables.tf file

Run with a command like this:

```
terraform apply -var 'key_name={your_aws_key_name}' \
   -var 'public_key_path={location_of_your_key_in_your_local_machine}'` 
```

For example:

```
terraform apply -var 'key_name=terraform' -var 'public_key_path=/Users/jsmith/.ssh/terraform.pub'
```


# Modules:
To download VPC module:

```
terraform get
```







