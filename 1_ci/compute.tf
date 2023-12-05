resource "google_compute_instance" "cts" {
  name         = "cts-${local.build_id}"
  machine_type = var.cts_machine_type
  zone         = local.zone
  project      = var.project_id

  tags = ["cts-${local.build_id}"]

  boot_disk {
    initialize_params {
      image = var.cts_image
      size  = 200
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = module.vpc.network_id
    subnetwork = module.vpc.subnets["${var.region}/android-ci-${local.build_id}"].id
  }

  metadata_startup_script = templatefile("./scripts/startup_cts.sh.tpl", {
    port        = var.aos_port,
    ip_addrs    = google_compute_instance.aos.*.network_interface.0.network_ip,
    shard_count = var.parallel_execution_count,
    build_id    = local.build_id,
    image_path  = var.image_path,
    bucket_name = local.bucket_name
  })

  service_account {
    email  = google_service_account.cts.email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_instance" "aos" {
  count        = var.parallel_execution_count
  name         = "aos-${local.build_id}-${count.index}"
  machine_type = var.aos_machine_type
  zone         = local.zone
  project      = var.project_id

  tags = ["aos-${local.build_id}"]

  boot_disk {
    initialize_params {
      image = var.aos_image
      size  = 200
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = module.vpc.network_id
    subnetwork = module.vpc.subnets["${var.region}/android-ci-${local.build_id}"].id
  }

  metadata_startup_script = templatefile("./scripts/startup_aos.sh.tpl", {
    image_path        = var.image_path,
    host_package_path = local.host_package_path
  })

  service_account {
    email  = google_service_account.aos.email
    scopes = ["cloud-platform"]
  }

  lifecycle {
    ignore_changes = [metadata]
  }
}


