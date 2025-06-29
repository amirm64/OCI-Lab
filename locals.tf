locals {
  # free-pool sizing guard
  requested_ocpus  = var.app_instance_count * var.app_ocpus
  requested_memory = var.app_instance_count * var.app_memory_gbs

  # newest compatible images
  image_x86_id = data.oci_core_images.ubuntu_x86.images[0].id
  image_arm_id = data.oci_core_images.ubuntu_arm.images[0].id
}