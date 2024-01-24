

provider "google" {
  project = var.project
  region  = var.region
  zone = var.region_zone
}

resource "google_compute_instance" "bootc_test" {
  name         = "bootc-test"
  machine_type = "e2-standard-4"
  tags = ["bootc-test"]
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "rhel-cloud/rhel-9"
    }
  }

  # LOOK HERE
  # This is really the main interesting thing going on; we're injecting a "startup script"
  # via GCE instance metadata into the stock RHEL-9 guest image.  This script fetches our
  # target container image, and reboots into it.
  metadata_startup_script = <<-EOS
dnf -y install podman skopeo && 
podman run --rm --privileged -v /:/target --pid=host --security-opt label=type:unconfined_t ${var.bootc_image} bootc install to-filesystem --replace=alongside /target &&
reboot
EOS

  network_interface {
    # A default network is created for all GCP projects
    network = "default"
    access_config {
    }
  }
}
