export NOW="$(date +%Y%m%d%H%M%S)"
export BUCKET="gs://ai-platform-trail"

export OUTPUT_DIR="${BUCKET}/output_data/${NOW}"
export PROJECT=healthy-earth-309119

cd preprocessor/

# run Dataflow jobs to prepare data for training
python -m run_preprocessing --cloud --output_dir "${OUTPUT_DIR}" --project_id "${PROJECT}"

export INPUT_DIR="${OUTPUT_DIR}"
export MODEL_DIR="${BUCKET}/model/$(date +%Y%m%d%H%M%S)"

# submit ML training job to AI platform
export JOB_NAME="train_$(date +%Y%m%d%H%M%S)"
gcloud ai-platform jobs submit training ${JOB_NAME} --job-dir ${MODEL_DIR} --config trainer/config.yaml --module-name trainer.task --package-path trainer/trainer --region us-central1 --python-version 3.5 --runtime-version 1.15 -- --input-dir ${INPUT_DIR}

export MODEL_NAME="survival_model"
export VERSION_NAME="demo_version"
export SAVED_MODEL_DIR=$(gsutil ls $MODEL_DIR/export/export | tail -1)

# upload trained model to AI platform
gcloud ai-platform models create $MODEL_NAME --regions us-central1

# this does NOT work, for some reason the model could not be found!
#gcloud ai-platform versions create $VERSION_NAME   --model $MODEL_NAME   --origin $SAVED_MODEL_DIR   --runtime-version=1.15   --framework TENSORFLOW   --python-version=3.7

export INPUT_PATHS=$INPUT_DIR/data/test/*
export OUTPUT_PATH=gs://ai-platform-trail/churn_prediction_output
export JOB_NAME="predict_$(date +%Y%m%d%H%M%S)"

# submit prediction job using trained model and save output to Storage Bucket
gcloud ai-platform jobs submit prediction $JOB_NAME     --model $MODEL_NAME     --input-paths $INPUT_PATHS     --output-path $OUTPUT_PATH     --region us-central1     --data-format TF_RECORD
