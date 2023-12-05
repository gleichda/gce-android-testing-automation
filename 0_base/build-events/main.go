package buildevents

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"strings"

	cloudbuild "cloud.google.com/go/cloudbuild/apiv1/v2"
	"cloud.google.com/go/cloudbuild/apiv1/v2/cloudbuildpb"
	"cloud.google.com/go/storage"
	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
	"github.com/cloudevents/sdk-go/v2/event"
	"github.com/googleapis/google-cloudevents-go/cloud/storagedata"
	"google.golang.org/api/iterator"
	"google.golang.org/protobuf/encoding/protojson"
)

var logger *slog.Logger

func init() {
	functions.CloudEvent("buildEvent", buildEvent)
	replace := func(groups []string, a slog.Attr) slog.Attr {
		if a.Key == slog.LevelKey {
			a.Key = "severity"
		}
		return a
	}

	textHandler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelDebug, ReplaceAttr: replace})
	logger = slog.New(textHandler)
}

// MessagePublishedData contains the full Pub/Sub message
// See the documentation for more details:
// https://cloud.google.com/eventarc/docs/cloudevents#pubsub
type MessagePublishedData struct {
	Message PubSubMessage
}

// PubSubMessage is the payload of a Pub/Sub event.
// See the documentation for more details:
// https://cloud.google.com/pubsub/docs/reference/rest/v1/PubsubMessage
type PubSubMessage struct {
	Data []byte `json:"data"`
}

type destroyNotification struct {
	ImagePath string `json:"imagePath"`
}

const HostPackageName = "cvd-host_package.tar.gz"

// buildEvent consumes a CloudEvent message and extracts the Pub/Sub message.
func buildEvent(ctx context.Context, e event.Event) error {
	var msg MessagePublishedData
	if err := e.DataAs(&msg); err != nil {
		return fmt.Errorf("event.DataAs: %w\n", err)
	}

	logger.Debug("Data from Pubsub", "msg.Message.Data", string(msg.Message.Data))
	var bucketNotification storagedata.StorageObjectData

	if err := protojson.Unmarshal(msg.Message.Data, &bucketNotification); err == nil && bucketNotification.Bucket != "" {
		// fmt.Printf("BucketNotification: %+v\n", bucketNotification)
		logger.Debug("Pubsub message content", "bucketNotification", bucketNotification)
		// Ensure it is a source image (Uploaded to /images/)
		if strings.HasPrefix(bucketNotification.Name, "images/") {
			client, err := storage.NewClient(ctx)
			if err != nil {
				return fmt.Errorf("error creating storage client: %e\n", err)
			}
			var names []string
			filename := getFileNameFromPath(bucketNotification.Name)
			query := &storage.Query{Prefix: strings.TrimSuffix(bucketNotification.Name, filename)}
			logger.Debug("querying data from GCS", "query", query, "filename", filename, "bucketNotification.Name", bucketNotification.Name)
			it := client.Bucket(bucketNotification.Bucket).Objects(ctx, query)
			for {
				attrs, err := it.Next()
				if err == iterator.Done {
					break
				}
				if err != nil {
					return fmt.Errorf("error iterating over GCS objects: %e\n", err)
				}
				names = append(names, attrs.Name)
			}

			logger.Debug("Found following files in the bucket dir", "files", names)

			if len(names) != 2 {
				logger.Info(fmt.Sprintf("having %d file(s) in the build directory instead of the expected 2 files -> not executing a build\n", len(names)))
				return nil
			}

			var imagePath string
			for _, file := range names {
				if !strings.Contains(file, HostPackageName) {
					imagePath = fmt.Sprintf("gs://%s/%s", bucketNotification.Bucket, file)
				}
			}
			return createCloudBuild(ctx, "apply", imagePath)
		}
		logger.Warn("No action as path is not part of /images/ directory")
		return nil
	} else {
		logger.Warn("error unmarshaling BucketNotification", "error", err)
	}

	var destroyNotification destroyNotification
	if err := json.Unmarshal(msg.Message.Data, &destroyNotification); err == nil && destroyNotification.ImagePath != "" {
		logger.Debug("Pubsub message content", "destroyNotification", destroyNotification)
		return createCloudBuild(ctx, "destroy", destroyNotification.ImagePath)
	} else {
		logger.Warn("error unmarshaling destroyNotification", "error", err)
	}

	return errors.New("error: couln't parse the message as bucketNotofication or as destroyNotification")
}

func getBuildIdFromPath(path string) string {
	imageName := getFileNameFromPath(path)

	splitImageName := strings.Split(strings.TrimSuffix(imageName, ".zip"), "-")

	return splitImageName[len(splitImageName)-1]
}

func getFileNameFromPath(path string) string {
	splitPath := strings.Split(path, "/")
	return splitPath[len(splitPath)-1]
}

func createCloudBuild(ctx context.Context, action, imagePath string) error {
	logger.Info("Creating Cloudbuild now", "action", action, "Image Path", imagePath)
	c, err := cloudbuild.NewClient(ctx)
	if err != nil {
		return errors.New(fmt.Sprintf("error creating Cloud Build client: %w", err))
	}
	defer c.Close()
	req := &cloudbuildpb.CreateBuildRequest{
		ProjectId: os.Getenv("PROJECT_ID"),
		Build: &cloudbuildpb.Build{
			Steps: []*cloudbuildpb.BuildStep{
				&cloudbuildpb.BuildStep{
					Name: "gcr.io/google.com/cloudsdktool/cloud-sdk",
					Id:   "git clone",
					Args: []string{
						"gcloud",
						"source",
						"repos",
						"clone",
						"android-ci",
						"--project=${_PROJECT_ID}",
					},
				},
				&cloudbuildpb.BuildStep{
					Name: "hashicorp/terraform:1.6",
					Id:   "prepare terraform",
					Args: []string{
						"-c",
						"git checkout main && terraform init && terraform workspace select -or-create ${_BUILD_ID}",
					},
					Dir:        "${_TF_DIR}",
					Entrypoint: "sh",
				},
				&cloudbuildpb.BuildStep{
					Name: "hashicorp/terraform:1.6",
					Id:   "execute terraform",
					Args: []string{
						action,
						"-input=false",
						"-auto-approve",
						"-no-color",
						"-parallelism=120",
					},
					Dir: "${_TF_DIR}",
					Env: []string{
						fmt.Sprintf("TF_VAR_image_path=%s", imagePath),
						"TF_VAR_project_id=${_PROJECT_ID}",
					},
				},
			},
			Options: &cloudbuildpb.BuildOptions{
				Logging: cloudbuildpb.BuildOptions_CLOUD_LOGGING_ONLY,
			},
			Substitutions: map[string]string{
				"_BUILD_ID":   getBuildIdFromPath(imagePath),
				"_PROJECT_ID": os.Getenv("PROJECT_ID"),
				"_TF_DIR":     "android-ci/1_ci",
			},
			ServiceAccount: os.Getenv("BUILD_SERVICE_ACCOUNT"),
		},
	}

	op, err := c.CreateBuild(ctx, req)
	if err != nil {
		return errors.New(fmt.Sprintf("error creating Cloud Build: %w", err))
	}

	logger.Info("Cloud build created", "Build operation details", op)

	return nil
}
