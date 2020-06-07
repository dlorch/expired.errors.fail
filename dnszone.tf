resource "google_dns_managed_zone" "errors-fail-zone" {
  name       = "errors-fail"
  dns_name   = "errors.fail."
  visibility = "public"

  dnssec_config {
    kind          = "dns#managedZoneDnsSecConfig"
    non_existence = "nsec3"
    state         = "off"
    
    default_key_specs {
      algorithm  = "rsasha256"
      key_length = 2048
      key_type   = "keySigning"
      kind       = "dns#dnsKeySpec"
    }

    default_key_specs {
      algorithm  = "rsasha256"
      key_length = 1024
      key_type   = "zoneSigning"
      kind       = "dns#dnsKeySpec"
    }
  }
}

resource "google_dns_record_set" "errors-fail-record" {
  name         = google_dns_managed_zone.errors-fail-zone.dns_name
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.errors-fail-zone.name
  rrdatas      = ["216.239.32.21", "216.239.34.21", "216.239.36.21", "216.239.38.21"] # Cloud Run
}

resource "google_dns_record_set" "probe-errors-fail-record" {
  name         = "probe.${google_dns_managed_zone.errors-fail-zone.dns_name}"
  type         = "CNAME"
  ttl          = 300
  managed_zone = google_dns_managed_zone.errors-fail-zone.name
  rrdatas      = ["ghs.googlehosted.com."] # Cloud Run
}

resource "google_dns_record_set" "packetloss-errors-fail-record" {
  name         = "packetloss.${google_dns_managed_zone.errors-fail-zone.dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.errors-fail-zone.name
  rrdatas      = [data.google_compute_instance.expired-instance.network_interface.0.access_config.0.nat_ip]
}

resource "google_dns_record_set" "expired-errors-fail-record" {
  name         = "expired.${google_dns_managed_zone.errors-fail-zone.dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.errors-fail-zone.name
  rrdatas      = [data.google_compute_instance.expired-instance.network_interface.0.access_config.0.nat_ip]
}
