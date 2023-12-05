module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 7.4"

  project_id   = var.project_id
  network_name = "android-ci-${local.build_id}"
  routing_mode = "GLOBAL"

  subnets = [
    {
      subnet_name   = "android-ci-${local.build_id}"
      subnet_ip     = "10.0.0.0/16"
      subnet_region = var.region
    },
  ]
  firewall_rules = [
    {
      name        = "aos-cts-ingress-${local.build_id}"
      direction   = "INGRESS"
      source_tags = ["cts-${local.build_id}"]
      target_tags = ["aos-${local.build_id}"]

      allow = [
        {
          protocol = "tcp"
          ports    = []
        }
      ]
    }
  ]
}

module "cloud-nat" {
  source        = "terraform-google-modules/cloud-nat/google"
  version       = "~> 4.1"
  create_router = true
  project_id    = var.project_id
  network       = module.vpc.network_id
  region        = var.region
  router        = "nat-router-${local.build_id}"
  name          = "nat--${local.build_id}"
}
