locals {
  bastion_enabled        = var.common_variables["bastion_enabled"]
  provisioning_addresses = local.bastion_enabled ? aws_instance.monitoring.*.private_ip : aws_instance.monitoring.*.public_ip
  hostname = var.common_variables["deployment_name_in_hostname"] ? format("%s-%s", var.common_variables["deployment_name"], var.name) : var.name
}

module "get_os_image" {
  source   = "../../modules/get_os_image"
  os_image = var.os_image
  os_owner = var.os_owner
}

resource "aws_instance" "monitoring" {
  count                       = var.monitoring_enabled == true ? 1 : 0
  ami                         = module.get_os_image.image_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  associate_public_ip_address = local.bastion_enabled ? false : true
  subnet_id                   = element(var.subnet_ids, 0)
  private_ip                  = var.monitoring_srv_ip
  vpc_security_group_ids      = [var.security_group_id]
  availability_zone           = element(var.availability_zones, 0)

  root_block_device {
    volume_type = "gp2"
    volume_size = "20"
  }

  ebs_block_device {
    volume_type = "gp2"
    volume_size = "10"
    device_name = "/dev/sdb"
  }

  volume_tags = {
    Name = "${var.common_variables["deployment_name"]}-${var.name}"
  }

  tags = {
    Name      = "${var.common_variables["deployment_name"]}-${var.name}"
    Workspace = var.common_variables["deployment_name"]
  }
}

module "monitoring_on_destroy" {
  source       = "../../../generic_modules/on_destroy"
  node_count   = var.monitoring_enabled ? 1 : 0
  instance_ids = aws_instance.monitoring.*.id
  user         = var.common_variables["authorized_user"]
  private_key  = var.common_variables["private_key"]
  bastion_host        = var.bastion_host
  bastion_private_key = var.common_variables["bastion_private_key"]
  public_ips   = local.provisioning_addresses
  dependencies = var.on_destroy_dependencies
}
