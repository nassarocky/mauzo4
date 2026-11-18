const { test } = require("node:test");
const assert = require("node:assert/strict");
const { createSmsHandlers } = require("./sms_functions");

function createFakeFirestore(seed) {
  const documents = new Map(Object.entries(seed));
  const logs = [];

  function snapshot(path) {
    return {
      id: path.split("/").at(-1),
      exists: documents.has(path),
      data: () => documents.get(path),
    };
  }

  function document(path) {
    return {
      path,
      get: async () => snapshot(path),
      update: async (values) => {
        documents.set(path, { ...(documents.get(path) || {}), ...values });
      },
      collection: (name) => collection(`${path}/${name}`),
    };
  }

  function collection(path) {
    return {
      doc: (id) => document(`${path}/${id}`),
      add: async (values) => {
        logs.push(values);
        return { id: `log-${logs.length}` };
      },
    };
  }

  return {
    documents,
    logs,
    collection,
    getAll: async (...refs) => refs.map((ref) => snapshot(ref.path)),
    runTransaction: async (callback) =>
      callback({
        get: async (ref) => snapshot(ref.path),
        update: (ref, values) => {
          documents.set(ref.path, {
            ...(documents.get(ref.path) || {}),
            ...values,
          });
        },
      }),
  };
}

test("sendAdvertisementSms personalizes, bills, and logs selected clients", async () => {
  const firestore = createFakeFirestore({
    "gmanusers/user-1": {
      role: "manager",
      business: ["business-1"],
    },
    "businesses/business-1": {
      name: "Duka Bora",
      smsCredits: 10,
      smsCreditsUsed: 0,
    },
    "clients/business-1/userClients/client-1": {
      name: "Asha",
      phone: "0765908208",
    },
  });
  const admin = {
    firestore: {
      FieldValue: {
        serverTimestamp: () => "server-time",
        increment: (value) => ({ increment: value }),
      },
    },
  };
  const handlers = createSmsHandlers({
    firestore,
    admin,
    fetchImpl: async () => ({ text: async () => "000 Send Successful" }),
    secrets: {
      user: { value: () => "gateway-user" },
      pwd: { value: () => "gateway-password" },
      senderId: { value: () => "HesabuMz" },
    },
    assertCommissionAdmin: async () => {},
  });

  const result = await handlers.sendAdvertisementSms({
    auth: { uid: "user-1" },
    data: {
      businessId: "business-1",
      clientIds: ["client-1"],
      message: "Habari {name}, karibu {business}.",
    },
  });

  assert.equal(result.success, true);
  assert.equal(result.sent, 1);
  assert.equal(result.creditsUsed, 1);
  assert.equal(
    firestore.documents.get("businesses/business-1").smsCredits,
    9
  );
  assert.equal(firestore.logs.length, 1);
  assert.equal(firestore.logs[0].type, "advertisement");
  assert.equal(
    firestore.logs[0].message,
    "Habari Asha, karibu Duka Bora."
  );
});

test("sendBusinessSms debt payment uses total remaining debt not the paid item", async () => {
  const firestore = createFakeFirestore({
    "gmanusers/user-1": {
      role: "owner",
      business: ["business-1"],
    },
    "businesses/business-1": {
      name: "Duka Bora",
      mainCurrency: "TZS",
      smsCredits: 10,
      smsCreditsUsed: 0,
    },
    "clients/business-1/userClients/client-1": {
      name: "Asha",
      phone: "0765908208",
      debt: 11000,
    },
  });
  const admin = {
    firestore: {
      FieldValue: {
        serverTimestamp: () => "server-time",
        increment: (value) => ({ increment: value }),
      },
    },
  };
  const handlers = createSmsHandlers({
    firestore,
    admin,
    fetchImpl: async () => ({ text: async () => "000 Send Successful" }),
    secrets: {
      user: { value: () => "gateway-user" },
      pwd: { value: () => "gateway-password" },
      senderId: { value: () => "HesabuMz" },
    },
    assertCommissionAdmin: async () => {},
  });

  const result = await handlers.sendBusinessSms({
    auth: { uid: "user-1" },
    data: {
      businessId: "business-1",
      type: "debt_payment",
      clientId: "client-1",
      phone: "0765908208",
      amount: 2000,
      remaining: 3000,
      lang: "en",
    },
  });

  assert.equal(result.success, true);
  assert.equal(firestore.logs.length, 1);
  assert.equal(firestore.logs[0].type, "debt_payment");
  assert.match(firestore.logs[0].message, /TZS 2000/);
  assert.match(firestore.logs[0].message, /Remaining TZS 11000/);
  assert.equal(firestore.logs[0].message.includes("3000"), false);
});

test("sendBusinessSms purchase receipt includes items, total, and remaining debt", async () => {
  const firestore = createFakeFirestore({
    "gmanusers/user-1": {
      role: "owner",
      business: ["business-1"],
    },
    "businesses/business-1": {
      name: "Duka Bora",
      mainCurrency: "TZS",
      smsCredits: 10,
      smsCreditsUsed: 0,
      phone: "0765908208",
    },
    "suppliers/business-1/userSuppliers/sup-1": {
      name: "Mtoa Bidhaa",
      phone: "0765908208",
    },
    "recovered/business-1/userRecovered/p1": {
      supplierName: "Mtoa Bidhaa",
      price: 4500,
      payment: 2000,
      debt: 2500,
      products: [
        { name: "Sugar", quantity: 2, price: 1500 },
        { name: "Rice", quantity: 1, price: 1500 },
      ],
    },
  });
  const admin = {
    firestore: {
      FieldValue: {
        serverTimestamp: () => "server-time",
        increment: (value) => ({ increment: value }),
      },
    },
  };
  const handlers = createSmsHandlers({
    firestore,
    admin,
    fetchImpl: async () => ({ text: async () => "000 Send Successful" }),
    secrets: {
      user: { value: () => "gateway-user" },
      pwd: { value: () => "gateway-password" },
      senderId: { value: () => "HesabuMz" },
    },
    assertCommissionAdmin: async () => {},
  });

  const result = await handlers.sendBusinessSms({
    auth: { uid: "user-1" },
    data: {
      businessId: "business-1",
      type: "purchase_receipt",
      supplierId: "sup-1",
      phone: "0765908208",
      referenceId: "p1",
      lang: "en",
    },
  });

  assert.equal(result.success, true);
  assert.equal(firestore.logs.length, 1);
  assert.equal(firestore.logs[0].type, "purchase_receipt");
  assert.match(firestore.logs[0].message, /Purchase receipt from Duka Bora for Mtoa Bidhaa/);
  assert.ok(firestore.logs[0].message.includes("Sugar x2 TZS 1500 (TZS 3000)"));
  assert.ok(firestore.logs[0].message.includes("Total TZS 4500"));
  assert.ok(firestore.logs[0].message.includes("Paid TZS 2000"));
  assert.ok(firestore.logs[0].message.includes("Remaining TZS 2500"));
});

test("grantSmsCredits is refused for customer care admins", async () => {
  const firestore = createFakeFirestore({
    "businesses/business-1": { name: "Duka Bora", smsCredits: 1 },
  });
  const handlers = createSmsHandlers({
    firestore,
    admin: { firestore: { FieldValue: { serverTimestamp: () => "t", increment: (v) => v } } },
    fetchImpl: async () => ({ text: async () => "" }),
    secrets: {},
    assertCommissionAdmin: async () => {},
    assertFullCommissionAdmin: async () => {
      throw new Error("Customer care admins cannot upgrade subscriptions or grant SMS.");
    },
  });

  await assert.rejects(
    () =>
      handlers.grantSmsCredits({
        auth: { uid: "care-1" },
        data: { businessId: "business-1", credits: 50 },
      }),
    /Customer care/
  );
  assert.equal(firestore.documents.get("businesses/business-1").smsCredits, 1);
});
