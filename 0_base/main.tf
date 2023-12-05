resource "google_storage_bucket" "android_images" {
  name     = "${var.project_id}-android-images"
  project  = var.project_id
  location = var.region
}

resource "google_storage_bucket" "tf_state" {
  name     = "${var.project_id}-terraform-state"
  project  = var.project_id
  location = var.tfstate_bucket_location
}

resource "google_storage_notification" "notification" {
  bucket         = google_storage_bucket.android_images.name
  payload_format = "JSON_API_V1"
  topic          = google_pubsub_topic.build_events.id
  event_types    = ["OBJECT_FINALIZE"]
  depends_on     = [google_pubsub_topic_iam_binding.binding]
}

// Enable notifications by giving the correct IAM permission to the unique service account.
data "google_storage_project_service_account" "gcs_account" {
  project = var.project_id
}

// Create a Pub/Sub topic.
resource "google_pubsub_topic_iam_binding" "binding" {
  topic   = google_pubsub_topic.build_events.id
  role    = "roles/pubsub.publisher"
  members = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}

resource "google_project_service" "services" {
  for_each = var.services_to_enable
  project  = var.project_id
  service  = each.key
}

resource "google_sourcerepo_repository" "my-repo" {
  name    = "android-ci"
  project = var.project_id
}

resource "google_service_account" "iac" {
  account_id   = "iac-sa"
  display_name = "IAC"
  project      = var.project_id
}

resource "google_sourcerepo_repository_iam_member" "iac" {
  project    = google_sourcerepo_repository.my-repo.project
  repository = google_sourcerepo_repository.my-repo.name
  role       = "roles/source.reader"
  member     = "serviceAccount:${google_service_account.iac.email}"
}

resource "google_project_iam_member" "iac" {
  for_each = var.iac_roles
  project  = var.project_id
  member   = "serviceAccount:${google_service_account.iac.email}"
  role     = each.key
}

resource "google_pubsub_topic" "build_events" {
  name    = "build-events"
  project = var.project_id
}

module "event-function" {
  source      = "terraform-google-modules/event-function/google"
  version     = "~> 3.0"
  name        = "build-trigger"
  entry_point = "buildEvent"
  event_trigger = {
    event_type = "google.pubsub.topic.publish"
    resource   = google_pubsub_topic.build_events.id
  }
  environment_variables = {
    PROJECT_ID            = var.project_id
    BUILD_SERVICE_ACCOUNT = google_service_account.iac.id
  }
  project_id           = var.project_id
  region               = var.function_region
  source_directory     = "${path.module}/build-events"
  runtime              = "go121"
  bucket_force_destroy = true
  max_instances        = 10
  timeout_s            = 540
}
