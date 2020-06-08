resource "google_compute_instance_template" "expired-template" {
  name         = "expired-${random_id.instance-template-id.hex}"
  machine_type = "f1-micro"
  region       = "us-east1" # https://cloud.google.com/free/ ;-)

  tags = ["http-server", "https-server"]

  disk {
    source_image = "debian-cloud/debian-10"
    boot         = true
    disk_size_gb = 10
  }

  network_interface {
    network = "default"
    access_config {
      network_tier = "PREMIUM"
    }
  }

  service_account {
    // important! this ensures that gcloud commands in the startup script
    // have permissions to access the project
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = <<EOF
export DEBIAN_FRONTEND=noninteractive
sudo -E iptables -A INPUT -p icmp --icmp-type echo-request -m statistic --mode random --probability 0.5 -j DROP
sudo -E apt-get update && apt-get install -y iptables-persistent nginx
sudo -E systemctl enable nginx
sudo -E add-apt-repository ppa:certbot/certbot
sudo -E apt-get install -y python-certbot-nginx

# make sure to:
# - give compute service account "Secret Manager Secret Accessor" privileges
# - grant compute instance "Allow full access to all Cloud APIs"

cd / && gcloud secrets versions access latest --secret="expired-errors-fail_letsencrypt-tar" | sudo tar xf -

# these aren't secrets, but otherwise I would have to create a Cloud Store bucket just
# for these two assets...
gcloud secrets versions access latest --secret="expired-errors-fail_nginx-conf" > /tmp/default
sudo -E mv /tmp/default /etc/nginx/sites-available/default
sudo -E service nginx restart

gcloud secrets versions access latest --secret="expired-errors-fail_index-html" > /tmp/index.html
sudo -E mv /tmp/index.html /var/www/html/index.html
EOF

  # by default, terraform will first destroy an entity before re-creating it. This
  # does not work for instances templates, as they cannot be deleted while still in
  # use by a instance group. Therefore, each time first a new template with a random
  # ID is created, then assigned to the instance group, and finally the old template
  # deleted.
  lifecycle {
    create_before_destroy = true
  }
}

resource "random_id" "instance-template-id" {
  byte_length = 3
}

# google_compute_region_instance_group_manager is regional (multi-zone)
# google_compute_instance_group_manager is single-zone
resource "google_compute_region_instance_group_manager" "expired-group" {
  name               = "expired-group"
  base_instance_name = "expired"
  region             = "us-east1"

  version {
    instance_template = google_compute_instance_template.expired-template.id
  }

  # None of the load balancers in GCP support ICMP, therefore no automatic autoscaling can
  # be used, as we are distributing load via DNS round robin on {packetloss,expired}.errors.fail.
  # Scaling can be done via Terraform, as Terraform also manages the DNS zone errors.fail
  # and can add new hosts to the respective records.
  target_size        = "1"
}

# this returns the instance group object, where the instances are referenced but not "expanded",
# thus a second lookup is necessary to retrieve the instance properties
data "google_compute_region_instance_group" "expired-instance-group" {
  self_link = google_compute_region_instance_group_manager.expired-group.instance_group
}

# TODO how do you retrieve the IPs of *all* instances in the instance group?
data "google_compute_instance" "expired-instance" {
  self_link = data.google_compute_region_instance_group.expired-instance-group.instances.0.instance
}
