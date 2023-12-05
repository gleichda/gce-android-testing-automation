resource "google_service_account" "cts" {
  account_id   = "cts-${local.build_id}"
  display_name = "CTS"
  project      = var.project_id
}

resource "google_service_account" "aos" {
  account_id   = "aos--${local.build_id}"
  display_name = "AOS"
  project      = var.project_id
}

resource "google_storage_bucket_iam_member" "aos_viewer" {
  bucket = "${var.project_id}-android-images"
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.aos.email}"
}

resource "google_storage_bucket_iam_member" "cts_reader" {
  bucket = "${var.project_id}-android-images"
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.cts.email}"
}

resource "google_storage_bucket_iam_member" "cts_writer" {
  bucket = "${var.project_id}-android-images"
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.cts.email}"
}

resource "google_project_iam_member" "cts_logwriter" {
  member  = "serviceAccount:${google_service_account.cts.email}"
  role    = "roles/logging.logWriter"
  project = var.project_id
}

resource "google_project_iam_member" "aos_logwriter" {
  member  = "serviceAccount:${google_service_account.aos.email}"
  role    = "roles/logging.logWriter"
  project = var.project_id
}

resource "google_project_iam_member" "aos_metricwriter" {
  member  = "serviceAccount:${google_service_account.aos.email}"
  role    = "roles/monitoring.metricWriter"
  project = var.project_id
}

resource "google_project_iam_member" "cts_metricwriter" {
  member  = "serviceAccount:${google_service_account.cts.email}"
  role    = "roles/monitoring.metricWriter"
  project = var.project_id
}

resource "google_pubsub_topic_iam_member" "member" {
  project = var.project_id
  topic   = "build-events"
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.cts.email}"
}
