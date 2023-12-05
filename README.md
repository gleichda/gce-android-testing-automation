# gce-android-testing-automation

This repository is made for Verifying Android images (the OS not APKs) against the test suite via [cts-tradefed](https://source.android.com/docs/compatibility/cts/run)

It uses a cloud function to react to files written to a GCS bucket.
From there it creates a Cloud Build that deploys the testing infrastructure via Terraform.
After the test it uploads the results to a GCS bucket and deletes the testing infrastrucutre.

## How to deploy

### Base infrastructure

First deploy `0_base` manually using terraform.

Afterwards feel free to use the created storage bucket with the name `<PROJECT-ID>-terraform-state` also for the [remote terraform state](https://developer.hashicorp.com/terraform/language/settings/backends/gcs) of the base deployment.

### Prepare the testing deployments

If you need you are able to modify the variables in `1_ci`.
For this purpose you can create a `terraform.tfvars` file.

Modify the terraform.tf and replace `<TF_STATE_BUCKET>` with the terraform state GCS bucket from `0_base`

After you have done your modifications push your code to the Cloud Source Repository created in the base deployment.

### Prepare all the files

Place the [CTS image](https://source.android.com/docs/compatibility/cts/downloads) in the created GCS Bucket under `/android-cts.zip`


## Results

The results will be dropped in the bucket under /results/<BUILD_ID>
