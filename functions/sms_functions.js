const { onCall, onRequest } = require("firebase-functions/v2/https");
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
    if (Array.isArray(packs) && packs.length) return packs;
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

/**
 * AzamPay webhook: credit SMS packs when productType=sms.
 * Returns true if this callback was an SMS purchase (caller should not extend app subscription).
 */
async function applySmsPaymentFromCallback(firestore, admin, additionalProps) {
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
  return true;
}

function registerSmsFunctions({ firestore, admin, fetchImpl, secrets, assertCommissionAdmin }) {
  const sendDebtReminderSms = onCall(
    {
      region: "us-central1",
      secrets: [secrets.user, secrets.pwd, secrets.senderId],
    },
    async (request) => {
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
  );

  const makeSmsPayment = onRequest(async (req, res) => {
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
      if (!pack) {
        return res.status(400).json({ success: false, message: "Unknown SMS pack" });
      }
      const paidAmount = parseInt(String(amount), 10);
      if (!Number.isFinite(paidAmount) || paidAmount !== Number(pack.price)) {
        return res.status(400).json({
          success: false,
          message: "Amount does not match the selected SMS pack.",
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
        amount: String(pack.price),
        currency: "TZS",
        externalId: `sms_${businessId}_${Date.now()}`,
        provider,
        additionalProperties: {
          email,
          productType: "sms",
          smsCredits: String(pack.credits),
          businessId,
          packId: pack.id,
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
  });

  const grantSmsCredits = onCall({ region: "us-central1" }, async (request) => {
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
    return { success: true, credits: n };
  });

  return {
    sendDebtReminderSms,
    makeSmsPayment,
    grantSmsCredits,
    applySmsPaymentFromCallback,
    loadSmsPacks,
    canBuySms,
  };
}

module.exports = {
  registerSmsFunctions,
  applySmsPaymentFromCallback,
  applySmsCreditsToBusiness,
};
