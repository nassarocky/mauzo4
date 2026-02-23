const { onCall, onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { HttpsError } = require("firebase-functions/v2/https");
const {onDocumentCreated, onDocumentWritten} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
admin.initializeApp();
const firestore = admin.firestore();
const { getAuth } = require('firebase-admin/auth');
const auth = getAuth();
const fetch = require("node-fetch");
const twilio = require('twilio');
const functions = require('firebase-functions');
const accountSid = 'ACdffb6ab3d81793f9677651222e218000'; // your actual SID
const authToken = '86bf7077fe67b4cd6ce83b01fb0399b6'; // your actual Auth Token
const client = new twilio(accountSid, authToken);

// Load v2 aggregate functions (write to new 'aggregates' collection only)
const aggregates = require('./aggregates_v2');
Object.assign(exports, aggregates);

// Explicitly export to satisfy Firebase CLI analyzer
exports.aggregateSalesV2 = aggregates.aggregateSalesV2;
exports.aggregateRecoveredV2 = aggregates.aggregateRecoveredV2;
exports.aggregateExpensesV2 = aggregates.aggregateExpensesV2;
exports.aggregateDebtOutstandingV2 = aggregates.aggregateDebtOutstandingV2;
exports.snapshotCurrentPeriodV2 = aggregates.snapshotCurrentPeriodV2;
exports.onBusinessResetTimeChangedV2 = aggregates.onBusinessResetTimeChangedV2;



exports.deleteBusiness = onRequest(
  {
    cors: ["https://hesabumauzo.co.tz", "https://biashara.hesabumauzo.co.tz"],
    region: "us-central1",
  },
  async (req, res) => {
    const businessId = req.body.businessId;
    const ownerId = req.body.ownerId;

    if (!businessId || !ownerId) {
      return res.status(400).send({ error: "businessId and ownerId are required." });
    }

    try {
      // Reference to the business document
      const businessRef = admin.firestore().collection('businesses').doc(businessId);
      const businessDoc = await businessRef.get();
      if (!businessDoc.exists) {
        return res.status(404).send({ error: "Business not found." });
      }

      // List of subcollections to delete (derived from FirestoreDb class)
      const subcollections = [
        'transactions/usersTransactions',
        'productReports/userReports',
        'products/userProducts',
        'store/userStore',
        'closedbooks/userClosedBooks',
        'sales/userSales',
        'recovered/userRecovered',
        'debtHistory/clientDebtHistory',
        'expenses/userExpenses',
        'invoices/userInvoices',
        'clients/userClients',
        'employees/userEmployees',
        'carts/userCarts', // From handleWhatsAppMessage function
        'feedback/userFeedback', // From handleWhatsAppMessage function
        'productReports/userReports', // Repeated in FirestoreDb, included for completeness
      ];

      // Remove duplicates from the subcollection list
      const uniqueSubcollections = [...new Set(subcollections.map(path => path.split('/')[0]))];

      // Delete all subcollections
      for (const subcollection of uniqueSubcollections) {
        await deleteCollection(firestore.collection('businesses').doc(businessId).collection(subcollection), 500);
      }

      // Delete the business document itself
      await businessRef.delete();

      // Update the gmanusers collection to remove the businessId from the owner's business list
      const userRef = admin.firestore().collection('gmanusers').doc(ownerId);
      const userDoc = await userRef.get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        const updatedBusinessList = userData.business.filter(id => id !== businessId);
        await userRef.update({ business: updatedBusinessList });
      }

      return res.status(200).send({ success: true, message: `Successfully deleted business ${businessId}, its subcollections, and updated owner ${ownerId}` });
    } catch (error) {
      console.error("Error deleting business:", error);
      return res.status(500).send({ success: false, message: `Error: ${error.message}` });
    }
  }
);

// Helper function to delete a collection in batches
async function deleteCollection(collectionRef, batchSize) {
  const snapshot = await collectionRef.limit(batchSize).get();

  if (snapshot.size === 0) {
    return;
  }

  const batch = firestore.batch();
  snapshot.docs.forEach(doc => {
    batch.delete(doc.ref);
  });

  await batch.commit();

  // Recursively delete remaining documents if any
  if (snapshot.size === batchSize) {
    await deleteCollection(collectionRef, batchSize);
  }
}

exports.makePayment = onRequest(async (req, res) => {
  const origin = req.headers.origin;
  const allowedOrigins = [
    "https://hesabumauzo.co.tz",
    "https://biashara.hesabumauzo.co.tz",
    "http://localhost:5000",
    "http://localhost:8080",
    "http://localhost:5173"
  ];
  if (origin && allowedOrigins.includes(origin)) {
    res.set("Access-Control-Allow-Origin", origin);
  }
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }
  try {
    const {
      phone,
      provider,
      amount,
      durationSeconds,
      email
    } = req.body;

    if (!phone || !provider || !amount || !durationSeconds || !email) {
      return res.status(400).json({ success: false, message: "Missing required fields" });
    }

    // === Step 1: Generate Token ===
    const tokenResponse = await fetch("https://authenticator.azampay.co.tz/AppRegistration/GenerateToken", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        appName: "Hesabu Mauzo",
        clientId: "01963395-6a54-7444-b323-5ee39cdc4326",
        clientSecret: "U2dqWWORy9Aze/MN57++tkkziznBSJkXgqBUg1v3p8EEZT4ruEjRC3Y2B8Wsh8ytm7uG7IVtFR+QtWC5DGUEAM9lbiWxRr8WO7ti68waLl1fsnihtizGce8FvFVlZzasnpCYTn6Bi6EbXoub7quw0y7mlQbYHLFy8prEzqnTZk8uLyct42z2Sa2GBTIjyVV8+lcWke6Z7njuwHs/r1mUWtq5rgAMx2egAZJjzMSijlYQeOFZN6DfQWfJgFw2xrNP/KfnmwMcZ7E0V2hvEmlgSJ5G3qpPOkhAYxjZpd3vEaBX/0T0t41GGsRQ/c6lXcjUi2l6GhtRH/NQSw8B9PqBv0ebsCrDT+5VQyBlSYL4amubN/t2Y4/cRSM7lO3ix2brfsJpcaUO8P+81796rO7tSs8qao1ZMM/TvxXdBKVMV1paotvYyb/CjwIxc2FbRVbdqo2zNR7YbYVs3nA8Wzb4joyGOdjVpE87B4UPTrE1LlyxzU2Z5qSnYsr8Ai6ieRK49o0PpYvfofrGPDF7Z1jO6mr/SNrDP65FplGR2StN69tT6KAMdrZ9S+2pB7EAafrbEUc4Pen1W44thAAwlGJhfth2X+4Rh9VZLMON0bmaAT8YN3ZsJ6VTkoUs0hqy38VW+mojCOkKorAR5Hu7srQcv23xoyDtw6IO+aB5FF2jNNE="
      }),
    });

    if (!tokenResponse.ok) {
      const errText = await tokenResponse.text();
      console.error("Token error:", errText);
      return res.status(500).json({ success: false, message: "Failed to get token" });
    }

    const tokenData = await tokenResponse.json();
    const accessToken = tokenData?.data?.accessToken;

    if (!accessToken) {
      return res.status(500).json({ success: false, message: "Invalid token response" });
    }

    // === Step 2: Send Checkout Request ===
    const numberOfDays = parseFloat(durationSeconds) / (60 * 60 * 24);
    const checkoutPayload = {
      accountNumber: phone,
      amount: amount,
      currency: "TZS",
      externalId: "123",
      provider: provider,
      additionalProperties: {
        email: email,
        numberOfDays: numberOfDays,
        source: "HesabuMauzo"
      }
    };

    const checkoutRes = await fetch("https://checkout.azampay.co.tz/azampay/mno/checkout", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${accessToken}`,
        "X-API-Key": "none"
      },
      body: JSON.stringify(checkoutPayload),
    });

    const checkoutData = await checkoutRes.json();

    if (checkoutRes.ok && checkoutData.success) {
      console.log("Checkout success:", checkoutData);
      return res.status(200).json({
        success: true,
        message: "Payment initiated successfully",
        transactionId: checkoutData.transactionId
      });
    } else {
      console.error("Checkout failed:", checkoutData);
      return res.status(400).json({
        success: false,
        message: checkoutData.message || "Checkout failed"
      });
    }
  } catch (error) {
    console.error("Payment function error:", error);
    return res.status(500).json({ success: false, message: "Internal server error" });
  }
});


// Callable Functionconst allowedOrigins = ["https://hesabumauzo.co.tz", "https://biashara.hesabumauzo.co.tz"];
    exports.loginAdmin = onRequest(async (req, res) => {
      // Set CORS headers
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
      res.set("Access-Control-Allow-Headers", "Content-Type");

      // Handle preflight (OPTIONS) request
      if (req.method === "OPTIONS") {
        return res.status(204).send(""); // No Content
      }

      try {
        // Validate request method
        if (req.method !== "POST") {
          return res.status(405).json({ message: "Method not allowed. Use POST." });
        }

        const { username, password } = req.body;

        // Accept two different credentials
        if (
          (username === "admin" && password === "wanasa1243") ||
          (username === "luth" && password === "luth1234")
        ) {
          return res.status(200).json({ message: "Login successful!" });
        } else {
          return res.status(401).json({ message: "Invalid username or password." });
        }
      } catch (error) {
        console.error("Error in loginAdmin:", error);
        return res.status(500).json({ error: "Internal Server Error" });
      }
    });


                     // Add your allowed origins here

                    exports.getAllBusinesses = onRequest(async (req, res) => {
                      // Get the origin of the request
                      const origin = req.headers.origin;

                      // Check if the origin is in the list of allowed origins
                      if (allowedOrigins.includes(origin)) {
                        res.set("Access-Control-Allow-Origin", origin);
                      } else {
                        res.set("Access-Control-Allow-Origin", ""); // Block the request if the origin is not allowed
                      }

                      res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
                      res.set("Access-Control-Allow-Headers", "Content-Type");

                      // Handle preflight (OPTIONS) request
                      if (req.method === "OPTIONS") {
                        return res.status(204).send(""); // No Content
                      }

                      try {
                        console.log("Fetching all businesses");

                        // Query Firestore to get all businesses sorted by the 'date' field in descending order
                        const businessesSnapshot = await firestore
                          .collection("businesses")
                          .orderBy("date", "desc")
                          .get();

                        console.log("Query executed, snapshot size:", businessesSnapshot.size);

                        if (businessesSnapshot.empty) {
                          console.log("No businesses found");
                          return res.status(404).json({ message: "No businesses found." });
                        }

                        const businesses = businessesSnapshot.docs.map(doc => ({
                          id: doc.id,
                          ...doc.data(),
                        }));
                        console.log("Businesses fetched:", businesses);

                        return res.status(200).json(businesses);
                      } catch (error) {
                        console.error("Error fetching businesses:", error);
                        return res.status(500).json({ error: "Internal Server Error" });
                      }
                    });

                   const allowedOrigins = ["https://hesabumauzo.co.tz", "https://biashara.hesabumauzo.co.tz"];

                   exports.getAllUsers = onRequest(
                     {
                       cors: allowedOrigins, // Use the array of allowed origins directly
                       region: "us-central1", // If you've set a region
                     },
                     async (req, res) => {
                       // No need for manual CORS header setting or OPTIONS handling here
                       try {
                         console.log("Fetching all users");
                         const usersSnapshot = await firestore
                           .collection("gmanusers")
                           .orderBy("date", "desc") // Ensure 'gmanusers' has an index on 'date'
                           .get();

                         if (usersSnapshot.empty) {
                           console.log("No users found");
                           return res.status(404).json({ message: "No users found." });
                         }

                         const users = usersSnapshot.docs.map(doc => ({
                           id: doc.id,
                           ...doc.data(),
                         }));
                         console.log("Users fetched:", users);
                         return res.status(200).json(users);

                       } catch (error) {
                         console.error("Error fetching users:", error);
                         // The declarative 'cors' option handles headers for error responses too
                         return res.status(500).json({ error: "Internal Server Error", details: error.message });
                       }
                     }
                   );

exports.addSale = onCall(async (request) => {
  const { businessId, saleData, products } = request.data;

  if (!businessId) {
    throw new HttpsError("invalid-argument", "Business ID is required.");
  }

  try {
    const fullSaleData = {
      ...saleData,
      price: parseFloat(saleData.price) || 0.0,
      buyingPrice: parseFloat(saleData.buyingPrice) || 0.0,
      payment: parseFloat(saleData.payment) || 0.0,
      debt: parseFloat(saleData.debt) || 0.0,
      discount: parseFloat(saleData.discount) || 0.0,
      products,
      date: admin.firestore.Timestamp.now(),
    };

    const saleRef = firestore.collection("sales").doc(businessId).collection("userSales").doc();
    const saleId = saleRef.id;
    fullSaleData.id = saleId;
    await saleRef.set(fullSaleData);

    if (fullSaleData.debt > 0) {
      const debtHistoryRef = firestore
        .collection("debtHistory")
        .doc(businessId)
        .collection("clientDebtHistory")
        .doc(saleId);

      const debtHistoryData = {
        id: saleId,
        client: fullSaleData.client || "",
        name: fullSaleData.clientName || "",
        owner: businessId,
        saleId,
        initialDebtAmount: fullSaleData.debt,
        remainingDebtAmount: fullSaleData.debt,
        paymentRecords: [],
        dateIncurred: admin.firestore.Timestamp.now(),
        status: "PENDING",
        comment: fullSaleData.comment || "",
      };

      await debtHistoryRef.set(debtHistoryData);
    }

    return { success: true, saleId };
  } catch (error) {
    console.error("Error adding sale:", error);
    throw new HttpsError("internal", "Failed to add sale.");
  }
});

// HTTP Functions
exports.deleteUser = onRequest(async (req, res) => {
  const origin = req.headers.origin;
  const allowedOrigins = [
    "https://hesabumauzo.co.tz",
    "https://biashara.hesabumauzo.co.tz",
    "http://localhost:5000",
    "http://localhost:8080",
    "http://localhost:5173"
  ];
  if (origin && allowedOrigins.includes(origin)) {
    res.set("Access-Control-Allow-Origin", origin);
  }
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }
  const userId = req.body.userId;
  const businessId = req.body.businessId;

  if (!userId || !businessId) {
    return res.status(400).send({ error: "userId and businessId are required." });
  }

  try {
    await admin.firestore().collection('employees').doc(businessId).collection('userEmployees').doc(userId).delete();
    await admin.firestore().collection('users').doc(userId).delete();
    await admin.auth().deleteUser(userId);
    return res.status(200).send({ success: true, message: `Successfully deleted user ${userId} for business: ${businessId}` });
  } catch (error) {
    console.error("Error deleting user:", error);
    return res.status(500).send({ success: false, message: `Error: ${error.message}` });
  }
});



exports.registerUrser = onRequest({ region: 'us-central1' }, async (req, res) => {
  // CORS: allow production domains (and common localhost ports for dev) and handle preflight
  const origin = req.headers.origin;
  const allowedOrigins = [
    "https://hesabumauzo.co.tz",
    "https://biashara.hesabumauzo.co.tz",
    "http://localhost:5000",
    "http://localhost:8080",
    "http://localhost:5173"
  ];
  if (origin && allowedOrigins.includes(origin)) {
    res.set("Access-Control-Allow-Origin", origin);
  }
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  const { name, email, phone, password, business, role } = req.body;

  if (!name) return res.status(400).send('Missing name');
  if (!email) return res.status(400).send('Missing email');
  if (!password) return res.status(400).send('Missing password');
  if (!business) return res.status(400).send('Missing business');

  try {
    const userRecord = await auth.createUser({
      email,
      password,
      displayName: name,
    });

    const userId = userRecord.uid;
    const userData = {
      id: userId,
      email,
      role: role || 'employee', // Use provided role or default to 'employee'
      phone,
      name,
      maxBusiness: 2,
      password,
      business: [business],
      image: '',
      date: new Date(),
    };

    await firestore.collection('gmanusers').doc(userId).set(userData);
    await firestore.collection('employees').doc(business).collection('userEmployees').doc(userId).set(userData);

    return res.status(201).send({ message: "User created", userId });
  } catch (error) {
    console.error('Error:', error);
    if (error.code === 'auth/email-already-exists') return res.status(400).send('Email exists');
    if (error.code === 'auth/weak-password') return res.status(400).send('Weak password');
    return res.status(500).send('Server error');
  }
});

exports.registerUserWithBusiness = onCall(async (data, context) => {
  try {
    // Optional: Check if the user is authenticated
    if (!context.auth) {
      throw new HttpsError('unauthenticated', 'User must be authenticated to register a business.');
    }

    const {
      name,
      email,
      phone,
      password,
      business,
      mainCurrency,
      secondaryCurrency
    } = data;

    if (!name || !email || !password || !business || !mainCurrency) {
      throw new HttpsError('invalid-argument', 'Missing required fields.');
    }

    // ✅ Create Firebase Auth user
    const userRecord = await admin.auth().createUser({
      email,
      password,
      displayName: name,
      phoneNumber: phone || undefined,
    });

    const userId = userRecord.uid;

    // ✅ Create a new business doc
    const businessRef = admin.firestore().collection('businesses').doc();
    const businessId = businessRef.id;
    const uniqueStoreId = `${businessId}_${Date.now()}`;

    await businessRef.set({
      name: business,
      email,
      phone,
      subscriptionStatus: 'subscription_ontrial',
      tin: 'TIN',
      categories: [],
      manufacturer: [],
      location: [],
      debtEnabled: true,
      discountPercent: 10,
      mainCurrency,
      reset_time: admin.firestore.FieldValue.serverTimestamp(),
      expireWarning: 30,
      allowSalesView: true,
      secondaryCurrency,
      date: admin.firestore.FieldValue.serverTimestamp(),
      id: businessId,
      ownerId: userId,
      reserve: 0.0,
      additionalDouble1: 0.0,
      additionalDouble2: 0.0,
      additionalString1: 'true',
      additionalString2: uniqueStoreId,
      additionalList1: [],
      additionalList2: [],
    });

    // ✅ Add user to 'gmanusers'
    await admin.firestore().collection('gmanusers').doc(userId).set({
      id: userId,
      email,
      role: 'owner',
      phone,
      name,
      maxBusiness: 2,
      business: [businessId],
      image: '',
      date: admin.firestore.FieldValue.serverTimestamp(),
      // password field removed for security
    });

    // ✅ Add user to employees subcollection
    await admin.firestore()
      .collection('employees')
      .doc(businessId)
      .collection('userEmployees')
      .doc(userId)
      .set({
        id: userId,
        email,
        role: 'owner',
        phone,
        name,
        maxBusiness: 2,
        business: [businessId],
        image: '',
        date: admin.firestore.FieldValue.serverTimestamp(),
        // password field removed for security
      }, { merge: true });

    // ✅ Return a success response
    return {
      success: true,
      message: 'User and business created successfully.',
      userId,
      businessId,
    };

  } catch (error) {
    console.error('Error in registerUserWithBusiness:', error);
    throw new HttpsError('internal', error.message || 'Unknown error occurred');
  }
});



exports.checkSubscriptionStatusBusiness = onSchedule(
  { schedule: "every 24 hours" },
  async (event) => {
    const businessesRef = firestore.collection('businesses');
    const now = admin.firestore.Timestamp.now();
    const month = 30 * 86400;

    try {
      const snapshot = await businessesRef.get();
      if (snapshot.empty) return;

      const updates = [];
      for (const doc of snapshot.docs) {
        const business = doc.data();
        // Trial logic
        if (!business.paid) {
          if (!business.trialStart) {
            updates.push(doc.ref.update({ trialStart: now }));
          } else {
            const trialDuration = now.seconds - business.trialStart.seconds;
            const status = trialDuration > month ? 'trial_expired' : 'subscription_ontrial';
            updates.push(doc.ref.update({ subscriptionStatus: status }));
          }
        }
        // Paid logic
        if (business.paid && business.paymentStart && business.paymentLast) {
          const nowDate = now.toDate();
          const expired = nowDate < business.paymentStart.toDate() || nowDate > business.paymentLast.toDate();
          updates.push(doc.ref.update({
            paid: !expired,
            subscriptionStatus: expired ? 'subscription_ended' : 'subscription_ok'
          }));
        }
      }
      await Promise.all(updates);
      console.log('Business subscriptions updated');
    } catch (error) {
      console.error('Error:', error);
    }
  }
);


exports.paymentCallbackEmail2 = onRequest(
  {
    cors: ["https://hesabumauzo.co.tz", "https://biashara.hesabumauzo.co.tz"], // Explicitly allow your domains
  },
  async (req, res) => {
    // Handle preflight (OPTIONS) request
    if (req.method === "OPTIONS") {
      res.set("Access-Control-Allow-Methods", "GET");
      res.set("Access-Control-Allow-Headers", "Content-Type");
      return res.status(204).send(""); // No Content
    }

    try {
      // Ensure CORS headers are set for all responses
      res.set("Access-Control-Allow-Origin", req.headers.origin || "https://hesabumauzo.co.tz");

      const email = req.query.email;
      const numberOfDays = parseInt(req.query.numberOfDays, 10);

      // Validate inputs
      if (!email || isNaN(numberOfDays)) {
        console.error("Missing or invalid parameters", { email, numberOfDays });
        return res.status(400).json({
          error: "Missing or invalid email or numberOfDays parameter.",
        });
      }

      // Search for businesses by email
      const businessesSnapshot = await firestore
        .collection("businesses")
        .where("email", "==", email)
        .get();

      if (businessesSnapshot.empty) {
        console.log(`No businesses found with email ${email}`);
        return res.status(404).json({
          error: `No businesses found with email ${email}`,
        });
      }

      const paymentStart = admin.firestore.Timestamp.now();

      // Update businesses with fair renewal logic
      const updatePromises = businessesSnapshot.docs.map((businessDoc) => {
        const business = businessDoc.data();
        const now = paymentStart.toDate();
        
        // Check paid subscription end date
        const existingPaymentLast = business.paymentLast ? business.paymentLast.toDate() : null;
        
        // Check trial end date (trialStart + 30 days)
        const trialStart = business.trialStart ? business.trialStart.toDate() : null;
        const trialExpiry = trialStart ? new Date(trialStart.getTime() + 30 * 24 * 60 * 60 * 1000) : null;
        
        // Determine start date: use the latest of now, paid expiry, or trial expiry
        let startDate = now;
        
        // Check if paid subscription extends beyond current startDate
        if (existingPaymentLast && existingPaymentLast > startDate) {
          startDate = existingPaymentLast;
        }
        
        // Check if trial extends beyond current startDate (could be later than paid)
        if (trialExpiry && trialExpiry > startDate) {
          startDate = trialExpiry;
        }
        
        const paymentLast = admin.firestore.Timestamp.fromDate(
          new Date(startDate.getTime() + numberOfDays * 24 * 60 * 60 * 1000)
        );

        return businessDoc.ref.update({
          paid: true,
          subscriptionStatus: "subscription_ok",
          paymentStart,
          paymentLast,
        });
      });

      await Promise.all(updatePromises);
      console.log(`Updated businesses with email ${email}`);

      return res.status(200).json({
        success: true,
        message: `Payment processed for all businesses with email: ${email}`,
      });
    } catch (error) {
      console.error("Error in paymentCallbackEmail2:", error);
      res.set("Access-Control-Allow-Origin", req.headers.origin || "https://hesabumauzo.co.tz");
      return res.status(500).json({
        error: `Internal server error: ${error.message}`,
      });
    }
  }
);

exports.paymentCallbackEmail = onRequest(async (req, res) => {
  const callbackData = req.body; // ✅ FIXED: use `req`, not `request`
  const additionalProps = callbackData.additionalProperties || {};

  const numberOfDays = parseInt(additionalProps.numberOfDays, 10);
  const email = additionalProps.email;
  const status = (callbackData.transactionstatus || '').toLowerCase();

  if (status !== 'success') {
    console.log(`Payment status is not success: ${status}`);
    res.status(400).send('Payment not successful.');
    return;
  }

  if (!email || isNaN(numberOfDays)) {
    console.log("Missing email or numberOfDays");
    res.status(400).send('Missing required fields.');
    return;
  }

  const businessesRef = firestore.collection('businesses');
  businessesRef.where('email', '==', email).get()
    .then((snapshot) => {
      if (snapshot.empty) {
        console.log(`No businesses found with email ${email}.`);
        res.status(404).send('No businesses found.');
        return;
      }

      const paymentStart = admin.firestore.Timestamp.now();

      // Update businesses with fair renewal logic
      const updatePromises = snapshot.docs.map((businessDoc) => {
        const business = businessDoc.data();
        const now = paymentStart.toDate();
        
        // Check paid subscription end date
        const existingPaymentLast = business.paymentLast ? business.paymentLast.toDate() : null;
        
        // Check trial end date (trialStart + 30 days)
        const trialStart = business.trialStart ? business.trialStart.toDate() : null;
        const trialExpiry = trialStart ? new Date(trialStart.getTime() + 30 * 24 * 60 * 60 * 1000) : null;
        
        // Determine start date: use the latest of now, paid expiry, or trial expiry
        let startDate = now;
        
        // Check if paid subscription extends beyond current startDate
        if (existingPaymentLast && existingPaymentLast > startDate) {
          startDate = existingPaymentLast;
        }
        
        // Check if trial extends beyond current startDate (could be later than paid)
        if (trialExpiry && trialExpiry > startDate) {
          startDate = trialExpiry;
        }
        
        const paymentLast = admin.firestore.Timestamp.fromDate(
          new Date(startDate.getTime() + (numberOfDays * 24 * 60 * 60 * 1000))
        );

        return businessDoc.ref.update({
          paid: true,
          subscriptionStatus: 'subscription_ok',
          paymentStart: paymentStart,
          paymentLast: paymentLast
        });
      });

      Promise.all(updatePromises)
        .then(() => {
          console.log(`Updated all businesses with email ${email}.`);
          res.status(200).send(`Payment processed for ${email}`);
        })
        .catch((error) => {
          console.error('Error updating Firestore:', error);
          res.status(500).send('Error processing payment.');
        });
    })
    .catch((error) => {
      console.error('Error querying Firestore:', error);
      res.status(500).send('Error during query.');
    });
});


exports.resetProductQuantities = onRequest(async (req, res) => {
  const origin = req.headers.origin;
  const allowedOrigins = [
    "https://hesabumauzo.co.tz",
    "https://biashara.hesabumauzo.co.tz",
    "http://localhost:5000",
    "http://localhost:8080",
    "http://localhost:5173"
  ];
  if (origin && allowedOrigins.includes(origin)) {
    res.set("Access-Control-Allow-Origin", origin);
  }
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }
 const profile = req.query.profile || req.query.business;  // Get the profile from the query parameter

    if (!profile) {
        console.error('Missing profile parameter');
        return res.status(400).send('Missing profile parameter');
    }

    const userProductsRef = admin.firestore().collection('products').doc(profile).collection('userProducts');

    try {
        const querySnapshot = await userProductsRef.get();

        const promises = querySnapshot.docs.map(doc => {
            const data = doc.data();
            if (data && data.hasOwnProperty('quantity')) {
                const quantity = data['quantity'];
                return doc.ref.update({ total: quantity });
            } else {
                return Promise.resolve();
            }
        });

        await Promise.all(promises);

        console.log('Product quantities successfully updated.');

        // Set the reset_time in the user's document
        const userRef = admin.firestore().collection('users').doc(profile);
        console.log(`Updating reset_time for user: ${profile}`);
        await userRef.update({
            reset_time: admin.firestore.Timestamp.now()
        });
        console.log('Reset time successfully updated.');

        res.status(200).send('Product quantities and reset time successfully updated.');
    } catch (error) {
        console.error('Error updating product quantities and reset time:', error.message);
        res.status(500).send('Error updating product quantities and reset time');
    }
});

exports.resetBusinessResetTime = onRequest(async (req, res) => {
    const profile = req.query.profile;  // Get the profile from the query parameter

    if (!profile) {
        console.error('Missing profile parameter');
        return res.status(400).send('Missing profile parameter');
    }

    // Reference to the business document in the 'businesses' collection
    const businessRef = admin.firestore().collection('businesses').doc(profile);

    try {
        // Update the reset_time field to the current timestamp
        console.log(`Updating reset_time for business: ${profile}`);
        await businessRef.update({
            reset_time: admin.firestore.Timestamp.now()
        });
        console.log('Reset time successfully updated.');

        res.status(200).send('Business reset time successfully updated.');
    } catch (error) {
        console.error('Error updating reset time:', error.message);
        res.status(500).send('Error updating reset time');
    }
});

// One-time migration function to fix paid users stuck in trial status
exports.fixPaidTrialUsers = onRequest(
  {
    cors: ["https://hesabumauzo.co.tz", "https://biashara.hesabumauzo.co.tz"],
    region: "us-central1",
  },
  async (req, res) => {
    // Handle preflight (OPTIONS) request
    if (req.method === "OPTIONS") {
      res.set("Access-Control-Allow-Methods", "GET, POST");
      res.set("Access-Control-Allow-Headers", "Content-Type");
      return res.status(204).send("");
    }

    try {
      console.log('=== Starting Paid Trial Users Migration ===');
      
      const businessesRef = firestore.collection('businesses');
      const snapshot = await businessesRef.get();
      
      if (snapshot.empty) {
        console.log('No businesses found in database');
        return res.status(200).json({
          success: true,
          message: 'No businesses found',
          fixed: 0,
          details: []
        });
      }

      const fixedBusinesses = [];
      const updates = [];
      
      for (const doc of snapshot.docs) {
        const business = doc.data();
        const businessId = doc.id;
        
        // Find businesses with payment data but still on trial status
        if (business.paymentStart && 
            business.paymentLast && 
            business.subscriptionStatus === 'subscription_ontrial') {
          
          console.log(`Found business stuck in trial: ${businessId}`);
          console.log(`- Email: ${business.email || 'N/A'}`);
          console.log(`- Business Name: ${business.name || 'N/A'}`);
          console.log(`- Payment Start: ${business.paymentStart.toDate()}`);
          console.log(`- Payment Last: ${business.paymentLast.toDate()}`);
          
          // Update to subscription_ok and set paid flag
          updates.push(
            doc.ref.update({
              subscriptionStatus: 'subscription_ok',
              paid: true
            })
          );
          
          fixedBusinesses.push({
            businessId: businessId,
            businessName: business.name || 'N/A',
            email: business.email || 'N/A',
            paymentStart: business.paymentStart.toDate().toISOString(),
            paymentLast: business.paymentLast.toDate().toISOString()
          });
        }
      }
      
      // Execute all updates
      if (updates.length > 0) {
        await Promise.all(updates);
        console.log(`Successfully fixed ${updates.length} businesses`);
      } else {
        console.log('No businesses needed fixing');
      }
      
      return res.status(200).json({
        success: true,
        message: `Migration completed. Fixed ${fixedBusinesses.length} businesses.`,
        fixed: fixedBusinesses.length,
        details: fixedBusinesses
      });
      
    } catch (error) {
      console.error('Error in fixPaidTrialUsers:', error);
      return res.status(500).json({
        success: false,
        error: error.message,
        message: 'Migration failed'
      });
    }
  }
);

async function executeLargeBatchWrite(productUpdates) {
  const batchSize = 500;
  const totalUpdates = productUpdates.length;
  for (let i = 0; i < totalUpdates; i += batchSize) {
    const batch = firestore.batch();
    const chunk = productUpdates.slice(i, i + batchSize);
    for (const update of chunk) {
      const { businessId, productId, productData } = update;
      const docRef = firestore
        .collection('products')
        .doc(businessId)
        .collection('userProducts')
        .doc(productId);
      batch.set(docRef, productData, { merge: true });
    }
    await batch.commit();
    console.log(`Batch ${Math.floor(i / batchSize) + 1} committed successfully.`);
  }
}
exports.dailyProductReport = onSchedule(
  { schedule: "every 24 hours" },
  async (context) => {
    try {
      // Fetch only businesses with subscriptionStatus = "subscription_ok"
      const businessesSnapshot = await firestore
        .collection('businesses')
        .where('subscriptionStatus', '==', 'subscription_ok')
        .get();

      const currentReportDate = new Date();

      for (const businessDoc of businessesSnapshot.docs) {
        const businessId = businessDoc.id;

        // Get all products for this business.
        const productsSnapshot = await firestore
          .collection('products')
          .doc(businessId)
          .collection('userProducts')
          .get();

        for (const productDoc of productsSnapshot.docs) {
          const productId = productDoc.id;
          const productData = productDoc.data();

          // Query for the previous day's report for this product.
          const previousReportQuery = await firestore
            .collection('productReports')
            .doc(businessId)
            .collection('userReports')
            .where('productId', '==', productId)
            .orderBy('reportDate', 'desc')
            .limit(1)
            .get();

          let openingQuantity = 0;
          let previousReportTimestamp = new Date(0);
          let breakdown = [];

          if (!previousReportQuery.empty) {
            // If previous report exists, use its final quantity and timestamp
            const previousReport = previousReportQuery.docs[0].data();
            openingQuantity = previousReport.finalQuantity;
            previousReportTimestamp = previousReport.reportDate.toDate();
          } else {
            // No previous report → no breakdown, use product's current quantity as opening quantity
            openingQuantity = productData.quantity || 0;
          }

          // Query all transactions for this product after the last report date
          const txnSnapshot = await firestore
            .collection('transactions')
            .doc(businessId)
            .collection('usersTransactions')
            .where('productId', '==', productId)
            .where('timestamp', '>', admin.firestore.Timestamp.fromDate(previousReportTimestamp))
            .orderBy('timestamp', 'asc')
            .get();

          if (!previousReportQuery.empty) {
            // Only process breakdown if there is a previous report
            let previousTotal = openingQuantity;

            txnSnapshot.forEach(doc => {
              const txn = doc.data();
              let change = txn.quantity - previousTotal;
              let newTotal = txn.quantity;

              breakdown.push({
                timestamp: txn.timestamp,
                transactionOrigin: txn.transactionOrigin,
                transactionType: txn.transactionType,
                change: change,
                previousTotal: previousTotal,
                newTotal: newTotal,
              });

              previousTotal = newTotal;
            });
          }

          // Save the report with Firestore auto-ID
          await firestore
            .collection('productReports')
            .doc(businessId)
            .collection('userReports')
            .add({
              businessId: businessId,
              productId: productId,
              reportDate: admin.firestore.Timestamp.fromDate(currentReportDate),
              openingQuantity: openingQuantity,
              breakdown: breakdown, // Empty if it's the first report
              finalQuantity: openingQuantity, // If no transactions, finalQuantity = openingQuantity
              productName: productData.name || "",
              productCategory: productData.category || "",
              productPrice: productData.price || 0
            });

          console.log(`Report generated for product ${productId} of business ${businessId}`);
        }
      }

      console.log('Daily product reports generated successfully.');
      return null;
    } catch (error) {
      console.error('Error generating daily product reports:', error);
      return null;
    }
  }
);



exports.syncProductsAcrossAllBusinesses = onRequest(async (req, res) => {
  const userId = req.body.userId;
  if (!userId) {
    return res.status(400).send({ error: "userId is required." });
  }
  try {
    // Step 1: Fetch the user's businesses.
    const userDoc = await firestore.collection('gmanusers').doc(userId).get();
    if (!userDoc.exists) {
      return res.status(404).send({ error: "User not found." });
    }
    const userData = userDoc.data();
    const businessList = userData.business || [];
    if (businessList.length === 0) {
      return res.status(400).send({ error: "User is not associated with any businesses." });
    }

    // Step 2: Collect all products across all businesses.
    const allProducts = new Map(); // Map<productId, productData>
    const businessProducts = {};   // Object mapping businessId -> array of product IDs

    for (const businessId of businessList) {
      const productsSnapshot = await firestore
        .collection('products')
        .doc(businessId)
        .collection('userProducts')
        .get();
      const productsInBusiness = [];
      productsSnapshot.forEach(doc => {
        const productData = doc.data();
        const productId = doc.id;
        productsInBusiness.push(productId);
        // Save unique product data if not already stored.
        if (!allProducts.has(productId)) {
          allProducts.set(productId, productData);
        }
      });
      businessProducts[businessId] = productsInBusiness;
    }

    // Step 3: Prepare missing product data for batch writes.
    const batchUpdates = [];
    for (const businessId of businessList) {
      const productsInBusiness = businessProducts[businessId] || [];
      for (const [productId, productData] of allProducts.entries()) {
        if (!productsInBusiness.includes(productId)) {
          // Product missing in this business; prepare an update with quantity 0.
          batchUpdates.push({
            businessId: businessId,
            productId: productId,
            productData: {
              ...productData,
              owner: businessId,
              businessId: businessId,
              quantity: 0,
            }
          });
        }
      }
    }

    // Step 4: Execute batch updates.
    await executeLargeBatchWrite(batchUpdates);
    return res.status(200).send({ success: true, message: "Products synchronized across all businesses." });
  } catch (error) {
    console.error("Error synchronizing products:", error);
    return res.status(500).send({ error: `Error synchronizing products: ${error.message}` });
  }
});


exports.saveProductToUserStore = onRequest(async (req, res) => {
  const origin = req.headers.origin;
  const allowedOrigins = [
    "https://hesabumauzo.co.tz",
    "https://biashara.hesabumauzo.co.tz",
    "http://localhost:5000",
    "http://localhost:8080",
    "http://localhost:5173"
  ];
  if (origin && allowedOrigins.includes(origin)) {
    res.set("Access-Control-Allow-Origin", origin);
  }
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }
  const {
    id,
    storeId,
    businessId,
    manufacturer,
    name,
    details,
    location,
    buyingPrice,
    understock,
    code,
    price,
    quantity,
    category,
    imageUrl,
    expireDate, // New field
    reserveString1,
    reserveString2,
    reserveDouble1,
    reserveDouble2,
    reserveList1,
    reserveList2,
  } = req.body;

  // Ensure required fields are present
  if (!id || !storeId || !businessId || !name || !buyingPrice || !price) {
    return res.status(400).send({
      error: "id, storeId, businessId, name, buyingPrice, and price are required fields.",
    });
  }

  try {
    // Parse expireDate as Firestore Timestamp if provided
    let parsedExpireDate = null;
    if (expireDate) {
      parsedExpireDate = new Date(expireDate); // Convert string to Date
      if (isNaN(parsedExpireDate)) {
        return res.status(400).send({ error: "Invalid expireDate format." });
      }
    }

    // Create a reference to the product document within the specific store using the provided id
    const productRef = admin
      .firestore()
      .collection("store")
      .doc(storeId)
      .collection("userStore")
      .doc(id); // Use the provided id for the product document

    // Prepare product data with storeId included
    const productData = {
      id: id,
      storeId: storeId, // Include the storeId field in product data
      owner: businessId,
      businessId: businessId,
      manufacturer: manufacturer || "",
      name: name,
      details: details || "",
      location: location || "",
      buyingPrice: buyingPrice,
      understock: parseInt(understock || "10", 10),
      code: code || "",
      price: price,
      quantity: 0, // FIXED: Store should start with zero quantity
      total: 0, // FIXED: Store should start with zero total
      category: category || "",
      image: imageUrl || "",
      expireDate: parsedExpireDate ? admin.firestore.Timestamp.fromDate(parsedExpireDate) : null, // Save as Firestore Timestamp

      // New fields with default values
      storeQuantity: 0, // Default store quantity set to 0
      reserveString1: reserveString1 || "", // Default empty string for reserveString1
      reserveString2: reserveString2 || "", // Default empty string for reserveString2
      reserveDouble1: reserveDouble1 || 0.0, // Default value for reserveDouble1
      reserveDouble2: reserveDouble2 || 0.0, // Default value for reserveDouble2
      reserveList1: reserveList1 || [], // Default empty list for reserveList1
      reserveList2: reserveList2 || [], // Default empty list for reserveList2
    };

    // Save product data to Firestore
    await productRef.set(productData);

    return res.status(200).send({
      success: true,
      message: "Product saved to userStore within store collection.",
      data: productData,
    });
  } catch (error) {
    console.error("Error saving product to userStore:", error);
    return res.status(500).send({ error: `Failed to save product: ${error.message}` });
  }
});



// Localization messages (English and Swahili)
const messages = {
  en: {
    welcome: (name, business) => `Hi ${name || 'there'}! Welcome to ${business} 🎉\nPlease select an option by replying with the number:\n1. Get Product Price\n2. Add to Cart\n3. List Products\n4. Show Cart\n5. Help`,
    selectBusiness: 'Multiple businesses found. Please select one by replying with the number:\n',
    noBusiness: 'Sorry, no registered businesses found for this number.',
    productNotFound: (productName, suggestions) => `Sorry, we couldn't find the product: ${productName}\n${suggestions}\n\nReply with:\n0. Go Back`,
    productDetails: (product) => `Product: ${product.name}\nPrice: ${product.price} TZS\nDescription: ${product.details || 'No description available'}\nReply with:\n1. Add to Cart\n2. Give Feedback\n0. Go Back`,
    addedToCart: (productName) => `${productName} has been added to your cart! ✅\nReply "4" to view your cart.`,
    cartEmpty: 'Your cart is empty.\nReply with:\n0. Go Back',
    cartDetails: (items, total) => `Your Cart:\n\n${items}\nTotal: ${total} TZS\nReply with:\n1. Checkout\n2. Clear Cart\n0. Go Back`,
    noProducts: 'No products available at the moment.\nReply with:\n0. Go Back',
    productList: 'Available Products:\n\n',
    help: (business) => `I'm here to help you with ${business}!\nReply with the number:\n1. Check product prices\n2. Add items to your cart\n3. List available products\n4. View your cart\n0. Go Back`,
    error: (suggestions) => `Sorry, I didn't understand that. Did you mean: ${suggestions.join(' or ')}?\nReply with:\n5. Help\n0. Go Back`,
    enterProductName: 'Please enter the product name (e.g., "iPhone").\nReply with:\n0. Go Back',
    feedbackPrompt: 'How was your experience with this product?\nReply with:\n1. Satisfied\n2. Not Satisfied\n0. Go Back',
    feedbackSuccess: 'Thank you for your feedback! ✅',
    checkoutPrompt: 'Would you like to proceed to checkout?\nReply with:\n1. Yes\n2. No\n0. Go Back',
    checkoutSuccess: 'Thank you for your purchase! Your order has been placed successfully. ✅',
    checkoutFailed: 'Sorry, there was an error processing your payment. Please try again.\nReply with:\n0. Go Back',
    errorProcessing: 'Sorry, there was an error processing your request. Please try again.\nReply with:\n0. Go Back',
    imageSendingFailed: 'Here are the product details (image unavailable):\n',
    sessionExpired: 'Your session has expired due to inactivity. Lets start over!\nReply with:\n1. Get Product Price\n2. Add to Cart\n3. List Products\n4. Show Cart\n5. Help',
  },
  sw: {
    welcome: (name, business) => `Habari ${name || 'yako'}! Karibu ${business} 🎉\nTafadhali chagua kwa kujibu na nambari:\n1. Pata Bei ya Bidhaa\n2. Ongeza kwenye Kikapu\n3. Orodhesha Bidhaa\n4. Angalia Kikapu\n5. Msaada`,
    selectBusiness: 'Biashara nyingi zimepatikana. Tafadhali chagua moja kwa kujibu na nambari:\n',
    noBusiness: 'Samahani, hakuna Biashara zilizosajiliwa kwa namba hii.',
    productNotFound: (productName, suggestions) => `Samahani, hatukuweza kupata bidhaa: ${productName}\n${suggestions}\n\nJibu na:\n0. Rudi Nyuma`,
    productDetails: (product) => `Bidhaa: ${product.name}\nBei: ${product.price} TZS\nMaelezo: ${product.details || 'Hakuna maelezo yanayopatikana'}\nJibu na:\n1. Ongeza kwenye Kikapu\n2. Toa Maoni\n0. Rudi Nyuma`,
    addedToCart: (productName) => `${productName} imeongezwa kwenye kikapu chako! ✅\nJibu "4" kuona kikapu chako.`,
    cartEmpty: 'Kikapu chako ni tupu.\nJibu na:\n0. Rudi Nyuma',
    cartDetails: (items, total) => `Kikapu Chako:\n\n${items}\nJumla: ${total} TZS\nJibu na:\n1. Maliza Ununuzi\n2. Futa Kikapu\n0. Rudi Nyuma`,
    noProducts: 'Hakuna bidhaa zinazopatikana kwa sasa.\nJibu na:\n0. Rudi Nyuma',
    help: (business) => `Niko hapa kukusaidia na ${business}!\nJibu na nambari:\n1. Angalia bei za bidhaa\n2. Ongeza bidhaa kwenye kikapu\n3. Orodhesha bidhaa zinazopatikana\n4. Angalia kikapu chako\n0. Rudi Nyuma`,
    error: (suggestions) => `Samahani, sikuweza kuelewa. Ulimaanisha: ${suggestions.join(' au ')}?\nJibu na:\n5. Msaada\n0. Rudi Nyuma`,
    enterProductName: 'Tafadhali andika jina la bidhaa (k.m., "iPhone").\nJibu na:\n0. Rudi Nyuma',
    feedbackPrompt: 'Uzoefu wako na bidhaa hii ulikuwaje?\nJibu na:\n1. Nimeridhika\n2. Sijaridhika\n0. Rudi Nyuma',
    feedbackSuccess: 'Asante kwa maoni yako! ✅',
    checkoutPrompt: 'Je, ungependa kuendelea na malipo?\nJibu na:\n1. Ndio\n2. Hapana\n0. Rudi Nyuma',
    checkoutSuccess: 'Asante kwa ununuzi wako! Agizo lako limefanikiwa. ✅',
    checkoutFailed: 'Samahani, kulikuwa na hitilafu wakati wa kulipia. Tafadhali jaribu tena.\nJibu na:\n0. Rudi Nyuma',
    errorProcessing: 'Samahani, kulikuwa na hitilafu katika kuchakata ombi lako. Tafadhali jaribu tena.\nJibu na:\n0. Rudi Nyuma',
    imageSendingFailed: 'Hapa kuna maelezo ya bidhaa (picha haipatikani):\n',
    sessionExpired: 'Muda wako umeisha kwa sababu ya kutokuwa na shughuli. Anza tena!\nJibu na:\n1. Pata Bei ya Bidhaa\n2. Ongeza kwenye Kikapu\n3. Orodhesha Bidhaa\n4. Angalia Kikapu\n5. Msaada',
  }
};

// Session timeout (10 minutes = 600,000 milliseconds)
const SESSION_TIMEOUT_MS = 600000;

// WhatsApp message handler
exports.handleWhatsAppMessage = onRequest(
  {
    cors: ["https://hesabumauzo.co.tz", "https://biashara.hesabumauzo.co.tz"],
    maxInstances: 10,
    timeoutSeconds: 60,
    memory: "256MiB"
  },
  async (req, res) => {
    console.log('Received WhatsApp message:', req.body);

    // Validate Twilio signature
    const twilioSignature = req.headers['x-twilio-signature'];
    const url = req.protocol + '://' + req.get('host') + req.originalUrl;
    const params = req.body;
    const isValidRequest = twilio.validateRequest(authToken, twilioSignature, url, params);

    //if (!isValidRequest) {
     // console.error('Invalid Twilio request');
     // return res.status(403).send('Invalid request');
   // }

    const { Body, From, ProfileName } = req.body;
    const customerPhone = From.replace('whatsapp:', '');
    const businessPhone = req.body.To?.replace('whatsapp:', '') || '';

    try {
      // Validate required fields
      if (!Body || !From || !req.body.To) {
        console.error('Missing required fields');
        throw new Error('Missing required fields');
      }

      // Get or initialize user state
      const userStateRef = admin.firestore().collection('userStates').doc(customerPhone);
      const userStateDoc = await userStateRef.get();
      let userState = userStateDoc.exists ? userStateDoc.data() : {
        lastInteraction: null,
        step: 'initial',
        language: 'en',
        cart: [],
        businessId: null
      };
      const lang = userState.language || 'en';

      // Handle session timeout
      if (userState.lastInteraction) {
        const lastInteractionTime = userState.lastInteraction.toMillis();
        const currentTime = Date.now();
        if (currentTime - lastInteractionTime > SESSION_TIMEOUT_MS) {
          if (Body.trim() !== '' && !['0','9'].includes(Body.trim())) {
            // User is responding to something - process their message normally
            console.log('Processing message after timeout');
          } else {
            await userStateRef.set({
              step: 'main_menu',
              language: lang,
              lastInteraction: admin.firestore.Timestamp.now()
            }, { merge: true });
            await sendWhatsAppMessage(From, messages[lang].sessionExpired);
            return res.status(200).send('OK');
          }
        }
      }

      // Find businesses associated with this number
      const businessesSnapshot = await admin.firestore()
        .collection('businesses')
        .where('phone', '==', businessPhone)
        .get();

      if (businessesSnapshot.empty) {
        await sendWhatsAppMessage(From, messages[lang].noBusiness);
        return res.status(200).send('OK');
      }

      // Business selection logic
      let selectedBusiness = null;
      let remainingMessage = Body.toLowerCase().trim();

      // Check for explicit business name in message
      for (const doc of businessesSnapshot.docs) {
        const business = doc.data();
        if (remainingMessage.startsWith(business.name.toLowerCase())) {
          selectedBusiness = { id: doc.id, data: business };
          remainingMessage = remainingMessage.slice(business.name.length).trim();
          break;
        }
      }

      // Handle multiple businesses
      if (!selectedBusiness && businessesSnapshot.size > 1) {
        if (userState.step === 'select_business' && /^\d+$/.test(remainingMessage)) {
          const businessIndex = parseInt(remainingMessage) - 1;
          if (businessIndex >= 0 && businessIndex < businessesSnapshot.docs.length) {
            selectedBusiness = {
              id: businessesSnapshot.docs[businessIndex].id,
              data: businessesSnapshot.docs[businessIndex].data()
            };
            remainingMessage = '';
          } else {
            await sendWhatsAppMessage(From, messages[lang].error(['select a valid number']));
            return res.status(200).send('OK');
          }
        } else {
          let businessList = messages[lang].selectBusiness;
          businessesSnapshot.forEach((doc, index) => {
            businessList += `${index + 1}. ${doc.data().name}\n`;
          });
          businessList += '\n0️⃣ Go Back\n9️⃣ Restart';
          await sendWhatsAppMessage(From, businessList);
          await userStateRef.set({
            step: 'select_business',
            lastInteraction: admin.firestore.Timestamp.now(),
            language: lang
          }, { merge: true });
          return res.status(200).send('OK');
        }
      } else if (!selectedBusiness && businessesSnapshot.size === 1) {
        selectedBusiness = {
          id: businessesSnapshot.docs[0].id,
          data: businessesSnapshot.docs[0].data()
        };
      }

      // Update user state with selected business
      if (selectedBusiness && userState.businessId !== selectedBusiness.id) {
        await userStateRef.update({ businessId: selectedBusiness.id });
        userState.businessId = selectedBusiness.id;
      }

      // Main state machine
      switch (userState.step) {
        case 'initial':
        case 'main_menu':
          await handleMainMenu(remainingMessage, selectedBusiness, From, ProfileName, userStateRef, lang);
          break;

        case 'awaiting_product_name':
          await handleProductNameInput(remainingMessage, userState, selectedBusiness, From, customerPhone, userStateRef, lang);
          break;

        case 'awaiting_product_selection':
          await handleProductSelection(remainingMessage, selectedBusiness, From, userStateRef, lang);
          break;

        case 'awaiting_product_details':
          await handleProductDetails(remainingMessage, userState, selectedBusiness, From, customerPhone, userStateRef, lang);
          break;

        case 'awaiting_cart_action':
          await handleCartAction(remainingMessage, selectedBusiness, From, customerPhone, userStateRef, lang);
          break;

        case 'awaiting_checkout_confirmation':
          await handleCheckoutConfirmation(remainingMessage, selectedBusiness, From, customerPhone, userStateRef, lang);
          break;

        case 'checkout_complete':
          await handlePostCheckout(remainingMessage, selectedBusiness, From, customerPhone, userStateRef, lang);
          break;

        case 'awaiting_feedback':
          await handleFeedbackInput(remainingMessage, selectedBusiness, From, customerPhone, userStateRef, lang);
          break;

        default:
          await sendWhatsAppMessage(From, messages[lang].errorProcessing);
          await userStateRef.set({ step: 'initial' }, { merge: true });
      }

      res.status(200).send('OK');
    } catch (error) {
      console.error('Error processing message:', error);
      await sendWhatsAppMessage(From, `⚠️ Error: ${error.message}\n\n9️⃣ Restart`);
      res.status(500).send('Error');
    }
  }
);

// ==================== SUPPORTING FUNCTIONS ====================

async function handleMainMenu(message, business, from, profileName, userStateRef, lang) {
  if (message === '0' || message === '9') {
    await userStateRef.set({
      step: 'initial',
      lastInteraction: admin.firestore.Timestamp.now()
    }, { merge: true });
    await sendWhatsAppMessage(from, messages[lang].welcome(profileName, business.data.name));
    return;
  }

  const options = {
    '1': async () => {
      await sendWhatsAppMessage(from, messages[lang].enterProductName);
      await userStateRef.set({
        step: 'awaiting_product_name',
        action: 'get_price',
        lastInteraction: admin.firestore.Timestamp.now()
      }, { merge: true });
    },
    '2': async () => {
      await sendWhatsAppMessage(from, messages[lang].enterProductName);
      await userStateRef.set({
        step: 'awaiting_product_name',
        action: 'add_to_cart',
        lastInteraction: admin.firestore.Timestamp.now()
      }, { merge: true });
    },
    '3': async () => {
      await handleProductListRequest(business.id, from, lang);
      await userStateRef.set({
        step: 'awaiting_product_selection',
        lastInteraction: admin.firestore.Timestamp.now()
      }, { merge: true });
    },
    '4': async () => {
      await handleCartOperation(null, 'show', business.id, from.replace('whatsapp:', ''), from, lang);
      await userStateRef.set({
        step: 'awaiting_cart_action',
        lastInteraction: admin.firestore.Timestamp.now()
      }, { merge: true });
    },
    '5': async () => {
      await handleHelpRequest(from, business.data.name, lang);
      await userStateRef.set({
        step: 'main_menu',
        lastInteraction: admin.firestore.Timestamp.now()
      }, { merge: true });
    }
  };

  if (options[message]) {
    await options[message]();
  } else {
    const suggestions = suggestCommand(message);
    await sendWhatsAppMessage(from, messages[lang].error(suggestions));
    await userStateRef.set({
      step: 'main_menu',
      lastInteraction: admin.firestore.Timestamp.now()
    }, { merge: true });
  }
}

async function handleProductNameInput(message, userState, business, from, customerPhone, userStateRef, lang) {
  if (message === '0') {
    await userStateRef.set({
      step: 'main_menu',
      lastInteraction: admin.firestore.Timestamp.now()
    }, { merge: true });
    await sendWhatsAppMessage(from, messages[lang].welcome(null, business.data.name));
    return;
  }

  if (message === '9') {
    await userStateRef.set({
      step: 'initial',
      lastInteraction: admin.firestore.Timestamp.now()
    }, { merge: true });
    await sendWhatsAppMessage(from, messages[lang].welcome(null, business.data.name));
    return;
  }

  if (!message) {
    await sendWhatsAppMessage(from, messages[lang].enterProductName);
    return;
  }

  if (userState.action === 'get_price') {
    await handleProductPriceQuery(message, business.id, from, lang);
  } else if (userState.action === 'add_to_cart') {
    await handleCartOperation(message, 'add', business.id, customerPhone, from, lang);
  }

  await userStateRef.set({
    step: 'main_menu',
    lastInteraction: admin.firestore.Timestamp.now()
  }, { merge: true });
}

async function handleProductSelection(message, business, from, userStateRef, lang) {
  if (message === '0') {
    await userStateRef.set({
      step: 'main_menu',
      lastInteraction: admin.firestore.Timestamp.now()
    }, { merge: true });
    await sendWhatsAppMessage(from, messages[lang].welcome(null, business.data.name));
    return;
  }

  if (message === '9') {
    await userStateRef.set({
      step: 'initial',
      lastInteraction: admin.firestore.Timestamp.now()
    }, { merge: true });
    await sendWhatsAppMessage(from, messages[lang].welcome(null, business.data.name));
    return;
  }

  if (/^\d+$/.test(message)) {
    const productIndex = parseInt(message) - 1;
    const productsSnapshot = await admin.firestore()
      .collection('products')
      .doc(business.id)
      .collection('userProducts')
      .orderBy('name', 'asc')
      .limit(5)
      .get();

    const productDocs = productsSnapshot.docs;
    if (productIndex >= 0 && productIndex < productDocs.length) {
      const product = productDocs[productIndex].data();
      const message = messages[lang].productDetails(product);

      if (product.image) {
        await sendMediaMessage(from, product.image, message);
      } else {
        await sendWhatsAppMessage(from, message);
      }

      await userStateRef.set({
        step: 'awaiting_product_details',
        lastProduct: product.name,
        lastInteraction: admin.firestore.Timestamp.now()
      }, { merge: true });
    } else {
      await sendWhatsAppMessage(from, messages[lang].error(['select a valid number']));
    }
  } else {
    await sendWhatsAppMessage(from, messages[lang].error(['select a valid number']));
  }
}

async function handleProductDetails(message, userState, business, from, customerPhone, userStateRef, lang) {
  if (message === '0') {
    await handleProductListRequest(business.id, from, lang);
    await userStateRef.set({
      step: 'awaiting_product_selection',
      lastInteraction: admin.firestore.Timestamp.now()
    }, { merge: true });
    return;
  }

  if (message === '9') {
    await userStateRef.set({
      step: 'initial',
      lastInteraction: admin.firestore.Timestamp.now()
    }, { merge: true });
    await sendWhatsAppMessage(from, messages[lang].welcome(null, business.data.name));
    return;
  }

  if (message === '1') {
    await handleCartOperation(userState.lastProduct, 'add', business.id, customerPhone, from, lang);
    await userStateRef.set({
      step: 'main_menu',
      lastInteraction: admin.firestore.Timestamp.now()
    }, { merge: true });
  } else if (message === '2') {
    await sendWhatsAppMessage(from, messages[lang].feedbackPrompt);
    await userStateRef.set({
      step: 'awaiting_feedback',
      lastInteraction: admin.firestore.Timestamp.now()
    }, { merge: true });
  } else {
    await sendWhatsAppMessage(from, messages[lang].error(['select a valid option']));
  }
}

async function handleCartAction(message, business, from, customerPhone, userStateRef, lang) {
  if (message === '0') {
    await userStateRef.set({
      step: 'main_menu',
      lastInteraction: admin.firestore.Timestamp.now()
    }, { merge: true });
    await sendWhatsAppMessage(from, messages[lang].welcome(null, business.data.name));
    return;
  }

  if (message === '9') {
    await userStateRef.set({
      step: 'initial',
      lastInteraction: admin.firestore.Timestamp.now()
    }, { merge: true });
    await sendWhatsAppMessage(from, messages[lang].welcome(null, business.data.name));
    return;
  }

  if (message === '1') {
    await sendWhatsAppMessage(from, messages[lang].checkoutPrompt);
    await userStateRef.set({
      step: 'awaiting_checkout_confirmation',
      lastInteraction: admin.firestore.Timestamp.now()
    }, { merge: true });
  } else if (message === '2') {
    await handleCartOperation(null, 'clear', business.id, customerPhone, from, lang);
    await userStateRef.set({
      step: 'main_menu',
      lastInteraction: admin.firestore.Timestamp.now()
    }, { merge: true });
  } else {
    await sendWhatsAppMessage(from, messages[lang].error(['select a valid option']));
  }
}

async function handleCheckoutConfirmation(message, business, from, customerPhone, userStateRef, lang) {
  if (message === '0') {
    await handleCartOperation(null, 'show', business.id, customerPhone, from, lang);
    await userStateRef.set({
      step: 'awaiting_cart_action',
      lastInteraction: admin.firestore.Timestamp.now()
    }, { merge: true });
    return;
  }

  if (message === '9') {
    await userStateRef.set({
      step: 'initial',
      lastInteraction: admin.firestore.Timestamp.now()
    }, { merge: true });
    await sendWhatsAppMessage(from, messages[lang].welcome(null, business.data.name));
    return;
  }

  if (message === '1') {
    try {
      // In a real implementation, you would process payment here
      // This is a mock implementation
      await handleCheckout(business.id, customerPhone, from, lang);
      await userStateRef.set({
        step: 'checkout_complete',
        lastInteraction: admin.firestore.Timestamp.now()
      }, { merge: true });
    } catch (error) {
      await sendWhatsAppMessage(from, messages[lang].checkoutFailed);
      await userStateRef.set({
        step: 'awaiting_cart_action',
        lastInteraction: admin.firestore.Timestamp.now()
      }, { merge: true });
    }
  } else if (message === '2') {
    await userStateRef.set({
      step: 'awaiting_cart_action',
      lastInteraction: admin.firestore.Timestamp.now()
    }, { merge: true });
    await sendWhatsAppMessage(from, messages[lang].checkoutCancelled);
  } else {
    await sendWhatsAppMessage(from, messages[lang].error(['select a valid option']));
  }
}

async function handlePostCheckout(message, business, from, customerPhone, userStateRef, lang) {
  if (message === '0') {
    await userStateRef.set({
      step: 'main_menu',
      lastInteraction: admin.firestore.Timestamp.now()
    }, { merge: true });
    await sendWhatsAppMessage(from, messages[lang].welcome(null, business.data.name));
    return;
  }

  if (message === '9') {
    await userStateRef.set({
      step: 'initial',
      lastInteraction: admin.firestore.Timestamp.now()
    }, { merge: true });
    await sendWhatsAppMessage(from, messages[lang].welcome(null, business.data.name));
    return;
  }

  if (message === '1') {
    await userStateRef.set({
      step: 'main_menu',
      lastInteraction: admin.firestore.Timestamp.now()
    }, { merge: true });
    await sendWhatsAppMessage(from, messages[lang].welcome(null, business.data.name));
  } else if (message === '2') {
    await handleViewReceipt(business.id, customerPhone, from, lang);
  } else {
    await sendWhatsAppMessage(from, messages[lang].error(['select a valid option']));
  }
}

async function handleFeedbackInput(message, business, from, customerPhone, userStateRef, lang) {
  if (message === '0') {
    await userStateRef.set({
      step: 'main_menu',
      lastInteraction: admin.firestore.Timestamp.now()
    }, { merge: true });
    await sendWhatsAppMessage(from, messages[lang].welcome(null, business.data.name));
    return;
  }

  if (message === '9') {
    await userStateRef.set({
      step: 'initial',
      lastInteraction: admin.firestore.Timestamp.now()
    }, { merge: true });
    await sendWhatsAppMessage(from, messages[lang].welcome(null, business.data.name));
    return;
  }

  if (message.match(/^[1-2]$/)) {
    await handleFeedback(message, customerPhone, business.id, from, lang);
    await userStateRef.set({
      step: 'main_menu',
      lastInteraction: admin.firestore.Timestamp.now()
    }, { merge: true });
  } else {
    await sendWhatsAppMessage(from, messages[lang].error(['select a valid option']));
  }
}

// ==================== HELPER FUNCTIONS ====================

async function sendWhatsAppMessage(to, message) {
  try {
    console.log('Sending message to:', to);
    await client.messages.create({
      body: message,
      from: 'whatsapp:+14155238886',
      to: to
    });
    await new Promise(resolve => setTimeout(resolve, 1000)); // Rate limiting
  } catch (error) {
    console.error('Error sending message:', error);
    throw error;
  }
}

async function sendMediaMessage(to, mediaUrl, caption) {
  try {
    await client.messages.create({
      body: caption,
      from: 'whatsapp:+14155238886',
      to: to,
      mediaUrl: [mediaUrl]
    });
    await new Promise(resolve => setTimeout(resolve, 1000)); // Rate limiting
  } catch (error) {
    console.error('Error sending media:', error);
    await sendWhatsAppMessage(to, messages[lang].imageSendingFailed + caption);
  }
}

async function handleProductPriceQuery(productName, businessId, customerPhone, lang) {
  const productsSnapshot = await admin.firestore()
    .collection('products')
    .doc(businessId)
    .collection('userProducts')
    .orderBy('name', 'asc')
    .get();

  const matchingProduct = productsSnapshot.docs.find(doc =>
    doc.data().name?.toLowerCase().includes(productName.toLowerCase())
  );

  if (!matchingProduct) {
    const suggestions = productsSnapshot.docs
      .map(doc => doc.data().name)
      .filter(name => name.toLowerCase().startsWith(productName.toLowerCase().charAt(0)))
      .slice(0, 3);
    const suggestionMessage = suggestions.length > 0
      ? `Did you mean one of these? ${suggestions.join(', ')}`
      : 'No similar products found.';
    await sendWhatsAppMessage(customerPhone, messages[lang].productNotFound(productName, suggestionMessage));
    return;
  }

  const product = matchingProduct.data();
  const message = messages[lang].productDetails(product);
  if (product.image) {
    await sendMediaMessage(customerPhone, product.image, message);
  } else {
    await sendWhatsAppMessage(customerPhone, message);
  }
}

async function handleCartOperation(productName, action, businessId, customerPhone, from, lang) {
  const cartRef = admin.firestore()
    .collection('carts')
    .doc(businessId)
    .collection('userCarts')
    .doc(customerPhone);

  if (action === 'add') {
    const productSnapshot = await admin.firestore()
      .collection('products')
      .doc(businessId)
      .collection('userProducts')
      .get();

    const matchingProduct = productSnapshot.docs.find(doc =>
      doc.data().name?.toLowerCase().includes(productName.toLowerCase())
    );

    if (!matchingProduct) {
      const suggestions = productSnapshot.docs
        .map(doc => doc.data().name)
        .filter(name => name.toLowerCase().startsWith(productName.toLowerCase().charAt(0)))
        .slice(0, 3);
      const suggestionMessage = suggestions.length > 0
        ? `Did you mean one of these? ${suggestions.join(', ')}`
        : 'No similar products found.';
      await sendWhatsAppMessage(from, messages[lang].productNotFound(productName, suggestionMessage));
      return;
    }

    const product = matchingProduct.data();
    const cartDoc = await cartRef.get();

    if (!cartDoc.exists) {
      await cartRef.set({
        items: [{
          productId: matchingProduct.id,
          name: product.name,
          price: product.price,
          quantity: 1
        }],
        total: product.price,
        updatedAt: admin.firestore.Timestamp.now()
      });
    } else {
      const cart = cartDoc.data();
      const existingItem = cart.items.find(item => item.productId === matchingProduct.id);

      if (existingItem) {
        existingItem.quantity += 1;
      } else {
        cart.items.push({
          productId: matchingProduct.id,
          name: product.name,
          price: product.price,
          quantity: 1
        });
      }

      cart.total = cart.items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
      cart.updatedAt = admin.firestore.Timestamp.now();

      await cartRef.update(cart);
    }

    await sendWhatsAppMessage(from, messages[lang].addedToCart(product.name));
  } else if (action === 'show') {
    const cartDoc = await cartRef.get();

    if (!cartDoc.exists || !cartDoc.data().items?.length) {
      await sendWhatsAppMessage(from, messages[lang].cartEmpty);
      return;
    }

    const cart = cartDoc.data();
    const items = cart.items.map(item =>
      `➡️ ${item.name} x${item.quantity} - ${item.price * item.quantity} TZS`
    ).join('\n');

    const message = `🛒 *Your Cart*\n\n${items}\n\n💵 *Total: ${cart.total} TZS*\n\n1️⃣ Checkout\n2️⃣ Clear Cart\n0️⃣ Go Back\n9️⃣ Restart`;
    await sendWhatsAppMessage(from, message);
  } else if (action === 'clear') {
    await cartRef.delete();
    await sendWhatsAppMessage(from, lang === 'en' ? '🛒 Your cart has been cleared.' : '🛒 Kikapu chako kimefutwa.');
  }
}

async function handleProductListRequest(businessId, customerPhone, lang) {
  const productsSnapshot = await admin.firestore()
    .collection('products')
    .doc(businessId)
    .collection('userProducts')
    .orderBy('name', 'asc')
    .limit(5)
    .get();

  if (productsSnapshot.empty) {
    await sendWhatsAppMessage(customerPhone, messages[lang].noProducts);
    return;
  }

  let message = messages[lang].productList;
  productsSnapshot.forEach((doc, index) => {
    const product = doc.data();
    message += `${index + 1}. ${product.name} - ${product.price} TZS${product.image ? ' 📷' : ''}\n`;
  });
  message += '\nReply with the number to get details:\n0️⃣ Go Back\n9️⃣ Restart';
  await sendWhatsAppMessage(customerPhone, message);
}

async function handleCheckout(businessId, customerPhone, from, lang) {
  const cartRef = admin.firestore()
    .collection('carts')
    .doc(businessId)
    .collection('userCarts')
    .doc(customerPhone);

  const cartDoc = await cartRef.get();
  if (!cartDoc.exists || !cartDoc.data().items?.length) {
    await sendWhatsAppMessage(from, messages[lang].cartEmpty);
    return;
  }

  const cart = cartDoc.data();
  const total = cart.total;

  try {
    // In a real implementation, you would process payment here
    // This is a mock implementation
    await admin.firestore()
      .collection('sales')
      .doc(businessId)
      .collection('userSales')
      .add({
        customerPhone,
        items: cart.items,
        total,
        date: admin.firestore.Timestamp.now(),
        status: 'completed'
      });

    await cartRef.delete();
    await sendWhatsAppMessage(from, messages[lang].checkoutSuccess);
  } catch (error) {
    console.error('Checkout error:', error);
    await sendWhatsAppMessage(from, messages[lang].checkoutFailed);
    throw error;
  }
}

async function handleFeedback(message, customerPhone, businessId, from, lang) {
  const feedback = message === '1' ? 'Satisfied' : 'Not Satisfied';
  await admin.firestore()
    .collection('feedback')
    .doc(businessId)
    .collection('userFeedback')
    .add({
      customerPhone,
      feedback,
      timestamp: admin.firestore.Timestamp.now()
    });

  await sendWhatsAppMessage(from, messages[lang].feedbackSuccess);
}

async function handleViewReceipt(businessId, customerPhone, from, lang) {
  const salesSnapshot = await admin.firestore()
    .collection('sales')
    .doc(businessId)
    .collection('userSales')
    .where('customerPhone', '==', customerPhone)
    .orderBy('date', 'desc')
    .limit(1)
    .get();

  if (salesSnapshot.empty) {
    await sendWhatsAppMessage(from, messages[lang].errorProcessing);
    return;
  }

  const sale = salesSnapshot.docs[0].data();
  const items = sale.items.map(item =>
    `➡️ ${item.name} x${item.quantity} - ${item.price * item.quantity} TZS`
  ).join('\n');

  const receiptMessage = `📋 *Your Receipt*\n\n${items}\n\n💵 *Total: ${sale.total} TZS*\n\n1️⃣ New Order\n0️⃣ Go Back\n9️⃣ Restart`;
  await sendWhatsAppMessage(from, receiptMessage);
}

async function handleHelpRequest(customerPhone, businessName, lang) {
  await sendWhatsAppMessage(customerPhone, messages[lang].help(businessName));
}

function suggestCommand(message) {
  const commands = ['price of', 'add to cart', 'list products', 'show cart', 'help'];
  return commands.filter(cmd => cmd.includes(message.split(' ')[0])).slice(0, 2);
}

exports.acceptTransferRequestV2 = onCall({ region: "us-central1" }, async (request) => {
  const context = request.auth;
  if (!context) {
    throw new HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { fromBusinessId, toBusinessId, productId, transferRequestId, quantity } = request.data;
  if (!fromBusinessId || !toBusinessId || !productId || !transferRequestId || !quantity) {
    throw new HttpsError('invalid-argument', 'Missing required fields');
  }

  try {
    // 1. Update transfer request status to 'accepted' in the receiver's business
    await firestore
      .collection('product_transfer_requests').doc(toBusinessId)
      .collection('userTransferRequests').doc(transferRequestId)
      .update({ status: 'accepted', respondedAt: admin.firestore.FieldValue.serverTimestamp() });

    // Declare variables to capture data from transactions
    let fromProductData = null;
    let fromQty = 0;
    let toQty = 0;

    // 2. Update product stock in sender (fromBusinessId): decrement quantity
    const fromProductRef = firestore
      .collection('products').doc(fromBusinessId)
      .collection('userProducts').doc(productId);
    await firestore.runTransaction(async (transaction) => {
      const fromProductSnap = await transaction.get(fromProductRef);
      if (!fromProductSnap.exists) {
        throw new HttpsError('not-found', 'Product not found in sender business');
      }
      fromProductData = fromProductSnap.data();
      fromQty = fromProductData.quantity || 0;
      if (fromQty < quantity) {
        throw new HttpsError('failed-precondition', 'Not enough stock in sender business');
      }
      transaction.update(fromProductRef, { quantity: fromQty - quantity });
    });

    // 3. Update product stock in receiver (toBusinessId): increment quantity
    const toProductRef = firestore
      .collection('products').doc(toBusinessId)
      .collection('userProducts').doc(productId);
    await firestore.runTransaction(async (transaction) => {
      const toProductSnap = await transaction.get(toProductRef);
      if (!toProductSnap.exists) {
        // Product doesn't exist in destination - use the source product data we already have
        if (fromProductData) {
          const newProductData = {
            ...fromProductData,
            quantity: quantity,
            owner: toBusinessId,
            id: productId
          };
          transaction.set(toProductRef, newProductData);
          console.log(`Created new product ${fromProductData.name} in destination with quantity: ${quantity}`);
        } else {
          // Fallback: create minimal product data (should rarely happen)
          const minimalProductData = {
            id: productId,
            name: 'Unknown Product',
            quantity: quantity,
            owner: toBusinessId,
            itemType: 'product',
            price: 0.0,
            buyingPrice: 0.0,
            storeId: '',
            code: '',
            discount: 0.0,
            manufacturer: '',
            location: '',
            details: '',
            understock: 0.0,
            category: '',
            total: 0.0,
            count: 0.0
          };
          transaction.set(toProductRef, minimalProductData);
          console.log(`Created minimal product ${productId} in destination`);
        }
        toQty = 0; // New product, so previous quantity is 0
      } else {
        // Product exists in destination - increment quantity
        toQty = toProductSnap.data().quantity || 0;
        transaction.update(toProductRef, { quantity: toQty + quantity });
        console.log(`Increased product in destination: ${toQty} -> ${toQty + quantity}`);
      }
    });

    // 4. Record transaction in sender business (removal)
    const sourceTransactionRef = firestore
      .collection('transactions')
      .doc(fromBusinessId)
      .collection('usersTransactions')
      .doc();

    const sourceTransaction = {
      transactionId: sourceTransactionRef.id,
      productId: productId,
      quantity: fromQty - quantity, // New quantity after removal
      previousQuantity: fromQty,
      transactionType: 'removal',
      transactionOrigin: 'Product Transfer Out',
      timestamp: admin.firestore.Timestamp.now(),
      userId: context.uid,
      price: fromProductData?.price || 0.0
    };

    await sourceTransactionRef.set(sourceTransaction);

    // 5. Record transaction in receiver business (addition)
    const destTransactionRef = firestore
      .collection('transactions')
      .doc(toBusinessId)
      .collection('usersTransactions')
      .doc();

    const destTransaction = {
      transactionId: destTransactionRef.id,
      productId: productId,
      quantity: toQty + quantity, // New quantity after addition
      previousQuantity: toQty,
      transactionType: 'addition',
      transactionOrigin: 'Product Transfer In',
      timestamp: admin.firestore.Timestamp.now(),
      userId: context.uid,
      price: fromProductData?.price || 0.0
    };

    await destTransactionRef.set(destTransaction);

    return { success: true };
  } catch (error) {
    console.error('acceptTransferRequestV2 error:', error);
    throw new HttpsError('internal', error.message || 'Unknown error occurred');
  }
});

// New Cloud Function for batch transfer requests
exports.acceptBatchTransferRequestV2 = onCall({ region: "us-central1" }, async (request) => {
  const context = request.auth;
  if (!context) {
    throw new HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { fromBusinessId, toBusinessId, transferRequestId, products } = request.data;
  if (!fromBusinessId || !toBusinessId || !transferRequestId || !products || !Array.isArray(products)) {
    throw new HttpsError('invalid-argument', 'Missing required fields or invalid products array');
  }

  if (products.length === 0) {
    throw new HttpsError('invalid-argument', 'Products array cannot be empty');
  }

  try {
    console.log(`[Batch Transfer] Processing ${products.length} products from ${fromBusinessId} to ${toBusinessId}`);
    
    // Process each product in the batch transfer
    for (const product of products) {
      const { id: productId, quantity, name: productName } = product;
      
      if (!productId || !quantity || quantity <= 0) {
        throw new HttpsError('invalid-argument', `Invalid product data: ${JSON.stringify(product)}`);
      }

      console.log(`[Batch Transfer] Processing product: ${productName} (${productId}), quantity: ${quantity}`);

      let fromProductData = null;
      let fromQty = 0;
      let toQty = 0;

      // 1. Update product stock in sender (fromBusinessId): decrement quantity
      const fromProductRef = firestore
        .collection('products').doc(fromBusinessId)
        .collection('userProducts').doc(productId);
        
      await firestore.runTransaction(async (transaction) => {
        const fromProductSnap = await transaction.get(fromProductRef);
        if (!fromProductSnap.exists) {
          throw new HttpsError('not-found', `Product ${productName} not found in sender business`);
        }
        
        fromProductData = fromProductSnap.data();
        fromQty = fromProductData.quantity || 0;
        
        if (fromQty < quantity) {
          throw new HttpsError('failed-precondition', `Not enough stock for ${productName}. Available: ${fromQty}, Requested: ${quantity}`);
        }
        
        // Decrease quantity in source business
        transaction.update(fromProductRef, { quantity: fromQty - quantity });
        console.log(`[Batch Transfer] Decreased ${productName} in source: ${fromQty} -> ${fromQty - quantity}`);
      });

      // 2. Update product stock in receiver (toBusinessId): increment quantity or create product
      const toProductRef = firestore
        .collection('products').doc(toBusinessId)
        .collection('userProducts').doc(productId);
        
      await firestore.runTransaction(async (transaction) => {
        const toProductSnap = await transaction.get(toProductRef);
        
        if (!toProductSnap.exists) {
          // Product doesn't exist in destination - get full product data from source
          const fromProductSnap = await transaction.get(fromProductRef);
          if (fromProductSnap.exists) {
            const sourceProductData = fromProductSnap.data();
            const newProductData = {
              ...sourceProductData,
              quantity: quantity,
              owner: toBusinessId,
              id: productId
            };
            transaction.set(toProductRef, newProductData);
            console.log(`[Batch Transfer] Created new product ${productName} in destination with quantity: ${quantity}`);
            toQty = 0;
          } else {
            // Fallback: create minimal product data
            const minimalProductData = {
              id: productId,
              name: productName || 'Unknown Product',
              quantity: quantity,
              owner: toBusinessId,
              itemType: product.itemType || 'product',
              price: 0.0,
              buyingPrice: 0.0,
              storeId: '',
              code: '',
              discount: 0.0,
              manufacturer: '',
              location: '',
              details: '',
              understock: 0.0,
              category: '',
              total: 0.0,
              count: 0.0
            };
            transaction.set(toProductRef, minimalProductData);
            console.log(`[Batch Transfer] Created minimal product ${productName} in destination`);
            toQty = 0;
          }
        } else {
          // Product exists in destination - increment quantity
          toQty = toProductSnap.data().quantity || 0;
          transaction.update(toProductRef, { quantity: toQty + quantity });
          console.log(`[Batch Transfer] Increased ${productName} in destination: ${toQty} -> ${toQty + quantity}`);
        }
      });

      // 3. Record transaction in sender business (removal)
      const sourceTransactionRef = firestore
        .collection('transactions')
        .doc(fromBusinessId)
        .collection('usersTransactions')
        .doc();

      const sourceTransaction = {
        transactionId: sourceTransactionRef.id,
        productId: productId,
        quantity: fromQty - quantity, // New quantity after removal
        previousQuantity: fromQty,
        transactionType: 'removal',
        transactionOrigin: 'Batch Transfer Out',
        timestamp: admin.firestore.Timestamp.now(),
        userId: context.uid,
        price: fromProductData?.price || 0.0
      };

      await sourceTransactionRef.set(sourceTransaction);

      // 4. Record transaction in receiver business (addition)
      const destTransactionRef = firestore
        .collection('transactions')
        .doc(toBusinessId)
        .collection('usersTransactions')
        .doc();

      const destTransaction = {
        transactionId: destTransactionRef.id,
        productId: productId,
        quantity: toQty + quantity, // New quantity after addition
        previousQuantity: toQty,
        transactionType: 'addition',
        transactionOrigin: 'Batch Transfer In',
        timestamp: admin.firestore.Timestamp.now(),
        userId: context.uid,
        price: fromProductData?.price || 0.0
      };

      await destTransactionRef.set(destTransaction);
    }

    // 5. Update transfer request status to 'accepted' in both businesses
    const updateData = {
      status: 'accepted',
      respondedByUserId: context.uid,
      respondedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    // Update in destination business
    await firestore
      .collection('product_transfer_requests').doc(toBusinessId)
      .collection('userTransferRequests').doc(transferRequestId)
      .update(updateData);

    // Update in source business
    await firestore
      .collection('product_transfer_requests').doc(fromBusinessId)
      .collection('userTransferRequests').doc(transferRequestId)
      .update(updateData);

    console.log(`[Batch Transfer] Successfully completed batch transfer of ${products.length} products`);
    return { 
      success: true, 
      message: `Successfully transferred ${products.length} products from ${fromBusinessId} to ${toBusinessId}`,
      processedProducts: products.length
    };
    
  } catch (error) {
    console.error('acceptBatchTransferRequestV2 error:', error);
    throw new HttpsError('internal', error.message || 'Unknown error occurred during batch transfer');
  }
});

exports.updateUserDetailsV2 = onCall(async (request) => {
  try {
    const { userId, updateData } = request.data;
    
    // Validate required parameters
    if (!userId) {
      throw new HttpsError("invalid-argument", "userId is required");
    }
    
    if (!updateData || typeof updateData !== 'object') {
      throw new HttpsError("invalid-argument", "updateData must be a valid object");
    }

    // Define allowed fields that can be updated
    const allowedFields = [
      'name', 
      'email', 
      'phone', 
      'role', 
      'maxBusiness', 
      'image', 
      'business'
    ];
    
    // Filter updateData to only include allowed fields
    const filteredUpdateData = {};
    Object.keys(updateData).forEach(key => {
      if (allowedFields.includes(key)) {
        filteredUpdateData[key] = updateData[key];
      }
    });
    
    if (Object.keys(filteredUpdateData).length === 0) {
      throw new HttpsError("invalid-argument", "No valid fields to update");
    }

    // Check if user exists in gmanusers collection
    const userRef = firestore.collection('gmanusers').doc(userId);
    const userDoc = await userRef.get();
    
    if (!userDoc.exists) {
      throw new HttpsError("not-found", "User not found in gmanusers collection");
    }

    const currentUserData = userDoc.data();
    
    // Update gmanusers collection
    await userRef.update(filteredUpdateData);
    
    // If user has businesses, update their records in employees subcollections
    if (currentUserData.business && Array.isArray(currentUserData.business)) {
      const businessUpdatePromises = currentUserData.business.map(async (businessId) => {
        const employeeRef = firestore
          .collection('employees')
          .doc(businessId)
          .collection('userEmployees')
          .doc(userId);
        
        // Check if employee record exists before updating
        const employeeDoc = await employeeRef.get();
        if (employeeDoc.exists) {
          return employeeRef.update(filteredUpdateData);
        }
        return Promise.resolve();
      });
      
      await Promise.all(businessUpdatePromises);
    }

    // If business array was updated, handle employee collection changes
    if (filteredUpdateData.business && Array.isArray(filteredUpdateData.business)) {
      const oldBusinesses = currentUserData.business || [];
      const newBusinesses = filteredUpdateData.business;
      
      // Remove user from businesses they're no longer part of
      const removedBusinesses = oldBusinesses.filter(id => !newBusinesses.includes(id));
      const removePromises = removedBusinesses.map(businessId => {
        return firestore
          .collection('employees')
          .doc(businessId)
          .collection('userEmployees')
          .doc(userId)
          .delete();
      });
      
      // Add user to new businesses
      const addedBusinesses = newBusinesses.filter(id => !oldBusinesses.includes(id));
      const addPromises = addedBusinesses.map(businessId => {
        const updatedUserData = { ...currentUserData, ...filteredUpdateData };
        return firestore
          .collection('employees')
          .doc(businessId)
          .collection('userEmployees')
          .doc(userId)
          .set(updatedUserData, { merge: true });
      });
      
      await Promise.all([...removePromises, ...addPromises]);
    }

    return {
      success: true,
      message: "User details updated successfully",
      updatedFields: Object.keys(filteredUpdateData)
    };

  } catch (error) {
    console.error("Error updating user details:", error);
    
    if (error instanceof HttpsError) {
      throw error;
    }
    
    throw new HttpsError("internal", `Failed to update user details: ${error.message}`);
  }
});

// Get subscription pricing configuration
exports.getSubscriptionPricing = onRequest(async (req, res) => {
  const origin = req.headers.origin;
  const allowedOrigins = [
    "https://hesabumauzo.co.tz",
    "https://biashara.hesabumauzo.co.tz",
    "http://localhost:5000",
    "http://localhost:8080",
    "http://localhost:5173"
  ];
  if (origin && allowedOrigins.includes(origin)) {
    res.set("Access-Control-Allow-Origin", origin);
  }
  res.set("Access-Control-Allow-Methods", "GET, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  
  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  try {
    const pricingDoc = await admin.firestore()
      .collection('subscriptionPricing')
      .doc('config')
      .get();

    if (pricingDoc.exists) {
      return res.status(200).json(pricingDoc.data());
    } else {
      // Return default pricing if not set
      const defaultPricing = {
        tier1: { week: 5000, month: 15000, sixMonths: 75000, year: 130000 },
        tier2: { week: 10000, month: 30000, sixMonths: 150000, year: 260000 },
        tier3: { week: 15000, month: 45000, sixMonths: 225000, year: 390000 },
        tier4: { week: 20000, month: 60000, sixMonths: 300000, year: 520000 },
        tier5Plus: { week: 25000, month: 75000, sixMonths: 375000, year: 650000 },
        durationSeconds: {
          week: '604800',
          month: '2592000',
          sixMonths: '15552000',
          year: '31622400'
        }
      };
      return res.status(200).json(defaultPricing);
    }
  } catch (error) {
    console.error("Error fetching subscription pricing:", error);
    return res.status(500).json({ error: "Internal server error" });
  }
});

// Update subscription pricing configuration
exports.updateSubscriptionPricing = onRequest(async (req, res) => {
  const origin = req.headers.origin;
  const allowedOrigins = [
    "https://hesabumauzo.co.tz",
    "https://biashara.hesabumauzo.co.tz",
    "http://localhost:5000",
    "http://localhost:8080",
    "http://localhost:5173"
  ];
  if (origin && allowedOrigins.includes(origin)) {
    res.set("Access-Control-Allow-Origin", origin);
  }
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  
  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  try {
    const pricingData = req.body;

    // Validate required fields
    const requiredTiers = ['tier1', 'tier2', 'tier3', 'tier4', 'tier5Plus'];
    const requiredPackages = ['week', 'month', 'sixMonths', 'year'];

    for (const tier of requiredTiers) {
      if (!pricingData[tier]) {
        return res.status(400).json({ error: `Missing ${tier} pricing data` });
      }
      for (const pkg of requiredPackages) {
        if (typeof pricingData[tier][pkg] !== 'number') {
          return res.status(400).json({ error: `Invalid price for ${tier}.${pkg}` });
        }
      }
    }

    // Add metadata
    const dataToSave = {
      ...pricingData,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: 'admin'
    };

    await admin.firestore()
      .collection('subscriptionPricing')
      .doc('config')
      .set(dataToSave);

    console.log("Subscription pricing updated successfully");
    return res.status(200).json({ 
      success: true, 
      message: "Subscription pricing updated successfully" 
    });
  } catch (error) {
    console.error("Error updating subscription pricing:", error);
    return res.status(500).json({ error: "Internal server error" });
  }
});