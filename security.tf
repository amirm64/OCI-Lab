resource "oci_core_network_security_group" "proxy" {
  compartment_id = var.compartment_ocid
  vcn_id         = data.oci_core_vcn.selected.id
  display_name   = "nsg-proxy"
}

resource "oci_core_network_security_group" "apps" {
  compartment_id = var.compartment_ocid
  vcn_id         = data.oci_core_vcn.selected.id
  display_name   = "nsg-apps"
}

# ── Ingress rules for proxy VM ───────────────────────────────────────────
resource "oci_core_network_security_group_security_rule" "proxy_https" {
  network_security_group_id = oci_core_network_security_group.proxy.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source_type               = "CIDR_BLOCK"
  source                    = "0.0.0.0/0"
  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "proxy_http" {
  network_security_group_id = oci_core_network_security_group.proxy.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source_type               = "CIDR_BLOCK"
  source                    = "0.0.0.0/0"
  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

# ── Ingress rule for apps VM (allow only from proxy-NSG) ─────────────────
resource "oci_core_network_security_group_security_rule" "apps_from_proxy" {
  network_security_group_id = oci_core_network_security_group.apps.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source_type               = "NETWORK_SECURITY_GROUP"
  source                    = oci_core_network_security_group.proxy.id
  tcp_options {
    destination_port_range {
      min = 80
      max = 443
    }
  }
}

# ── Egress: allow all traffic out (updates, package repos, etc.) ─────────
resource "oci_core_network_security_group_security_rule" "proxy_egress_all" {
  network_security_group_id = oci_core_network_security_group.proxy.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination_type          = "CIDR_BLOCK"
  destination               = "0.0.0.0/0"
}

resource "oci_core_network_security_group_security_rule" "apps_egress_all" {
  network_security_group_id = oci_core_network_security_group.apps.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination_type          = "CIDR_BLOCK"
  destination               = "0.0.0.0/0"
}

resource "oci_core_network_security_group_security_rule" "apps_from_proxy_ssh" {
  network_security_group_id = oci_core_network_security_group.apps.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source_type               = "NETWORK_SECURITY_GROUP"
  source                    = oci_core_network_security_group.proxy.id
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}