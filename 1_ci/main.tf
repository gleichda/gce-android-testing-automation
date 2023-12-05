locals {
  zone              = "${var.region}-${var.zone_suffix}"
  image_name        = reverse(split("/", var.image_path))[0]
  host_package_path = "${trimsuffix(var.image_path, local.image_name)}cvd-host_package.tar.gz"
  bucket_name       = split("/", var.image_path)[2]
  build_id          = reverse(split("-", split(".", local.image_name)[0]))[0]
}
