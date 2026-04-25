# Match product images by name (Shopping Manager → Hesabu Mauzo)

Use this when **product document IDs differ** between systems but **product names** are the same, and image files were already copied to the Hesabu Storage bucket **with the same object paths** as in the old URLs (e.g. `gmanproducts/1730....png`).

Firestore field updated: `image` on `products/{hesabuBusinessId}/userProducts/{id}`.

## Important: which JSON files?

Use **Service account private key** downloads (the file contains `"type": "service_account"` and `"private_key"`).

**Not** `firebase.json`, **not** `google-services.json` — those cannot authenticate this script.

Download keys: **Google Cloud Console** → your project → **IAM & Admin** → **Service accounts** → choose an account → **Keys** → **Add key** → **JSON**.  
Do this once for **Hesabu Mauzo** and once for **Shopping Manager** (if using live Firestore).

## What you need

1. **Hesabu** service account JSON with:
   - Firestore read/write on `products/{hesabuBusinessId}/userProducts`
   - Storage read on `hesabumauzo.firebasestorage.app` (to sign URLs)
2. **Either:**
   - **JSON file** from Shopping Manager with `name` + `image` (old download URL), **or**
   - **Shopping Manager** service account JSON + Shopping **business id** (script reads Firestore directly).

## Duplicate names

If two products share the same normalized name in the source, the **last** one wins for that name. Fix duplicates in source or rename before running.

Normalization: trim, collapse spaces, **case-insensitive**, Unicode NFKC.

## Install

```bash
cd tools/product_image_by_name
npm install
```

## Option A — JSON export from Shopping Manager

Build a file `shopping_products.json`:

```json
[
  { "name": "Sugar 1kg", "image": "https://firebasestorage.googleapis.com/v0/b/shopping-manager-a938a.appspot.com/o/gmanproducts%2F123.png?alt=media&token=..." },
  { "name": "Salt", "image": "https://..." }
]
```

Export from Firestore console, or a one-off query, or Excel → save as JSON.

Run (Windows PowerShell):

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\hesabu-sa.json"
node migrate.cjs --dest-business-id=YOUR_HESABU_BUSINESS_DOC_ID --from-json=C:\path\shopping_products.json --dry-run
```

(`--hesabu-business-id=` is the same as `--dest-business-id=`.)

Remove `--dry-run` to apply.

## Option B — Read Shopping Manager Firestore live

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\hesabu-sa.json"
node migrate.cjs `
  --dest-business-id=YOUR_HESABU_BID `
  --shopping-credentials=C:\path\shopping-sa.json `
  --source-business-id=SHOPPING_BUSINESS_DOC_ID `
  --dry-run
```

(`--shopping-business-id=` is the same as `--source-business-id=`.)

Find both IDs in the app under **Account Status → Account info → Business ID** (Hesabu), and the same screen on Shopping Manager for the source id.

`shopping-sa.json` must be able to read `products/{shoppingBusinessId}/userProducts`.

## Optional flags

- `--hesabu-credentials=C:\path\hesabu.json` if you don’t use `GOOGLE_APPLICATION_CREDENTIALS`
- `--bucket=hesabumauzo.firebasestorage.app` (default)

## URLs

The script stores a **long-lived signed URL** so the app can load images without the old Firebase token. Your Storage **rules** must still allow the intended access pattern for the app (same as normal product images).
