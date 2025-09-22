import os
from google.cloud import bigquery
from google.cloud import storage
import requests
from concurrent.futures import ThreadPoolExecutor, as_completed

# --- Configuration ---
PROJECT_ID = "sf311-triage-2025"
DATASET_ID = "sf311"
BUCKET_NAME = f"{PROJECT_ID}-sf311-data"
LOCATION = "US"
MAX_WORKERS = 10 # Number of parallel downloads

# Initialize clients
bq_client = bigquery.Client(project=PROJECT_ID)
storage_client = storage.Client(project=PROJECT_ID)

def get_image_urls_from_bigquery():
    """Fetches image URLs for the cohort that is already generated."""
    print("--> Fetching image URLs from your existing BigQuery cohort...")
    query = f"""
        SELECT
            c.service_request_id,
            c.media_url
        FROM
            `{PROJECT_ID}.{DATASET_ID}.cases_norm` AS c
        JOIN
            `{PROJECT_ID}.{DATASET_ID}.batch_ids` AS b
            ON c.service_request_id = b.service_request_id
        WHERE
            c.media_url IS NOT NULL AND TRIM(c.media_url) <> ""
            AND REGEXP_CONTAINS(LOWER(c.media_url), r"\.(jpg|jpeg|png|gif)(?:$|[?#])")
    """
    query_job = bq_client.query(query)
    results = query_job.result()
    print(f"--> Found {results.total_rows} images to download for your cohort.")
    return list(results)

def create_gcs_bucket_if_not_exists():
    """Creates the GCS bucket if it doesn't already exist."""
    try:
        bucket = storage_client.get_bucket(BUCKET_NAME)
        print(f"--> Bucket '{BUCKET_NAME}' already exists.")
    except Exception:
        print(f"--> Bucket '{BUCKET_NAME}' not found. Creating it now in {LOCATION}...")
        bucket = storage_client.create_bucket(BUCKET_NAME, location=LOCATION)
        print(f"--> Bucket '{BUCKET_NAME}' created successfully.")
    return bucket

def download_and_upload_image(row, bucket):
    """Downloads an image from a public URL and uploads it to GCS."""
    request_id = row.service_request_id
    url = row.media_url
    
    destination_blob_name = f"sf311_cohort/images/{request_id}.jpg"
    
    try:
        response = requests.get(url, timeout=15)
        response.raise_for_status()
        image_data = response.content
        
        blob = bucket.blob(destination_blob_name)
        blob.upload_from_string(image_data, content_type=response.headers.get('content-type'))
        
        return f"SUCCESS: {request_id}"
    except requests.exceptions.RequestException:
        return f"FAILED Download: {request_id}"
    except Exception as e:
        return f"FAILED Upload: {request_id}"

def main():
    """Main function to orchestrate the download and upload process."""
    bucket = create_gcs_bucket_if_not_exists()
    image_rows = get_image_urls_from_bigquery()
    
    if not image_rows:
        print("--> No images to process. Exiting.")
        return

    print(f"\n--> Starting parallel download/upload with {MAX_WORKERS} workers...")
    
    success_count = 0
    failure_count = 0
    
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = [executor.submit(download_and_upload_image, row, bucket) for row in image_rows]
        
        for i, future in enumerate(as_completed(futures)):
            result = future.result()
            if "SUCCESS" in result:
                success_count += 1
            else:
                failure_count += 1
            
            print(f"    ({i+1}/{len(image_rows)}) {result}")
    
    print("\n--- Process Complete ---")
    print(f"✅ Successful uploads: {success_count}")
    print(f"❌ Failed uploads: {failure_count}")
    print("------------------------")

if __name__ == "__main__":
    main()
