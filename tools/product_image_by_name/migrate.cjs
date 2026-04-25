#!/usr/bin/env node
/**
 * Set Firestore product `image` on Hesabu Mauzo by matching `name` to Shopping Manager data.
 * Shopping Manager rows (name + old image URL) give the Storage object path; files must
 * already exist in the Hesabu bucket at the same path (e.g. gmanproducts/...).
 *
 * Modes:
 *   1) --from-json export.json   array of { "name": "...", "image": "https://firebasestorage..." }
 *   2) --shopping-credentials path/to/shopping-sa.json --shopping-business-id BID
 *      reads products/{BID}/userProducts from Shopping Manager project (second Firebase app)
 *
 * Hesabu: uses GOOGLE_APPLICATION_CREDENTIALS or --hesabu-credentials for Firestore + Storage.
 *
 * Example:
 *   set GOOGLE_APPLICATION_CREDENTIALS=C:\keys\hesabu-sa.json
 *   node migrate.cjs --hesabu-business-id YOUR_HESABU_BID --from-json shopping_products.json --dry-run
 */

const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

const DEFAULT_BUCKET = "hesabumauzo.firebasestorage.app";

/** Load and validate a Google Cloud service account key JSON (not firebase.json). */
function loadServiceAccountKey(filePath, label) {
  const abs = path.resolve(filePath);
  if (!fs.existsSync(abs)) {
    console.error(`${label}: file not found:\n  ${abs}`);
    process.exit(1);
  }
  let data;
  try {
    data = JSON.parse(fs.readFileSync(abs, "utf8"));
  } catch (e) {
    console.error(`${label}: invalid JSON (${e.message})\n  ${abs}`);
    process.exit(1);
  }
  if (data.type !== "service_account" || !data.private_key || !data.client_email) {
    console.error(`${label}: this is not a service account key JSON.`);
    console.error(`  File: ${abs}`);
    console.error(
      `  Expected a key file with "type":"service_account", "private_key", and "client_email".`
    );
    console.error(
      `  firebase.json / google-services.json are NOT valid — use "Generate new private key" in Google Cloud.`
    );
    console.error(`  Cloud Console: IAM & Admin → Service Accounts → your SA → Keys → Add key → JSON`);
    process.exit(1);
  }
  return data;
}

function parseArgs() {
  const out = {
    hesabuBusinessId: null,
    hesabuCredentials: process.env.GOOGLE_APPLICATION_CREDENTIALS || null,
    bucket: process.env.STORAGE_BUCKET || DEFAULT_BUCKET,
    fromJson: null,
    shoppingCredentials: null,
    shoppingBusinessId: null,
    shoppingProjectId: null,
    dryRun: false,
  };
  for (let i = 2; i < process.argv.length; i++) {
    const a = process.argv[i];
    if (a === "--dry-run") out.dryRun = true;
    else if (a.startsWith("--hesabu-business-id="))
      out.hesabuBusinessId = a.split("=")[1];
    else if (a.startsWith("--hesabu-credentials="))
      out.hesabuCredentials = a.split("=")[1];
    else if (a.startsWith("--bucket=")) out.bucket = a.split("=")[1];
    else if (a.startsWith("--from-json=")) out.fromJson = a.split("=")[1];
    else if (a.startsWith("--shopping-credentials="))
      out.shoppingCredentials = a.split("=")[1];
    else if (a.startsWith("--shopping-business-id="))
      out.shoppingBusinessId = a.split("=")[1];
    else if (a.startsWith("--source-business-id="))
      out.shoppingBusinessId = a.split("=")[1];
    else if (a.startsWith("--dest-business-id="))
      out.hesabuBusinessId = a.split("=")[1];
    else if (a.startsWith("--shopping-project-id="))
      out.shoppingProjectId = a.split("=")[1];
    else if (a === "--help" || a === "-h") out.help = true;
  }
  return out;
}

function normalizeName(s) {
  if (s == null || typeof s !== "string") return "";
  return s
    .trim()
    .replace(/\s+/g, " ")
    .normalize("NFKC")
    .toLowerCase();
}

/** Extract gs-style object path from Firebase download URL */
function pathFromFirebaseDownloadUrl(url) {
  if (!url || typeof url !== "string") return null;
  const m = url.match(/\/o\/([^?]+)/);
  if (!m) return null;
  try {
    return decodeURIComponent(m[1]);
  } catch {
    return null;
  }
}

function loadNameToPathFromJson(filePath) {
  const abs = path.resolve(filePath);
  const raw = JSON.parse(fs.readFileSync(abs, "utf8"));
  const rows = Array.isArray(raw) ? raw : raw.products || raw.items || [];
  const map = new Map();
  let dup = 0;
  for (const row of rows) {
    const n = normalizeName(row.name);
    if (!n) continue;
    const p = pathFromFirebaseDownloadUrl(row.image);
    if (!p) continue;
    if (map.has(n)) {
      dup++;
      map.set(n, p); // last wins
    } else {
      map.set(n, p);
    }
  }
  return { map, dup, count: rows.length };
}

async function loadNameToPathFromFirestore(shoppingDb, shoppingBusinessId) {
  const snap = await shoppingDb
    .collection("products")
    .doc(shoppingBusinessId)
    .collection("userProducts")
    .get();
  const map = new Map();
  let dup = 0;
  for (const doc of snap.docs) {
    const d = doc.data();
    const n = normalizeName(d.name);
    if (!n) continue;
    const p = pathFromFirebaseDownloadUrl(d.image);
    if (!p) continue;
    if (map.has(n)) dup++;
    map.set(n, p);
  }
  return { map, dup, count: snap.size };
}

async function main() {
  const args = parseArgs();
  if (args.help || !args.hesabuBusinessId) {
    console.log(`
Usage:
  node migrate.cjs --dest-business-id=HESABU_BID [options]
  (alias: --hesabu-business-id= same as --dest-business-id)

Options:
  --dest-business-id=BID        Hesabu Mauzo Firestore business doc id (products/{id}/...)
  --hesabu-business-id=BID    Same as --dest-business-id
  --from-json=PATH              JSON array of { name, image } from Shopping Manager
  --shopping-credentials=PATH   SA JSON for Shopping Manager (Firestore read)
  --source-business-id=BID      Shopping Manager business id (alias: --shopping-business-id)
  --shopping-project-id=PID     Optional; else taken from SA project_id
  --hesabu-credentials=PATH     Hesabu SA JSON (else GOOGLE_APPLICATION_CREDENTIALS)
  --bucket=NAME                 Default: ${DEFAULT_BUCKET}
  --dry-run

One of --from-json or (--shopping-credentials + --source-business-id) is required.
`);
    process.exit(args.hesabuBusinessId ? 0 : 1);
  }

  if (!args.fromJson && !(args.shoppingCredentials && args.shoppingBusinessId)) {
    console.error(
      "Provide --from-json=... OR --shopping-credentials + --source-business-id (or --shopping-business-id)"
    );
    process.exit(1);
  }

  const hesabuKey =
    args.hesabuCredentials || process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!hesabuKey || !String(hesabuKey).trim()) {
    console.error(
      "Hesabu credentials missing. Use ONE of:\n" +
        "  PowerShell:  $env:GOOGLE_APPLICATION_CREDENTIALS=\"C:\\path\\hesabu-SA-KEY.json\"\n" +
        "  Or add:      --hesabu-credentials=C:\\path\\hesabu-SA-KEY.json\n\n" +
        "The file must be a Service Account KEY (contains private_key), NOT firebase.json.\n" +
        "Create it: Firebase Console → Project settings → Service accounts → Generate new private key,\n" +
        "or Google Cloud → IAM → Service Accounts → Keys → Add key → JSON."
    );
    process.exit(1);
  }

  const hesabuJson = loadServiceAccountKey(hesabuKey, "Hesabu (destination)");
  const hesabuCred = admin.credential.cert(hesabuJson);

  admin.initializeApp({
    credential: hesabuCred,
    storageBucket: args.bucket,
  });

  const db = admin.firestore();
  const bucket = admin.storage().bucket(args.bucket);

  let nameToPath, dupNames, sourceCount;
  if (args.fromJson) {
    const r = loadNameToPathFromJson(args.fromJson);
    nameToPath = r.map;
    dupNames = r.dup;
    sourceCount = r.count;
    console.log(
      `Loaded ${nameToPath.size} name→path mappings from JSON (${sourceCount} rows, ${dupNames} duplicate names in source)`
    );
  } else {
    const shopJson = loadServiceAccountKey(
      args.shoppingCredentials,
      "Shopping Manager (source Firestore)"
    );
    const shopCred = admin.credential.cert(shopJson);
    const shopProject =
      args.shoppingProjectId || shopJson.project_id;
    const shoppingApp = admin.initializeApp(
      { credential: shopCred, projectId: shopProject },
      "shopping"
    );
    const shoppingDb = shoppingApp.firestore();
    const r = await loadNameToPathFromFirestore(
      shoppingDb,
      args.shoppingBusinessId
    );
    nameToPath = r.map;
    dupNames = r.dup;
    sourceCount = r.count;
    console.log(
      `Loaded ${nameToPath.size} name→path from Shopping Firestore (${sourceCount} docs, ${dupNames} duplicate names)`
    );
  }

  const productsRef = db
    .collection("products")
    .doc(args.hesabuBusinessId)
    .collection("userProducts");
  const snap = await productsRef.get();

  let updated = 0;
  let skippedNoMapping = 0;
  let skippedNoFile = 0;
  let skippedDry = 0;
  let batch = db.batch();
  let batchOps = 0;

  async function commitBatch() {
    if (batchOps === 0) return;
    if (!args.dryRun) await batch.commit();
    batch = db.batch();
    batchOps = 0;
  }

  for (const doc of snap.docs) {
    const data = doc.data();
    const n = normalizeName(data.name);
    if (!n) continue;

    const objectPath = nameToPath.get(n);
    if (!objectPath) {
      skippedNoMapping++;
      continue;
    }

    const file = bucket.file(objectPath);
    const [exists] = await file.exists();
    if (!exists) {
      console.warn(`Missing file in Hesabu bucket: ${objectPath} (product "${data.name}")`);
      skippedNoFile++;
      continue;
    }

    if (args.dryRun) {
      console.log(`[dry-run] would set image for "${data.name}" (${doc.id}) ← ${objectPath}`);
      skippedDry++;
      continue;
    }

    const [url] = await file.getSignedUrl({
      action: "read",
      expires: new Date("2100-01-01"),
    });

    batch.update(doc.ref, { image: url });
    batchOps++;
    updated++;
    console.log(`update "${data.name}" (${doc.id})`);

    if (batchOps >= 400) await commitBatch();
  }

  await commitBatch();

  console.log(`
Done.
  updated: ${args.dryRun ? 0 : updated}
  dry-run rows: ${skippedDry}
  no name match in source: ${skippedNoMapping}
  file missing in bucket: ${skippedNoFile}
  hesabu products scanned: ${snap.size}
`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
