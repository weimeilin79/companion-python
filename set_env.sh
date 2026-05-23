#!/bin/bash

# This script sets various Google Cloud related environment variables.
# It must be SOURCED to make the variables available in your current shell.
# Example: source ./set_gcp_env.sh

# --- Configuration ---
PROJECT_FILE="~/project_id.txt"
API_KEY_FILE="~/api_key.txt"
GOOGLE_CLOUD_LOCATION="us-central1"
# ---------------------


echo "--- Setting Google Cloud Environment Variables ---"

# --- Authentication Check ---
echo "Checking gcloud authentication status..."
# Run a command that requires authentication (like listing accounts or printing a token)
# Redirect stdout and stderr to /dev/null so we don't see output unless there's a real error
if gcloud auth print-access-token > /dev/null 2>&1; then
  echo "gcloud is authenticated."
else
  echo "Error: gcloud is not authenticated."
  echo "Please log in by running: gcloud auth login"
  # Use 'return 1' instead of 'exit 1' because the script is meant to be sourced.
  # 'exit 1' would close your current terminal session.
  return 1
fi
# --- --- --- --- --- ---


# 1. Check if project file exists
PROJECT_FILE_PATH=$(eval echo $PROJECT_FILE) # Expand potential ~
if [ ! -f "$PROJECT_FILE_PATH" ]; then
  echo "Error: Project file not found at $PROJECT_FILE_PATH"
  echo "Please create $PROJECT_FILE_PATH containing your Google Cloud project ID."
  return 1 # Return 1 as we are sourcing
fi



# 2. Set the default gcloud project configuration
PROJECT_ID_FROM_FILE=$(cat "$PROJECT_FILE_PATH")
echo "Setting gcloud config project to: $PROJECT_ID_FROM_FILE"
# Adding --quiet; set -e will handle failure if the project doesn't exist or access is denied
gcloud config set project "$PROJECT_ID_FROM_FILE" --quiet


# 3. Export PROJECT_ID (Get from config to confirm it was set correctly)
export PROJECT_ID=$(gcloud config get project)
echo "Exported PROJECT_ID=$PROJECT_ID"

# 4. Export PROJECT_NUMBER
# Using --format to extract just the projectNumber value
export PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
echo "Exported PROJECT_NUMBER=$PROJECT_NUMBER"

# 6. Export GOOGLE_CLOUD_PROJECT (Often used by client libraries)
# This is usually the same as PROJECT_ID
export GOOGLE_CLOUD_PROJECT="$PROJECT_ID"
echo "Exported GOOGLE_CLOUD_PROJECT=$GOOGLE_CLOUD_PROJECT"

# 9. Export GOOGLE_GENAI_USE_VERTEXAI
export GOOGLE_GENAI_USE_VERTEXAI="FALSE"
echo "Exported GOOGLE_GENAI_USE_VERTEXAI=$GOOGLE_GENAI_USE_VERTEXAI"

# 10. Export GOOGLE_CLOUD_LOCATION
export GOOGLE_CLOUD_LOCATION="$GOOGLE_CLOUD_LOCATION"
echo "Exported GOOGLE_CLOUD_LOCATION=$GOOGLE_CLOUD_LOCATION"

# 12. Export REGION
export REGION="$GOOGLE_CLOUD_LOCATION"
echo "Exported REGION=$GOOGLE_CLOUD_LOCATION"

# 13. Export GEMINI_API_KEY from ~/gemini_key.txt
GEMINI_KEY_FILE="~/gemini_key.txt"
GEMINI_KEY_FILE_PATH=$(eval echo $GEMINI_KEY_FILE)
if [ -f "$GEMINI_KEY_FILE_PATH" ]; then
  export GEMINI_API_KEY=$(cat "$GEMINI_KEY_FILE_PATH" | tr -d '\r\n[:space:]')
  echo "Exported GEMINI_API_KEY from $GEMINI_KEY_FILE"
else
  echo "Warning: $GEMINI_KEY_FILE not found. GEMINI_API_KEY was not set."
fi

source ~/.bashrc


echo ""
echo "--- Environment setup complete ---"