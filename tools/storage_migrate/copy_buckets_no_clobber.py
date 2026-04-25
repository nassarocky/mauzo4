#!/usr/bin/env python3
"""
Copy all objects from a source GCS/Firebase Storage bucket to a destination bucket,
preserving object names (folder paths). Never overwrites: if an object already exists
in the destination, it is skipped.

Uses two service account JSON keys (e.g. one per Firebase/Google account).

Example:
  python copy_buckets_no_clobber.py \\
    --source-bucket my-old.appspot.com \\
    --dest-bucket my-new.firebasestorage.app \\
    --source-key ./source-sa.json \\
    --dest-key ./dest-sa.json

IAM (minimum):
  Source key: roles/storage.objectViewer on the SOURCE bucket (or project).
  Dest key:   roles/storage.objectCreator on the DEST bucket (or project).
  Dest key also needs object.get to check existence: roles/storage.objectViewer
  on the destination bucket, or use storage.objectAdmin (broader).
"""

from __future__ import annotations

import argparse
import os
import sys
import tempfile


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--source-bucket", required=True, help="Source bucket name (no gs://)")
    p.add_argument("--dest-bucket", required=True, help="Destination bucket name (no gs://)")
    p.add_argument(
        "--source-key",
        default=os.environ.get("SOURCE_SA_JSON", ""),
        help="Path to SA JSON (read source). Or set env SOURCE_SA_JSON.",
    )
    p.add_argument(
        "--dest-key",
        default=os.environ.get("DEST_SA_JSON", ""),
        help="Path to SA JSON (write dest). Or set env DEST_SA_JSON.",
    )
    p.add_argument(
        "--prefix",
        default="",
        help="Only copy objects whose names start with this prefix (e.g. images/)",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="List what would be copied or skipped; no writes",
    )
    return p.parse_args()


def main() -> int:
    args = parse_args()
    if not (args.source_key or "").strip():
        print(
            "Error: --source-key missing and SOURCE_SA_JSON not set.",
            file=sys.stderr,
        )
        return 1
    if not (args.dest_key or "").strip():
        print(
            "Error: --dest-key missing and DEST_SA_JSON not set.",
            file=sys.stderr,
        )
        return 1
    for label, path in ("Source", args.source_key), ("Dest", args.dest_key):
        if not os.path.isfile(path):
            print(f"Error: {label} key file not found: {path}", file=sys.stderr)
            return 1

    try:
        from google.cloud import storage
        from google.oauth2 import service_account
    except ImportError:
        print(
            "Missing dependency. Run: pip install -r requirements.txt",
            file=sys.stderr,
        )
        return 1

    source_creds = service_account.Credentials.from_service_account_file(
        args.source_key
    )
    dest_creds = service_account.Credentials.from_service_account_file(args.dest_key)

    source_client = storage.Client(
        credentials=source_creds,
        project=source_creds.project_id,
    )
    dest_client = storage.Client(
        credentials=dest_creds,
        project=dest_creds.project_id,
    )

    src_bucket = source_client.bucket(args.source_bucket)
    dst_bucket = dest_client.bucket(args.dest_bucket)

    copied = 0
    skipped = 0
    errors = 0

    blobs = source_client.list_blobs(
        args.source_bucket, prefix=args.prefix or None
    )

    for blob in blobs:
        name = blob.name
        if name.endswith("/"):
            continue

        dst_blob = dst_bucket.blob(name)
        try:
            exists = dst_blob.exists()
        except Exception as e:
            print(f"[error] exists check {name!r}: {e}", file=sys.stderr)
            errors += 1
            continue

        if exists:
            print(f"skip (exists): {name}")
            skipped += 1
            continue

        if args.dry_run:
            print(f"would copy: {name}")
            copied += 1
            continue

        tmp_fd, tmp_path = tempfile.mkstemp(prefix="gcs-migrate-", suffix=".bin")
        os.close(tmp_fd)
        try:
            blob.download_to_filename(tmp_path)
            dst_blob.upload_from_filename(
                tmp_path,
                content_type=blob.content_type or "application/octet-stream",
            )
            print(f"copied: {name}")
            copied += 1
        except Exception as e:
            print(f"[error] {name!r}: {e}", file=sys.stderr)
            errors += 1
        finally:
            try:
                os.remove(tmp_path)
            except OSError:
                pass

    print(
        f"\nDone. copied={copied} skipped_existing={skipped} errors={errors} dry_run={args.dry_run}"
    )
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
