import http.client
import urllib.parse
import json
import csv
import time
import os

# --- Config ---
API_KEY     = "60a6ac7a3925418cbdaa7fdfec6d2b90"
ID_CSV_FILE = "va_pnode_ids.csv"
OUTPUT_FILE = "rt_hrl_lmps_2025_apr.csv"
START_TIME  = "2025-04-01 00:00"
END_TIME    = "2025-04-30 23:00"

POSSIBLE_ID_COLUMNS = ["pnode_id", "id", "node_id", "pnodeid", "PNODE_ID", "ID", "NODE_ID"]

MAX_RETRIES    = 3
DELAY_SECONDS  = 1.0
ROWS_PER_FETCH = 50000


# --- Load IDs ---
def load_pnode_ids(csv_file):
    with open(csv_file, newline="") as f:
        reader = csv.DictReader(f)
        headers = reader.fieldnames
        id_column = None
        for candidate in POSSIBLE_ID_COLUMNS:
            if candidate in headers:
                id_column = candidate
                break
        if not id_column:
            print("Could not detect ID column. Headers:", headers)
            exit()
        f.seek(0)
        reader = csv.DictReader(f)
        ids = [row[id_column].strip() for row in reader if row[id_column].strip()]
    return ids


# --- Fetch one page ---
def fetch_page(pnode_id_str, start_row):
    params = urllib.parse.urlencode({
        "rowCount": ROWS_PER_FETCH,
        "startRow": start_row,
        "datetime_beginning_ept": f"{START_TIME} to {END_TIME}",
        "pnode_id": pnode_id_str,
        "row_is_current": "TRUE",
        "sort": "datetime_beginning_ept",
        "order": "Asc",
    })

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            conn = http.client.HTTPSConnection("api.pjm.com", timeout=30)
            conn.request(
                "GET",
                f"/api/v1/rt_hrl_lmps?{params}",
                headers={"Ocp-Apim-Subscription-Key": API_KEY}
            )
            response = conn.getresponse()
            raw = response.read()
            conn.close()

            if response.status == 200:
                data = json.loads(raw)
                return data.get("items", []), int(data.get("totalRows", 0))
            elif response.status == 429:
                wait = 15 * attempt
                print(f"\n  Rate limited. Waiting {wait}s...")
                time.sleep(wait)
            elif response.status == 400:
                error = raw.decode("utf-8")
                # If pnode_id filter rejected, fall back to no filter
                if "Pnode_Id" in error:
                    print(f"\n  pnode_id filter rejected — data may be archived.")
                    print(f"  Try the monthly_filtered download script instead.")
                else:
                    print(f"\n  400 error: {error[:300]}")
                return [], 0
            else:
                print(f"\n  HTTP {response.status}: {raw.decode('utf-8')[:200]}")
                return [], 0

        except Exception as e:
            print(f"\n  Connection error (attempt {attempt}/{MAX_RETRIES}): {e}")
            time.sleep(5 * attempt)

    return [], 0


# --- Load IDs and batch into chunks to avoid 414 URI too large ---
pnode_ids = load_pnode_ids(ID_CSV_FILE)
BATCH_SIZE   = 50
batches      = [pnode_ids[i:i+BATCH_SIZE] for i in range(0, len(pnode_ids), BATCH_SIZE)]

print(f"Loaded {len(pnode_ids)} pnode IDs")
print(f"Batch size:        {BATCH_SIZE} IDs per request")
print(f"Number of batches: {len(batches)}")
print(f"Date range:        {START_TIME} to {END_TIME}")
print(f"Estimated rows:    {len(pnode_ids):,} nodes x 720 hrs = {len(pnode_ids)*720:,}")
print(f"Output:            {OUTPUT_FILE}")

confirm = input(f"\nProceed? (y/n): ")
if confirm.lower() != "y":
    print("Aborted.")
    exit()

# --- Download ---
headers_written    = False
total_rows_written = 0
total_fetches      = 0
start_time_run     = time.time()

print(f"\n{'='*60}")
print(f"Downloading April 2025...")
print(f"{'='*60}")

with open(OUTPUT_FILE, "w", newline="") as f:
    writer = None

    for batch_num, batch in enumerate(batches, 1):
        pnode_id_str = ";".join(batch)
        start_row    = 1
        page         = 1

        print(f"\n  Batch {batch_num:>3}/{len(batches)} "
              f"({len(batch)} IDs: {batch[0]}...{batch[-1]})")

        while True:
            print(f"    Page {page} (startRow={start_row})...", end=" ", flush=True)
            items, total_rows = fetch_page(pnode_id_str, start_row)
            total_fetches += 1

            if not items:
                print("No items.")
                break

            if not headers_written:
                writer = csv.DictWriter(f, fieldnames=items[0].keys())
                writer.writeheader()
                headers_written = True

            writer.writerows(items)
            f.flush()

            total_rows_written += len(items)
            elapsed = time.time() - start_time_run

            print(f"Wrote {len(items):,} | "
                  f"Batch total: {total_rows:,} | "
                  f"All written: {total_rows_written:,} | "
                  f"Elapsed: {elapsed:.0f}s")

            if start_row + ROWS_PER_FETCH - 1 >= total_rows or len(items) == 0:
                break

            start_row += ROWS_PER_FETCH
            page      += 1
            time.sleep(DELAY_SECONDS)

        time.sleep(DELAY_SECONDS)

elapsed_total = time.time() - start_time_run
file_size_mb  = os.path.getsize(OUTPUT_FILE) / (1024 * 1024)

print(f"\n{'='*60}")
print(f"DONE")
print(f"{'='*60}")
print(f"Total rows written: {total_rows_written:,}")
print(f"Total fetches:      {total_fetches}")
print(f"Time taken:         {elapsed_total/60:.1f} minutes")
print(f"File size:          {file_size_mb:.1f} MB")
print(f"Output:             {OUTPUT_FILE}")