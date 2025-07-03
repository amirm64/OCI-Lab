# ── Guard-rail: abort plan if free-tier limits exceeded ──────────────────
resource "null_resource" "validate_pool" {
  triggers = {
    ocpu_ok = local.requested_ocpus <= 4 ? "yes" : "no"
    mem_ok  = local.requested_memory <= 24 ? "yes" : "no"
  }

  provisioner "local-exec" {
    when    = create
    command = <<EOT
if [ "${self.triggers.ocpu_ok}" = "no" ] || [ "${self.triggers.mem_ok}" = "no" ]; then
  echo "ERROR: Requested pool (${local.requested_ocpus} OCPU, ${local.requested_memory} GB) exceeds Always-Free limit (4 OCPU, 24 GB)." >&2
  exit 1
fi
EOT
  }
}

# ── Networking ───────────────────────────────────────────────────────────
resource "oci_core_vcn" "free_vcn" {
  count          = trimspace(var.vcn_ocid) == "" ? 1 : 0
  cidr_block     = "10.0.0.0/16"
  compartment_id = var.compartment_ocid
  display_name   = "free-tier-vcn"
  dns_label      = "lab"
}

data "oci_core_vcn" "selected" {
  vcn_id = trimspace(var.vcn_ocid) == "" ? oci_core_vcn.free_vcn[0].id : var.vcn_ocid
}

resource "oci_core_subnet" "proxy_subnet" {
  cidr_block                 = var.proxy_subnet_cidr
  vcn_id                     = data.oci_core_vcn.selected.id
  compartment_id             = var.compartment_ocid
  display_name               = "proxy-public"
  dns_label                  = "proxy"
  prohibit_public_ip_on_vnic = false
}

resource "oci_core_subnet" "apps_subnet" {
  cidr_block                 = var.apps_subnet_cidr
  vcn_id                     = data.oci_core_vcn.selected.id
  compartment_id             = var.compartment_ocid
  display_name               = "apps-private"
  dns_label                  = "apps"
  prohibit_public_ip_on_vnic = true
}

# ── Proxy micro (x86) ────────────────────────────────────────────────────
resource "oci_core_instance" "proxy" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "proxy-micro"
  shape               = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    subnet_id        = oci_core_subnet.proxy_subnet.id
    assign_public_ip = true
    nsg_ids          = [oci_core_network_security_group.proxy.id]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(file("cloud-init/proxy.yml"))
  }

  source_details {
    source_type             = "image"
    source_id               = local.image_x86_id
    boot_volume_size_in_gbs = 50
  }
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = data.oci_core_vcn.selected.id
  display_name   = "free-igw"
  enabled        = true
}

resource "oci_core_route_table" "proxy_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = data.oci_core_vcn.selected.id
  display_name   = "proxy-rt-igw"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

resource "oci_core_route_table_attachment" "proxy_subnet_rt" {
  subnet_id      = oci_core_subnet.proxy_subnet.id
  route_table_id = oci_core_route_table.proxy_rt.id
}

# ── App instances (Arm) ─────────────────────────────────────────────────
resource "oci_core_instance" "app" {
  count      = var.app_instance_count
  depends_on = [null_resource.validate_pool]

  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[var.ad_index].name
  compartment_id      = var.compartment_ocid
  display_name        = "app-${count.index}"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.app_ocpus
    memory_in_gbs = var.app_memory_gbs
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.apps_subnet.id
    assign_public_ip = false
    nsg_ids          = [oci_core_network_security_group.apps.id]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(file("cloud-init/apps.yml"))
  }

  source_details {
    source_type             = "image"
    source_id               = local.image_arm_id
    boot_volume_size_in_gbs = 50
  }
}

# ── Budget €1 guard-rail ─────────────────────────────────────────────
resource "oci_budget_budget" "guardrail" {
  compartment_id = var.tenancy_ocid
  display_name   = "always-free-budget"
  amount         = 1 # €1 / month
  reset_period   = "MONTHLY"
  target_type    = "COMPARTMENT"
  targets        = [var.compartment_ocid]
}

resource "oci_budget_alert_rule" "zero_alert" {
  budget_id      = oci_budget_budget.guardrail.id
  display_name   = "free-tier-spend"
  type           = "ACTUAL"
  threshold_type = "ABSOLUTE"
  threshold      = 0.01
  message        = "Spend has exceeded zero – investigate non-free resources!"
  recipients     = var.notify_email
}