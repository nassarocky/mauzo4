# Copy Firebase / GCS bucket → another account (no overwrite)

Copies every object from a **source** bucket to a **destination** bucket, keeping the same object paths (folders). If an object **already exists** in the destination, it is **not** touched.

## 1. Service accounts

**Source Firebase / GCP project**

1. IAM & Admin → Service accounts → Create (or pick one).
2. Grant **Storage Object Viewer** on the **source bucket** (Bucket → Permissions → Grant access: principal = that SA, role = `Storage Object Viewer`).
3. Keys → Add key → JSON → save as e.g. `source-sa.json`.

**Destination Firebase / GCP project**

1. Create another service account.
2. On the **destination bucket**, grant:
   - **Storage Object Viewer** (to check if an object exists and read metadata), and  
   - **Storage Object Creator** (to upload new objects).  
   Or a single role like **Storage Object Admin** on that bucket only (still safe: this script never deletes and never overwrites existing keys).

3. Save JSON as e.g. `dest-sa.json`.

Do **not** commit these JSON files to git.

### This repo: Shopping Manager → Hesabu Mauzo

| | Bucket | Folder (prefix) |
|---|--------|-----------------|
| **Source** (Shopping Manager) | `shopping-manager-a938a.appspot.com` | `gmanproducts/` |
| **Destination** (Hesabu Mauzo) | `hesabumauzo.firebasestorage.app` | same paths under `gmanproducts/` |

Use the **Shopping Manager** service account JSON for `--source-key` and the **Hesabu Mauzo** JSON for `--dest-key`. Existing files already in `hesabumauzo` under `gmanproducts/` are **not** overwritten.

```bash
python copy_buckets_no_clobber.py ^
  --source-bucket shopping-manager-a938a.appspot.com ^
  --dest-bucket hesabumauzo.firebasestorage.app ^
  --source-key path\to\shopping-manager-sa.json ^
  --dest-key path\to\hesabumauzo-sa.json ^
  --prefix gmanproducts/
```

Run once with `--dry-run` to list what would copy vs skip.

**PowerShell helper** (same buckets + prefix):

```powershell
cd tools\storage_migrate
.\run_shopping_to_hesabu.ps1 -SourceKey "C:\path\shopping-manager-sa.json" -DestKey "C:\path\hesabumauzo-sa.json" -DryRun
# then without -DryRun to copy
```

You can also set `SOURCE_SA_JSON` and `DEST_SA_JSON` and omit `--source-key` / `--dest-key` on the Python command.

## 2. Install & run

```bash
cd tools/storage_migrate
python -m venv .venv
# Windows:
.venv\Scripts\activate
# macOS/Linux:
# source .venv/bin/activate

pip install -r requirements.txt
```

Dry run (no uploads):

```bash
python copy_buckets_no_clobber.py ^
  --source-bucket YOUR_OLD_BUCKET ^
  --dest-bucket YOUR_NEW_BUCKET ^
  --source-key path\to\source-sa.json ^
  --dest-key path\to\dest-sa.json ^
  --dry-run
```

Real copy:

```bash
python copy_buckets_no_clobber.py ^
  --source-bucket YOUR_OLD_BUCKET ^
  --dest-bucket YOUR_NEW_BUCKET ^
  --source-key path\to\source-sa.json ^
  --dest-key path\to\dest-sa.json
```

Optional: only under a prefix (e.g. `images/`):

```bash
python copy_buckets_no_clobber.py ... --prefix images/
```

Bucket names look like `project-id.appspot.com` or `project-id.firebasestorage.app` (see Firebase console → Storage).

## 3. After copying

- Point your app to the **new** Firebase project / `storageBucket` in `firebase_options.dart`.
- Update **Firestore** (or other DB) fields that store **old** download URLs; new uploads will use the new bucket.

## 4. Alternative: `gsutil` (one principal with access to both buckets)

If one Google identity can read the source bucket and write the destination bucket:

```bash
gcloud auth login
# or: gcloud auth activate-service-account --key-file=combined.json

gsutil -m cp -n -r gs://SOURCE_BUCKET/** gs://DEST_BUCKET/
```

`-n` means **no-clobber** (skip if destination object already exists). You still need matching IAM on both buckets for that account.
