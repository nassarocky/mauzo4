const { HttpsError } = require("firebase-functions/v2/https");
const smsHelpers = require("./sms_helpers");

const MAX_REMINDERS_PER_CALL = 50;

const SMS_CORS = [
  "https://hesabumauzo.co.tz",
  "https://biashara.hesabumauzo.co.tz",
  "http://localhost:5000",
  "http://localhost:8080",
  "http://localhost:5173",
];

const AZAMPAY_TOKEN_BODY = {
  appName: "Hesabu Mauzo",
  clientId: "01963395-6a54-7444-b323-5ee39cdc4326",
  clientSecret:
    "U2dqWWORy9Aze/MN57++tkkziznBSJkXgqBUg1v3p8EEZT4ruEjRC3Y2B8Wsh8ytm7uG7IVtFR+QtWC5DGUEAM9lbiWxRr8WO7ti68waLl1fsnihtizGce8FvFVlZzasnpCYTn6Bi6EbXoub7quw0y7mlQbYHLFy8prEzqnTZk8uLyct42z2Sa2GBTIjyVV8+lcWke6Z7njuwHs/r1mUWtq5rgAMx2egAZJjzMSijlYQeOFZN6DfQWfJgFw2xrNP/KfnmwMcZ7E0V2hvEmlgSJ5G3qpPOkhAYxjZpd3vEaBX/0T0t41GGsRQ/c6lXcjUi2l6GhtRH/NQSw8B9PqBv0ebsCrDT+5VQyBlSYL4amubN/t2Y4/cRSM7lO3ix2brfsJpcaUO8P+81796rO7tSs8qao1ZMM/TvxXdBKVMV1paotvYyb/CjwIxc2FbRVbdqo2zNR7YbYVs3nA8Wzb4joyGOdjVpE87B4UPTrE1LlyxzU2Z5qSnYsr8Ai6ieRK49o0PpYvfofrGPDF7Z1jO6mr/SNrDP65FplGR2StN69tT6KAMdrZ9S+2pB7EAafrbEUc4Pen1W44thAAwlGJhfth2X+4Rh9VZLMON0bmaAT8YN3ZsJ6VTkoUs0hqy38VW+mojCOkKorAR5Hu7srQcv23xoyDtw6IO+aB5FF2jNNE=",
};

function setCors(req, res) {
  const origin = req.headers.origin;
  if (origin && SMS_CORS.includes(origin)) {
    res.set("Access-Control-Allow-Origin", origin);
  }
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
}

async function loadSmsPacks(firestore) {
  try {
    const snap = await firestore.collection("smsPricing").doc("config").get();
    const packs = snap.exists ? snap.data().packs : null;
    if (Array.isArray(packs) && packs.length) {
      const priced = packs
        .map((p) => ({
          ...p,
          credits: Number(p.credits) || 0,
          price: smsHelpers.priceForCredits(p.credits) || Number(p.price) || 0,
        }))
        .filter((p) => p.id && p.credits >= smsHelpers.SMS_MIN_PACK && p.price > 0);
      if (priced.length) return priced;
    }
  } catch (e) {
    console.error("[sms] failed to load smsPricing", e);
  }
  return smsHelpers.DEFAULT_SMS_PACKS;
}

async function assertBusinessMember(firestore, uid, businessId) {
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  if (!businessId || typeof businessId !== "string") {
    throw new HttpsError("invalid-argument", "businessId is required.");
  }
  const userSnap = await firestore.collection("gmanusers").doc(uid).get();
  if (!userSnap.exists) {
    throw new HttpsError("permission-denied", "User profile not found.");
  }
  const data = userSnap.data() || {};
  const businesses = Array.isArray(data.business) ? data.business : [];
  if (!businesses.includes(businessId)) {
    throw new HttpsError(
      "permission-denied",
      "You do not belong to this business."
    );
  }
  return data;
}

function canSendDebtSms(userData) {
  const role = String(userData.role || "").toLowerCase();
  const perms = Array.isArray(userData.permissions) ? userData.permissions : [];
  return (
    role === "owner" ||
    role === "manager" ||
    perms.includes("send_debt_sms") ||
    perms.includes("manage_debt")
  );
}

function canBuySms(userData) {
  return String(userData.role || "").toLowerCase() === "owner";
}

async function sendViaMobishastra(fetchImpl, secrets, mobileNo, msgText) {
  const user = secrets.user.value().trim();
  const pwd = secrets.pwd.value().trim();
  const senderId = (secrets.senderId.value() || "HesabuMz").trim() || "HesabuMz";
  if (!user || !pwd) {
    throw new HttpsError(
      "failed-precondition",
      "SMS gateway is not configured. Contact support."
    );
  }
  const url = smsHelpers.buildMobishastraUrl({
    user,
    pwd,
    senderId,
    mobileNo,
    msgText,
  });
  const res = await fetchImpl(url, { method: "GET" });
  const raw = await res.text();
  return smsHelpers.parseMobishastraResponse(raw);
}

async function applySmsCreditsToBusiness(firestore, admin, businessId, credits, meta) {
  const n = smsHelpers.parseSmsCreditsValue(credits);
  if (!n || !businessId) {
    throw new Error("Invalid SMS credit grant.");
  }
  const ref = firestore.collection("businesses").doc(businessId);
  await firestore.runTransaction(async (t) => {
    const snap = await t.get(ref);
    if (!snap.exists) {
      throw new Error(`Business ${businessId} not found`);
    }
    const data = snap.data() || {};
    t.update(ref, {
      smsCredits: (Number(data.smsCredits) || 0) + n,
      smsCreditsTotalPurchased: (Number(data.smsCreditsTotalPurchased) || 0) + n,
      smsLastPurchaseAt: admin.firestore.FieldValue.serverTimestamp(),
      smsLastPurchasePack: meta.packId || "",
    });
  });
  return n;
}

async function recordSmsSale(firestore, admin, {
  businessId,
  credits,
  amountTzs,
  packId,
  source,
  transactionId,
  note,
  sentBy,
}) {
  const payload = {
    businessId: String(businessId || "").trim(),
    credits: Math.trunc(Number(credits) || 0),
    amountTzs: Math.max(0, Math.trunc(Number(amountTzs) || 0)),
    packId: String(packId || "").trim(),
    source: String(source || "user_purchase"),
    transactionId: String(transactionId || "").trim(),
    note: String(note || "").trim(),
    sentBy: String(sentBy || "").trim(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  await firestore.collection("smsPurchases").add(payload);
  const statsUpdate = {
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (payload.source === "user_purchase" && payload.amountTzs > 0) {
    statsUpdate.revenueTzs = admin.firestore.FieldValue.increment(payload.amountTzs);
    statsUpdate.purchaseCount = admin.firestore.FieldValue.increment(1);
    statsUpdate.creditsSold = admin.firestore.FieldValue.increment(payload.credits);
  } else if (payload.source === "admin_grant") {
    statsUpdate.creditsGranted = admin.firestore.FieldValue.increment(payload.credits);
    statsUpdate.grantCount = admin.firestore.FieldValue.increment(1);
  }
  await firestore.collection("smsAdmin").doc("stats").set(statsUpdate, { merge: true });
}

/**
 * AzamPay webhook: credit SMS packs when productType=sms.
 * Returns true if this callback was an SMS purchase (caller should not extend app subscription).
 */
async function applySmsPaymentFromCallback(firestore, admin, additionalProps, extra = {}) {
  const productType = String(additionalProps.productType || "").toLowerCase();
  if (productType !== "sms") return false;

  const businessId = String(additionalProps.businessId || "").trim();
  const credits = smsHelpers.parseSmsCreditsValue(additionalProps.smsCredits);
  const packId = String(additionalProps.packId || "").trim();
  if (!businessId || !credits) {
    throw new Error("SMS payment callback missing businessId or smsCredits.");
  }
  await applySmsCreditsToBusiness(firestore, admin, businessId, credits, {
    packId,
  });
  const amountTzs = Math.max(
    0,
    Math.trunc(
      Number(additionalProps.amount) ||
        Number(extra.amount) ||
        smsHelpers.priceForCredits(credits) ||
        0
    )
  );
  try {
    await recordSmsSale(firestore, admin, {
      businessId,
      credits,
      amountTzs,
      packId,
      source: "user_purchase",
      transactionId: String(
        extra.transactionId || additionalProps.externalId || ""
      ).trim(),
    });
  } catch (e) {
    console.error("[sms] failed to record user purchase", e);
  }
  return true;
}

function createSmsHandlers({ firestore, admin, fetchImpl, secrets, assertCommissionAdmin }) {
  async function sendDebtReminderSms(request) {
      const uid = request.auth?.uid;
      const {
        businessId,
        clientIds,
        lang,
      } = request.data || {};

      const userData = await assertBusinessMember(firestore, uid, businessId);
      if (!canSendDebtSms(userData)) {
        throw new HttpsError(
          "permission-denied",
          "Only the owner or manager can send debt reminder SMS."
        );
      }

      const ids = Array.isArray(clientIds)
        ? clientIds.filter((id) => typeof id === "string" && id.trim())
        : [];
      if (!ids.length) {
        throw new HttpsError("invalid-argument", "Select at least one client.");
      }
      if (ids.length > MAX_REMINDERS_PER_CALL) {
        throw new HttpsError(
          "invalid-argument",
          `You can send at most ${MAX_REMINDERS_PER_CALL} SMS at once.`
        );
      }

      const bizSnap = await firestore.collection("businesses").doc(businessId).get();
      if (!bizSnap.exists) {
        throw new HttpsError("not-found", "Business not found.");
      }
      const business = bizSnap.data() || {};
      const businessName = business.name || "duka";
      const currency = business.mainCurrency || "TZS";
      const settings = smsHelpers.normalizeSmsSettings(business.smsSettings);
      const messageLang = lang === "en" ? "en" : "sw";

      const recipients = [];
      for (const clientId of ids) {
        const clientSnap = await firestore
          .collection("clients")
          .doc(businessId)
          .collection("userClients")
          .doc(clientId)
          .get();
        if (!clientSnap.exists) continue;
        const client = clientSnap.data() || {};
        const debt = Number(client.debt) || 0;
        if (debt <= 0) continue;
        const phone = smsHelpers.normalizeSmsPhone(client.phone);
        if (!phone || phone.length < 11) continue;
        const message = smsHelpers.buildDebtReminderMessage({
          clientName: client.name,
          amount: debt,
          currency,
          businessName,
          lang: messageLang,
          template: settings.debtReminderTemplate,
        });
        recipients.push({
          clientId,
          clientName: client.name || "",
          phone,
          debt,
          message,
          segments: smsHelpers.countSmsSegments(message),
        });
      }

      if (!recipients.length) {
        throw new HttpsError(
          "failed-precondition",
          "No clients with debt and a valid phone number were selected."
        );
      }

      const creditsNeeded = recipients.reduce((sum, r) => sum + r.segments, 0);
      const bizRef = firestore.collection("businesses").doc(businessId);
      const availableNow = Number(business.smsCredits) || 0;
      if (availableNow < creditsNeeded) {
        throw new HttpsError(
          "resource-exhausted",
          `Not enough SMS credits. Need ${creditsNeeded}, have ${availableNow}. Buy an SMS pack first.`
        );
      }

      await firestore.runTransaction(async (t) => {
        const snap = await t.get(bizRef);
        const data = snap.data() || {};
        const available = Number(data.smsCredits) || 0;
        if (available < creditsNeeded) {
          throw new Error("SMS_CREDITS_EXHAUSTED");
        }
        t.update(bizRef, {
          smsCredits: available - creditsNeeded,
          smsCreditsUsed: (Number(data.smsCreditsUsed) || 0) + creditsNeeded,
        });
      }).catch((err) => {
        if (String(err.message || "").includes("SMS_CREDITS_EXHAUSTED")) {
          throw new HttpsError(
            "resource-exhausted",
            `Not enough SMS credits. Need ${creditsNeeded}. Buy an SMS pack first.`
          );
        }
        throw err;
      });

      const results = [];
      let used = 0;
      let failedCredits = 0;

      for (const rec of recipients) {
        try {
          const parsed = await sendViaMobishastra(
            fetchImpl,
            secrets,
            rec.phone,
            rec.message
          );
          if (!parsed.success) {
            failedCredits += rec.segments;
            results.push({
              clientId: rec.clientId,
              phone: rec.phone,
              success: false,
              error: parsed.raw || "SMS not sent",
            });
            await firestore
              .collection("smsLogs")
              .doc(businessId)
              .collection("messages")
              .add({
                clientId: rec.clientId,
                clientName: rec.clientName,
                phone: rec.phone,
                message: rec.message,
                type: "debt_reminder",
                status: "failed",
                providerResponse: parsed.raw,
                credits: rec.segments,
                sentBy: uid,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
              });
            continue;
          }
          used += rec.segments;
          results.push({
            clientId: rec.clientId,
            phone: rec.phone,
            success: true,
            credits: rec.segments,
          });
          await firestore
            .collection("smsLogs")
            .doc(businessId)
            .collection("messages")
            .add({
              clientId: rec.clientId,
              clientName: rec.clientName,
              phone: rec.phone,
              message: rec.message,
              type: "debt_reminder",
              status: "sent",
              providerResponse: parsed.raw,
              credits: rec.segments,
              sentBy: uid,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        } catch (e) {
          failedCredits += rec.segments;
          results.push({
            clientId: rec.clientId,
            phone: rec.phone,
            success: false,
            error: e.message || "SMS delivery failed",
          });
        }
      }

      if (failedCredits > 0) {
        await bizRef.update({
          smsCredits: admin.firestore.FieldValue.increment(failedCredits),
          smsCreditsUsed: admin.firestore.FieldValue.increment(-failedCredits),
        });
      }

      const sent = results.filter((r) => r.success).length;
      return {
        success: sent > 0,
        sent,
        failed: results.length - sent,
        creditsUsed: used,
        results,
      };
  }

  async function makeSmsPayment(req, res) {
    setCors(req, res);
    if (req.method === "OPTIONS") {
      return res.status(204).send("");
    }
    try {
      const { phone, provider, amount, email, businessId, packId } = req.body || {};
      if (!phone || !provider || !amount || !email || !businessId || !packId) {
        return res.status(400).json({
          success: false,
          message: "Missing required fields",
        });
      }

      const packs = await loadSmsPacks(firestore);
      const pack = smsHelpers.getSmsPackById(packs, packId);
      if (!pack || pack.credits < smsHelpers.SMS_MIN_PACK) {
        return res.status(400).json({ success: false, message: "Unknown SMS pack" });
      }
      const expectedPrice = smsHelpers.priceForCredits(pack.credits);
      const paidAmount = parseInt(String(amount), 10);
      if (!Number.isFinite(paidAmount) || paidAmount !== expectedPrice) {
        return res.status(400).json({
          success: false,
          message: "Amount does not match SMS pricing (TZS 30, or TZS 25 from 1000 SMS).",
        });
      }

      const bizSnap = await firestore.collection("businesses").doc(businessId).get();
      if (!bizSnap.exists) {
        return res.status(404).json({ success: false, message: "Business not found" });
      }

      const tokenResponse = await fetchImpl(
        "https://authenticator.azampay.co.tz/AppRegistration/GenerateToken",
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(AZAMPAY_TOKEN_BODY),
        }
      );
      if (!tokenResponse.ok) {
        return res.status(500).json({ success: false, message: "Failed to get token" });
      }
      const tokenData = await tokenResponse.json();
      const accessToken = tokenData?.data?.accessToken;
      if (!accessToken) {
        return res.status(500).json({ success: false, message: "Invalid token response" });
      }

      const checkoutPayload = {
        accountNumber: phone,
        amount: String(expectedPrice),
        currency: "TZS",
        externalId: `sms_${businessId}_${Date.now()}`,
        provider,
        additionalProperties: {
          email,
          productType: "sms",
          smsCredits: String(pack.credits),
          businessId,
          packId: pack.id,
          amount: String(expectedPrice),
          source: "HesabuMauzoSms",
        },
      };

      const checkoutRes = await fetchImpl(
        "https://checkout.azampay.co.tz/azampay/mno/checkout",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
            "X-API-Key": "none",
          },
          body: JSON.stringify(checkoutPayload),
        }
      );
      const checkoutData = await checkoutRes.json();
      if (checkoutRes.ok && checkoutData.success) {
        return res.status(200).json({
          success: true,
          message: "Payment initiated successfully",
          transactionId: checkoutData.transactionId,
        });
      }
      return res.status(400).json({
        success: false,
        message: checkoutData.message || "Checkout failed",
      });
    } catch (error) {
      console.error("[makeSmsPayment]", error);
      return res.status(500).json({ success: false, message: "Internal server error" });
    }
  }

  async function grantSmsCredits(request) {
    await assertCommissionAdmin(request);
    const { businessId, credits, packId, note } = request.data || {};
    const n = smsHelpers.parseSmsCreditsValue(credits);
    if (!businessId || !n) {
      throw new HttpsError(
        "invalid-argument",
        "businessId and a positive credits count are required."
      );
    }
    await applySmsCreditsToBusiness(firestore, admin, String(businessId).trim(), n, {
      packId: packId || "admin_grant",
    });
    await firestore
      .collection("smsLogs")
      .doc(String(businessId).trim())
      .collection("messages")
      .add({
        type: "credit_grant",
        status: "granted",
        credits: n,
        note: note || "",
        sentBy: request.auth.uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    try {
      await recordSmsSale(firestore, admin, {
        businessId: String(businessId).trim(),
        credits: n,
        amountTzs: 0,
        packId: packId || "admin_grant",
        source: "admin_grant",
        note,
        sentBy: request.auth.uid,
      });
    } catch (e) {
      console.error("[sms] failed to record admin grant", e);
    }
    return { success: true, credits: n };
  }

  async function testSendSms(req, res) {
    const phone = smsHelpers.normalizeSmsPhone(
      (req.query && req.query.phone) ||
        (req.body && req.body.phone) ||
        "0758422100"
    );
    const allowed = new Set(["255758422100", "255765908208"]);
    if (!allowed.has(phone)) {
      return res.status(403).json({
        success: false,
        message: "Only configured test numbers are allowed.",
      });
    }
    let egressIp = "";
    try {
      egressIp = String(await (await fetchImpl("https://api.ipify.org")).text()).trim();
    } catch (_) {
      egressIp = "";
    }
    const message =
      "Habari, hii ni SMS ya majaribio kutoka Hesabu Mauzo (Cloud Function).";
    try {
      const parsed = await sendViaMobishastra(
        fetchImpl,
        secrets,
        phone,
        message
      );
      return res.status(200).json({
        success: parsed.success,
        code: parsed.code,
        raw: parsed.raw,
        phone,
        egressIp,
      });
    } catch (e) {
      return res.status(500).json({
        success: false,
        message: e.message || "SMS failed",
        phone,
        egressIp,
      });
    }
  }

  async function deductAndSend({
    businessId,
    phone,
    message,
    type,
    uid,
    extra,
  }) {
    const normalizedPhone = smsHelpers.normalizeSmsPhone(phone);
    if (!normalizedPhone || normalizedPhone.length < 11) {
      throw new HttpsError("invalid-argument", "A valid phone number is required.");
    }
    const msg = String(message || "").trim();
    if (!msg) {
      throw new HttpsError("invalid-argument", "Message is required.");
    }
    const segments = smsHelpers.countSmsSegments(msg);
    if (segments < 1 || segments > 4) {
      throw new HttpsError(
        "invalid-argument",
        "Message is too long. Keep it within 4 SMS parts."
      );
    }

    const bizRef = firestore.collection("businesses").doc(businessId);
    await firestore.runTransaction(async (t) => {
      const snap = await t.get(bizRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", "Business not found.");
      }
      const data = snap.data() || {};
      const available = Number(data.smsCredits) || 0;
      if (available < segments) {
        throw new Error("SMS_CREDITS_EXHAUSTED");
      }
      t.update(bizRef, {
        smsCredits: available - segments,
        smsCreditsUsed: (Number(data.smsCreditsUsed) || 0) + segments,
      });
    }).catch((err) => {
      if (String(err.message || "").includes("SMS_CREDITS_EXHAUSTED")) {
        throw new HttpsError(
          "resource-exhausted",
          `Not enough SMS credits. Need ${segments}. Buy an SMS pack first.`
        );
      }
      throw err;
    });

    let refunded = false;
    const refund = async () => {
      if (refunded) return;
      refunded = true;
      await bizRef.update({
        smsCredits: admin.firestore.FieldValue.increment(segments),
        smsCreditsUsed: admin.firestore.FieldValue.increment(-segments),
      });
    };
    try {
      const parsed = await sendViaMobishastra(fetchImpl, secrets, normalizedPhone, msg);
      const logBase = {
        phone: normalizedPhone,
        message: msg,
        type: type || "custom",
        credits: segments,
        sentBy: uid || "system",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        ...(extra && typeof extra === "object" ? extra : {}),
      };
      if (!parsed.success) {
        await refund();
        await firestore
          .collection("smsLogs")
          .doc(businessId)
          .collection("messages")
          .add({ ...logBase, status: "failed", providerResponse: parsed.raw });
        throw new HttpsError("internal", parsed.raw || "SMS not sent");
      }
      await firestore
        .collection("smsLogs")
        .doc(businessId)
        .collection("messages")
        .add({ ...logBase, status: "sent", providerResponse: parsed.raw });
      return {
        success: true,
        creditsUsed: segments,
        phone: normalizedPhone,
      };
    } catch (e) {
      await refund();
      if (e instanceof HttpsError) throw e;
      throw new HttpsError("internal", e.message || "SMS delivery failed");
    }
  }

  function normalizeLines(raw) {
    return smsHelpers.normalizeSmsLines(raw);
  }

  async function sendBusinessSms(request) {
    const uid = request.auth?.uid;
    const data = request.data || {};
    const {
      businessId,
      type,
      phone,
      clientId,
      supplierId,
      clientName,
      supplierName,
      referenceId,
      amount,
      remaining,
      lines,
      lang,
      message,
    } = data;

    const userData = await assertBusinessMember(firestore, uid, businessId);
    const role = String(userData.role || "").toLowerCase();
    const perms = Array.isArray(userData.permissions) ? userData.permissions : [];
    const smsType = String(type || "custom");
    const allowed =
      role === "owner" ||
      role === "manager" ||
      (smsType === "invoice" && (perms.includes("share_invoices") || perms.includes("print_invoices"))) ||
      (smsType === "purchase_list" && perms.includes("buy_products")) ||
      (["advance", "debt_payment", "debt_reminder"].includes(smsType) &&
        (perms.includes("send_debt_sms") || perms.includes("manage_debt"))) ||
      smsType === "custom";
    if (!allowed) {
      throw new HttpsError("permission-denied", "You cannot send this SMS.");
    }

    const bizSnap = await firestore.collection("businesses").doc(businessId).get();
    if (!bizSnap.exists) {
      throw new HttpsError("not-found", "Business not found.");
    }
    const business = bizSnap.data() || {};
    const settings = smsHelpers.normalizeSmsSettings(business.smsSettings);
    const businessName = business.name || "duka";
    const currency = business.mainCurrency || "TZS";
    const messageLang = lang === "en" ? "en" : "sw";

    if (smsType === "advance" && !settings.advanceSmsEnabled) {
      throw new HttpsError("failed-precondition", "Advance SMS is turned off.");
    }
    if (smsType === "debt_payment" && !settings.debtPaymentSmsEnabled) {
      throw new HttpsError("failed-precondition", "Debt payment SMS is turned off.");
    }

    let destPhone = phone;
    let destName = clientName || supplierName || "";
    if (!destPhone && clientId) {
      const clientSnap = await firestore
        .collection("clients")
        .doc(businessId)
        .collection("userClients")
        .doc(String(clientId))
        .get();
      if (clientSnap.exists) {
        const client = clientSnap.data() || {};
        destPhone = client.phone;
        destName = destName || client.name || "";
      }
    }
    if (!destPhone && supplierId) {
      const supplierSnap = await firestore
        .collection("suppliers")
        .doc(businessId)
        .collection("userSuppliers")
        .doc(String(supplierId))
        .get();
      if (supplierSnap.exists) {
        const supplier = supplierSnap.data() || {};
        destPhone = supplier.phone;
        destName = destName || supplier.name || "";
      }
    }

    let invoiceAmount = amount;
    let itemLines = normalizeLines(lines);
    let purchaseDraftRef = null;
    if (smsType === "invoice" && referenceId) {
      const invoiceId = String(referenceId).trim();
      if (invoiceId && !invoiceId.includes("/")) {
        const invoiceSnap = await firestore
          .collection("invoices")
          .doc(businessId)
          .collection("userInvoices")
          .doc(invoiceId)
          .get();
        if (invoiceSnap.exists) {
          const invoice = invoiceSnap.data() || {};
          const storedLines = normalizeLines(invoice.products);
          if (storedLines.length > 0) {
            itemLines = storedLines;
          }
          if (Number.isFinite(Number(invoice.price))) {
            invoiceAmount = Number(invoice.price);
          }
        }
      }
    }
    if (smsType === "purchase_list" && referenceId) {
      const draftId = String(referenceId).trim();
      if (!draftId || draftId.includes("/")) {
        throw new HttpsError("invalid-argument", "Invalid purchase list ID.");
      }
      purchaseDraftRef = firestore
        .collection("purchaseLists")
        .doc(businessId)
        .collection("drafts")
        .doc(draftId);
      const draftSnap = await purchaseDraftRef.get();
      if (!draftSnap.exists) {
        throw new HttpsError("not-found", "Purchase list not found.");
      }
      const draft = draftSnap.data() || {};
      if (String(draft.status || "draft") === "converted") {
        throw new HttpsError(
          "failed-precondition",
          "This purchase list was already converted."
        );
      }
      const storedLines = normalizeLines(draft.products);
      if (storedLines.length === 0) {
        throw new HttpsError(
          "failed-precondition",
          "Purchase list has no products."
        );
      }
      itemLines = storedLines;
      destPhone = destPhone || draft.supplierPhone;
      destName = destName || draft.supplierName || "";
    }
    let text = String(message || "").trim();
    if (!text) {
      if (smsType === "invoice") {
        text = smsHelpers.buildInvoiceSms({
          clientName: destName,
          amount: invoiceAmount,
          currency,
          businessName,
          lines: itemLines,
          lang: messageLang,
        });
      } else if (smsType === "purchase_list") {
        text = smsHelpers.buildPurchaseListSms({
          supplierName: destName,
          businessName,
          lines: itemLines,
          lang: messageLang,
        });
      } else if (smsType === "advance") {
        text = smsHelpers.buildAdvanceSms({
          clientName: destName,
          amount,
          currency,
          businessName,
          lang: messageLang,
        });
      } else if (smsType === "debt_payment") {
        text = smsHelpers.buildDebtPaymentSms({
          clientName: destName,
          amount,
          remaining,
          currency,
          businessName,
          lang: messageLang,
        });
      } else if (smsType === "debt_reminder") {
        text = smsHelpers.buildDebtReminderMessage({
          clientName: destName,
          amount,
          currency,
          businessName,
          lang: messageLang,
          template: settings.debtReminderTemplate,
        });
      } else {
        throw new HttpsError("invalid-argument", "Message or a supported SMS type is required.");
      }
    }

    const result = await deductAndSend({
      businessId,
      phone: destPhone,
      message: text,
      type: smsType,
      uid,
      extra: {
        clientId: clientId || "",
        clientName: destName,
        supplierId: supplierId || "",
        referenceId: referenceId || "",
        lineCount: itemLines.length,
      },
    });
    if (purchaseDraftRef) {
      await purchaseDraftRef.update({
        lastSentAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        sendCount: admin.firestore.FieldValue.increment(1),
      }).catch((error) => {
        console.error("Purchase list SMS sent but metadata update failed", {
          businessId,
          referenceId,
          error: error?.message || String(error),
        });
      });
    }
    return result;
  }

  async function updateSmsSettings(request) {
    const uid = request.auth?.uid;
    const { businessId, settings } = request.data || {};
    const userData = await assertBusinessMember(firestore, uid, businessId);
    if (String(userData.role || "").toLowerCase() !== "owner") {
      throw new HttpsError("permission-denied", "Only the owner can change SMS settings.");
    }
    const bizRef = firestore.collection("businesses").doc(businessId);
    const bizSnap = await bizRef.get();
    if (!bizSnap.exists) {
      throw new HttpsError("not-found", "Business not found.");
    }
    const existing = (bizSnap.data() || {}).smsSettings || {};
    const merged = {
      ...(existing && typeof existing === "object" ? existing : {}),
      ...(settings && typeof settings === "object" ? settings : {}),
    };
    const normalized = smsHelpers.normalizeSmsSettings(merged);
    await bizRef.update({
      smsSettings: normalized,
    });
    return { success: true, settings: normalized };
  }

  function serializeTs(value) {
    if (!value) return null;
    if (typeof value.toDate === "function") {
      return { _seconds: Math.floor(value.toDate().getTime() / 1000) };
    }
    if (typeof value._seconds === "number") return { _seconds: value._seconds };
    if (typeof value.seconds === "number") return { _seconds: value.seconds };
    return null;
  }

  async function fetchGatewayBalance() {
    const user = secrets.user.value().trim();
    const pwd = secrets.pwd.value().trim();
    if (!user || !pwd) {
      return {
        success: false,
        credits: null,
        raw: "",
        error: "SMS gateway is not configured.",
      };
    }
    const url = smsHelpers.buildMobishastraBalanceUrl({ user, pwd });
    const res = await fetchImpl(url, { method: "GET" });
    const raw = await res.text();
    const parsed = smsHelpers.parseMobishastraBalance(raw);
    if (!parsed.success) {
      return {
        success: false,
        credits: parsed.credits,
        raw: parsed.raw,
        error: parsed.raw || "Could not read gateway balance.",
      };
    }
    return { success: true, credits: parsed.credits, raw: parsed.raw, error: "" };
  }

  async function adminGetSmsOverview(request) {
    await assertCommissionAdmin(request);
    const [gateway, shopSnap, purchasesSnap, statsSnap] = await Promise.all([
      fetchGatewayBalance().catch((e) => ({
        success: false,
        credits: null,
        raw: "",
        error: e.message || "Gateway balance request failed.",
      })),
      firestore
        .collection("businesses")
        .select("name", "email", "smsCredits", "smsCreditsUsed", "smsCreditsTotalPurchased")
        .get(),
      firestore
        .collection("smsPurchases")
        .orderBy("createdAt", "desc")
        .limit(50)
        .get(),
      firestore.collection("smsAdmin").doc("stats").get(),
    ]);

    let remaining = 0;
    let used = 0;
    let purchased = 0;
    const shops = [];
    for (const doc of shopSnap.docs) {
      const d = doc.data() || {};
      const smsRemaining = Number(d.smsCredits) || 0;
      const smsUsed = Number(d.smsCreditsUsed) || 0;
      const smsPurchased = Number(d.smsCreditsTotalPurchased) || 0;
      remaining += smsRemaining;
      used += smsUsed;
      purchased += smsPurchased;
      if (smsRemaining > 0 || smsPurchased > 0 || smsUsed > 0) {
        shops.push({
          id: doc.id,
          name: d.name || "",
          email: d.email || "",
          smsCredits: smsRemaining,
          smsCreditsUsed: smsUsed,
          smsCreditsTotalPurchased: smsPurchased,
        });
      }
    }
    shops.sort((a, b) => b.smsCredits - a.smsCredits);

    const stats = statsSnap.exists ? statsSnap.data() || {} : {};
    const purchases = purchasesSnap.docs.map((doc) => {
      const d = doc.data() || {};
      return {
        id: doc.id,
        businessId: d.businessId || "",
        credits: Number(d.credits) || 0,
        amountTzs: Number(d.amountTzs) || 0,
        packId: d.packId || "",
        source: d.source || "",
        note: d.note || "",
        createdAt: serializeTs(d.createdAt),
      };
    });

    return {
      success: true,
      gateway: {
        remaining: gateway.credits,
        success: Boolean(gateway.success),
        error: gateway.error || "",
      },
      shops: {
        remaining,
        used,
        purchased,
        count: shopSnap.size,
      },
      revenue: {
        tzs: Number(stats.revenueTzs) || 0,
        purchaseCount: Number(stats.purchaseCount) || 0,
        creditsSold: Number(stats.creditsSold) || 0,
        creditsGranted: Number(stats.creditsGranted) || 0,
        grantCount: Number(stats.grantCount) || 0,
      },
      topShops: shops.slice(0, 40),
      purchases,
    };
  }

  async function businessesWithSmsCredits() {
    const snap = await firestore
      .collection("businesses")
      .where("smsCredits", ">", 0)
      .limit(200)
      .get();
    return snap.docs;
  }

  async function processScheduledSmsJobs() {
    const today = smsHelpers.startOfDayNairobi();
    const bizDocs = await businessesWithSmsCredits();
    let sent = 0;
    let skipped = 0;

    for (const bizDoc of bizDocs) {
      const business = bizDoc.data() || {};
      const businessId = bizDoc.id;
      const settings = smsHelpers.normalizeSmsSettings(business.smsSettings);
      const businessName = business.name || "duka";
      const currency = business.mainCurrency || "TZS";
      const expireWarning = Math.max(0, Math.trunc(Number(business.expireWarning) || 30));

      try {
        const debtsSnap = await firestore
          .collection("debtHistory")
          .doc(businessId)
          .collection("clientDebtHistory")
          .where("status", "==", "PENDING")
          .limit(80)
          .get();

        const phonesSent = new Set();
        for (const debtDoc of debtsSnap.docs) {
          const debt = debtDoc.data() || {};
          const remaining = Number(debt.remainingDebtAmount) || 0;
          const incurred = smsHelpers.firestoreToDate(debt.dateIncurred) || today;
          const dueDate =
            smsHelpers.firestoreToDate(debt.dueDate) ||
            smsHelpers.dueDateFrom(incurred, debt.creditDays || settings.defaultCreditDays);
          const lastReminderAt = smsHelpers.firestoreToDate(debt.lastReminderAt);
          if (
            !smsHelpers.shouldSendScheduledReminder({
              remainingDebt: remaining,
              dueDate,
              today,
              reminderDaysBefore: settings.reminderDaysBefore,
              reminderDaysAfter: settings.reminderDaysAfter,
              reminderAfterMode: settings.reminderAfterMode,
              reminderCount: debt.smsReminderCount,
              reminderMaxCount: settings.reminderMaxCount,
              lastReminderAt,
            })
          ) {
            skipped += 1;
            continue;
          }

          let phone = debt.phone;
          let clientName = debt.name || "";
          if (debt.client) {
            const clientSnap = await firestore
              .collection("clients")
              .doc(businessId)
              .collection("userClients")
              .doc(String(debt.client))
              .get();
            if (clientSnap.exists) {
              const client = clientSnap.data() || {};
              phone = phone || client.phone;
              clientName = clientName || client.name || "";
            }
          }
          const normalizedPhone = smsHelpers.normalizeSmsPhone(phone);
          if (!normalizedPhone || phonesSent.has(normalizedPhone)) {
            skipped += 1;
            continue;
          }

          const message = smsHelpers.buildDebtReminderMessage({
            clientName,
            amount: remaining,
            currency,
            businessName,
            dueDateLabel: smsHelpers.formatDueDateLabel(dueDate),
            lang: "sw",
            template: settings.debtReminderTemplate,
          });
          try {
            await deductAndSend({
              businessId,
              phone: normalizedPhone,
              message,
              type: "debt_reminder",
              uid: "scheduler",
              extra: { clientId: debt.client || "", clientName, debtId: debtDoc.id },
            });
            phonesSent.add(normalizedPhone);
            await debtDoc.ref.update({
              smsReminderCount: (Number(debt.smsReminderCount) || 0) + 1,
              lastReminderAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            sent += 1;
          } catch (e) {
            console.error("[sms] scheduled reminder failed", businessId, debtDoc.id, e);
            break;
          }
        }
      } catch (e) {
        console.error("[sms] reminder scan failed", businessId, e);
      }

      const needProductScan =
        settings.expiryAlertEnabled || settings.lowStockAlertEnabled;
      let productsSnap = null;
      if (needProductScan) {
        try {
          productsSnap = await firestore
            .collection("products")
            .doc(businessId)
            .collection("userProducts")
            .limit(400)
            .get();
        } catch (e) {
          console.error("[sms] product scan failed", businessId, e);
        }
      }

      if (settings.expiryAlertEnabled && productsSnap) {
        const lastExpiry = smsHelpers.firestoreToDate(business.smsLastExpiryAlertAt);
        if (!lastExpiry || !smsHelpers.sameCalendarDay(lastExpiry, today)) {
          try {
            const soon = [];
            const until = new Date(today);
            until.setDate(until.getDate() + expireWarning);
            for (const p of productsSnap.docs) {
              const prod = p.data() || {};
              const exp = smsHelpers.firestoreToDate(prod.expireDate);
              if (!exp) continue;
              if (exp >= today && exp <= until) {
                soon.push(prod.name || "bidhaa");
              }
            }
            const ownerPhone = business.phone;
            if (soon.length && ownerPhone) {
              const message = smsHelpers.buildExpiryAlertSms({
                businessName,
                products: soon,
                lang: "sw",
              });
              await deductAndSend({
                businessId,
                phone: ownerPhone,
                message,
                type: "expiry_alert",
                uid: "scheduler",
                extra: { clientName: businessName },
              });
              await bizDoc.ref.update({
                smsLastExpiryAlertAt: admin.firestore.FieldValue.serverTimestamp(),
              });
              sent += 1;
            }
          } catch (e) {
            console.error("[sms] expiry alert failed", businessId, e);
          }
        }
      }

      if (settings.lowStockAlertEnabled && productsSnap) {
        const lastLowStock = smsHelpers.firestoreToDate(business.smsLastLowStockAlertAt);
        if (!lastLowStock || !smsHelpers.sameCalendarDay(lastLowStock, today)) {
          try {
            const low = productsSnap.docs
              .map((p) => p.data() || {})
              .filter((prod) => smsHelpers.isLowStockProduct(prod));
            const ownerPhone = business.phone;
            if (low.length && ownerPhone) {
              const message = smsHelpers.buildLowStockAlertSms({
                businessName,
                products: low,
                lang: "sw",
              });
              await deductAndSend({
                businessId,
                phone: ownerPhone,
                message,
                type: "low_stock_alert",
                uid: "scheduler",
                extra: { clientName: businessName, count: low.length },
              });
              await bizDoc.ref.update({
                smsLastLowStockAlertAt: admin.firestore.FieldValue.serverTimestamp(),
              });
              sent += 1;
            }
          } catch (e) {
            console.error("[sms] low stock alert failed", businessId, e);
          }
        }
      }
    }

    return { success: true, sent, skipped };
  }

  async function sumTodaySalesAndExpenses(businessId, today) {
    const start = admin.firestore.Timestamp.fromDate(smsHelpers.startOfDayNairobi(today));
    const end = admin.firestore.Timestamp.fromDate(smsHelpers.endOfDayNairobi(today));
    let sales = 0;
    let profit = 0;
    let expenses = 0;

    const salesSnap = await firestore
      .collection("sales")
      .doc(businessId)
      .collection("userSales")
      .where("date", ">=", start)
      .where("date", "<=", end)
      .limit(500)
      .get();
    for (const doc of salesSnap.docs) {
      const s = doc.data() || {};
      if (String(s.saleType || "") === "debt_repayment") continue;
      const price = Number(s.price) || 0;
      const buying = Number(s.buyingPrice) || 0;
      sales += price;
      profit += price - buying;
    }

    const expSnap = await firestore
      .collection("expenses")
      .doc(businessId)
      .collection("userExpenses")
      .where("date", ">=", start)
      .where("date", "<=", end)
      .limit(300)
      .get();
    for (const doc of expSnap.docs) {
      expenses += Number((doc.data() || {}).amount) || 0;
    }
    profit -= expenses;
    return { sales, profit, expenses };
  }

  async function processDailyDigestJobs() {
    const today = new Date();
    const bizDocs = await businessesWithSmsCredits();
    let sent = 0;
    for (const bizDoc of bizDocs) {
      const business = bizDoc.data() || {};
      const settings = smsHelpers.normalizeSmsSettings(business.smsSettings);
      if (!settings.dailyDigestEnabled) continue;
      const last = smsHelpers.firestoreToDate(business.smsLastDailyDigestAt);
      if (last && smsHelpers.sameCalendarDay(last, smsHelpers.startOfDayNairobi(today))) {
        continue;
      }
      const ownerPhone = business.phone;
      if (!ownerPhone) continue;
      try {
        const totals = await sumTodaySalesAndExpenses(bizDoc.id, today);
        const message = smsHelpers.buildDailyDigestSms({
          businessName: business.name || "duka",
          sales: totals.sales,
          profit: totals.profit,
          expenses: totals.expenses,
          currency: business.mainCurrency || "TZS",
          lang: "sw",
        });
        await deductAndSend({
          businessId: bizDoc.id,
          phone: ownerPhone,
          message,
          type: "daily_digest",
          uid: "scheduler",
          extra: { clientName: business.name || "" },
        });
        await bizDoc.ref.update({
          smsLastDailyDigestAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        sent += 1;
      } catch (e) {
        console.error("[sms] daily digest failed", bizDoc.id, e);
      }
    }
    return { success: true, sent };
  }

  return {
    sendDebtReminderSms,
    sendBusinessSms,
    updateSmsSettings,
    processScheduledSmsJobs,
    processDailyDigestJobs,
    makeSmsPayment,
    grantSmsCredits,
    testSendSms,
    adminGetSmsOverview,
    applySmsPaymentFromCallback,
    loadSmsPacks,
    canBuySms,
  };
}

module.exports = {
  createSmsHandlers,
  applySmsPaymentFromCallback,
  applySmsCreditsToBusiness,
};
