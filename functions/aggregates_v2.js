const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
let _firestore = null;
try { _firestore = admin.firestore(); } catch (e) { _firestore = null; }
function getDb() { return _firestore || admin.firestore(); }

function _num(x) {
  if (x === null || x === undefined) return 0;
  if (typeof x === 'number' && !isNaN(x)) return x;
  const p = parseFloat(x);
  return isNaN(p) ? 0 : p;
}

async function _getBusiness(businessId) {
  const snap = await getDb().collection('businesses').doc(businessId).get();
  return snap.exists ? snap.data() : {};
}

function _toMain(amount, currency, mainCurrency, rateUsed) {
  const amt = _num(amount);
  if (!currency || currency === mainCurrency) return amt;
  const rate = _num(rateUsed) || 1;
  return amt * rate;
}

async function _ensureCurrentPeriodRef(businessId, business) {
  const ref = getDb()
    .collection('aggregates')
    .doc(businessId)
    .collection('periods')
    .doc('current');
  const snap = await ref.get();
  if (!snap.exists) {
    await ref.set({
      status: 'current',
      startTime: business?.reset_time || admin.firestore.FieldValue.serverTimestamp(),
      currency: business?.mainCurrency || 'TZS',
      paymentsCash: 0,
      paymentsBank: 0,
      paymentsMobile: 0,
      debtCollected: 0,
      expensesTotal: 0,
      purchasesPaidTotal: 0,
      availableBalance: 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  return ref;
}

function _salePaymentTotals(doc, mainCurrency) {
  let cash = 0, bank = 0, mobile = 0, debtCol = 0;
  const payments = Array.isArray(doc?.payments) ? doc.payments : [];
  if (payments.length > 0) {
    for (const p of payments) {
      const amtMain = _toMain(p?.amount, p?.currency, mainCurrency, p?.rateUsed);
      const methodRaw = (p?.method || 'cash').toString().trim().toLowerCase();
      const method = methodRaw === '' ? 'cash' : methodRaw;
      if (method === 'bank') bank += amtMain; else if (method === 'mobile') mobile += amtMain; else cash += amtMain;
      if ((doc?.saleType || '') === 'debt_repayment') debtCol += amtMain;
    }
  } else {
    const amt = _num(doc?.payment);
    cash += amt;
    if ((doc?.saleType || '') === 'debt_repayment') debtCol += amt;
  }
  return { cash, bank, mobile, debtCollected: debtCol };
}

function _purchasePaidTotal(doc, mainCurrency) {
  let total = 0;
  const payments = Array.isArray(doc?.payments) ? doc.payments : [];
  if (payments.length > 0) {
    for (const p of payments) total += _toMain(p?.amount, p?.currency, mainCurrency, p?.rateUsed);
  } else {
    total += _num(doc?.payment);
  }
  return total;
}

function _asTimestamp(val) {
  if (!val) return null;
  if (val instanceof admin.firestore.Timestamp) return val;
  if (val._seconds !== undefined && val._nanoseconds !== undefined) {
    return new admin.firestore.Timestamp(val._seconds, val._nanoseconds);
  }
  if (val instanceof Date) return admin.firestore.Timestamp.fromDate(val);
  return null;
}

function _includeByReset(doc, resetTs) {
  if (!doc || !resetTs) return false;
  const d = _asTimestamp(doc.date || doc.timestamp);
  if (!d) return false;
  // Exclusive lower bound to match front-end dialog (date > reset_time)
  return d.toMillis() > _asTimestamp(resetTs).toMillis();
}

async function _updatePeriodWithDeltas(businessId, deltas) {
  const business = await _getBusiness(businessId);
  const periodRef = await _ensureCurrentPeriodRef(businessId, business);
  await getDb().runTransaction(async (tx) => {
    const snap = await tx.get(periodRef);
    const data = snap.exists ? snap.data() : {};
    const paymentsCash = _num(data.paymentsCash) + _num(deltas.paymentsCash);
    const paymentsBank = _num(data.paymentsBank) + _num(deltas.paymentsBank);
    const paymentsMobile = _num(data.paymentsMobile) + _num(deltas.paymentsMobile);
    const debtCollected = _num(data.debtCollected) + _num(deltas.debtCollected);
    const expensesTotal = _num(data.expensesTotal) + _num(deltas.expensesTotal);
    const purchasesPaidTotal = _num(data.purchasesPaidTotal) + _num(deltas.purchasesPaidTotal);
    const availableBalance = paymentsCash + paymentsBank + paymentsMobile - expensesTotal - purchasesPaidTotal;
    tx.set(periodRef, {
      paymentsCash,
      paymentsBank,
      paymentsMobile,
      debtCollected,
      expensesTotal,
      purchasesPaidTotal,
      availableBalance,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  });
}

// Sales (payments + optional debt collected) since reset_time
exports.aggregateSalesV2 = onDocumentWritten({ document: 'sales/{businessId}/userSales/{saleId}', region: 'us-central1' }, async (event) => {
  const businessId = event.params.businessId;
  const before = event.data?.before?.data() || null;
  const after = event.data?.after?.data() || null;
  const business = await _getBusiness(businessId);
  const resetTs = business?.reset_time;
  const mainCurrency = business?.mainCurrency || 'TZS';
  if (!resetTs) return;
  const beforeIn = _includeByReset(before, resetTs);
  const afterIn = _includeByReset(after, resetTs);
  const bTotals = beforeIn ? _salePaymentTotals(before, mainCurrency) : { cash: 0, bank: 0, mobile: 0, debtCollected: 0 };
  const aTotals = afterIn ? _salePaymentTotals(after, mainCurrency) : { cash: 0, bank: 0, mobile: 0, debtCollected: 0 };
  const deltas = {
    paymentsCash: _num(aTotals.cash) - _num(bTotals.cash),
    paymentsBank: _num(aTotals.bank) - _num(bTotals.bank),
    paymentsMobile: _num(aTotals.mobile) - _num(bTotals.mobile),
    debtCollected: _num(aTotals.debtCollected) - _num(bTotals.debtCollected),
    expensesTotal: 0,
    purchasesPaidTotal: 0,
  };
  if (Object.values(deltas).every(v => _num(v) === 0)) return;
  await _updatePeriodWithDeltas(businessId, deltas);
});

// Purchases paid since reset_time
exports.aggregateRecoveredV2 = onDocumentWritten({ document: 'recovered/{businessId}/userRecovered/{purchaseId}', region: 'us-central1' }, async (event) => {
  const businessId = event.params.businessId;
  const before = event.data?.before?.data() || null;
  const after = event.data?.after?.data() || null;
  const business = await _getBusiness(businessId);
  const resetTs = business?.reset_time;
  const mainCurrency = business?.mainCurrency || 'TZS';
  if (!resetTs) return;
  const beforeIn = _includeByReset(before, resetTs);
  const afterIn = _includeByReset(after, resetTs);
  const bAmt = beforeIn ? _purchasePaidTotal(before, mainCurrency) : 0;
  const aAmt = afterIn ? _purchasePaidTotal(after, mainCurrency) : 0;
  const deltas = {
    paymentsCash: 0,
    paymentsBank: 0,
    paymentsMobile: 0,
    debtCollected: 0,
    expensesTotal: 0,
    purchasesPaidTotal: _num(aAmt) - _num(bAmt),
  };
  if (Object.values(deltas).every(v => _num(v) === 0)) return;
  await _updatePeriodWithDeltas(businessId, deltas);
});

// Expenses since reset_time
exports.aggregateExpensesV2 = onDocumentWritten({ document: 'expenses/{businessId}/userExpenses/{expenseId}', region: 'us-central1' }, async (event) => {
  const businessId = event.params.businessId;
  const before = event.data?.before?.data() || null;
  const after = event.data?.after?.data() || null;
  const business = await _getBusiness(businessId);
  const resetTs = business?.reset_time;
  const mainCurrency = business?.mainCurrency || 'TZS';
  if (!resetTs) return;
  const beforeIn = _includeByReset(before, resetTs);
  const afterIn = _includeByReset(after, resetTs);
  const bAmt = beforeIn ? _toMain(before?.amount, before?.currency, mainCurrency, before?.rateUsed) : 0;
  const aAmt = afterIn ? _toMain(after?.amount, after?.currency, mainCurrency, after?.rateUsed) : 0;
  const deltas = {
    paymentsCash: 0,
    paymentsBank: 0,
    paymentsMobile: 0,
    debtCollected: 0,
    expensesTotal: _num(aAmt) - _num(bAmt),
    purchasesPaidTotal: 0,
  };
  if (Object.values(deltas).every(v => _num(v) === 0)) return;
  await _updatePeriodWithDeltas(businessId, deltas);
});

// Outstanding client debt (point-in-time), tracked in a separate meta doc
exports.aggregateDebtOutstandingV2 = onDocumentWritten({ document: 'debtHistory/{businessId}/clientDebtHistory/{debtId}', region: 'us-central1' }, async (event) => {
  const businessId = event.params.businessId;
  const before = event.data?.before?.data() || null;
  const after = event.data?.after?.data() || null;
  const statusIsPending = (s) => (s || '').toString().toUpperCase() === 'PENDING';
  const bAmt = before && statusIsPending(before.status) ? _num(before.remainingDebtAmount) : 0;
  const aAmt = after && statusIsPending(after.status) ? _num(after.remainingDebtAmount) : 0;
  const delta = _num(aAmt) - _num(bAmt);
  if (delta === 0) return;
  const totalsRef = getDb().collection('aggregates').doc(businessId).collection('meta').doc('totals');
  await getDb().runTransaction(async (tx) => {
    const snap = await tx.get(totalsRef);
    const cur = snap.exists ? snap.data() : {};
    const debtOutstandingTotal = _num(cur.debtOutstandingTotal) + delta;
    tx.set(totalsRef, { debtOutstandingTotal, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  });
});

// Create a snapshot into existing closedbooks (does not mutate existing user data)
exports.snapshotCurrentPeriodV2 = onCall({ region: 'us-central1' }, async (request) => {
  const { businessId } = request.data || {};
  if (!businessId) throw new HttpsError('invalid-argument', 'businessId is required');
  const business = await _getBusiness(businessId);
  const periodRef = await _ensureCurrentPeriodRef(businessId, business);
  const snap = await periodRef.get();
  if (!snap.exists) throw new HttpsError('failed-precondition', 'current period not initialized');
  const data = snap.data() || {};
  const now = admin.firestore.Timestamp.now();
  const totalPayment = _num(data.paymentsCash) + _num(data.paymentsBank) + _num(data.paymentsMobile);
  const closedRef = getDb().collection('closedbooks').doc(businessId).collection('userClosedBooks').doc();
  const payload = {
    id: closedRef.id,
    owner: businessId,
    totalSales: 0.0,
    totalPayment: totalPayment,
    totalDebt: 0.0,
    expenses: _num(data.expensesTotal),
    startDate: data.startTime || business?.reset_time || now,
    endDate: now,
    finalStock: 0.0,
    netProfit: 0.0,
    totalPurchase: _num(data.purchasesPaidTotal),
    totalDiscounts: 0.0,
    currency: data.currency || business?.mainCurrency || 'TZS',
    createdBy: request.auth?.uid || '',
    createdAt: now,
    reserveString1: '',
    reserveString2: '',
    reserveDouble1: 0.0,
    reserveDouble2: 0.0,
    reserveList1: [],
    reserveList2: [],
    debt: _num(data.debtCollected),
    debtCollected: _num(data.debtCollected),
  };
  await closedRef.set(payload);
  return { success: true, closedBookId: closedRef.id };
});

async function _rebuildCurrentPeriod(businessId, business) {
  const mainCurrency = business?.mainCurrency || 'TZS';
  const resetTs = business?.reset_time;
  if (!resetTs) return;
  const db = getDb();
  let cash = 0, bank = 0, mobile = 0, debtCollected = 0;
  const salesSnap = await db.collection('sales').doc(businessId).collection('userSales').where('date', '>', resetTs).get();
  for (const d of salesSnap.docs) {
    const t = _salePaymentTotals(d.data(), mainCurrency);
    cash += _num(t.cash);
    bank += _num(t.bank);
    mobile += _num(t.mobile);
    debtCollected += _num(t.debtCollected);
  }
  let purchasesPaidTotal = 0;
  const recSnap = await db.collection('recovered').doc(businessId).collection('userRecovered').where('date', '>', resetTs).get();
  for (const d of recSnap.docs) purchasesPaidTotal += _num(_purchasePaidTotal(d.data(), mainCurrency));
  let expensesTotal = 0;
  const expSnap = await db.collection('expenses').doc(businessId).collection('userExpenses').where('date', '>', resetTs).get();
  for (const d of expSnap.docs) expensesTotal += _num(_toMain(d.data()?.amount, d.data()?.currency, mainCurrency, d.data()?.rateUsed));
  const availableBalance = cash + bank + mobile - expensesTotal - purchasesPaidTotal;
  const periodRef = db.collection('aggregates').doc(businessId).collection('periods').doc('current');
  await periodRef.set({
    paymentsCash: cash,
    paymentsBank: bank,
    paymentsMobile: mobile,
    debtCollected,
    expensesTotal,
    purchasesPaidTotal,
    availableBalance,
    startTime: resetTs,
    currency: mainCurrency,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

exports.onBusinessResetTimeChangedV2 = onDocumentWritten({ document: 'businesses/{businessId}', region: 'us-central1' }, async (event) => {
  const businessId = event.params.businessId;
  const before = event.data?.before?.data() || null;
  const after = event.data?.after?.data() || null;
  const beforeTs = _asTimestamp(before?.reset_time);
  const afterTs = _asTimestamp(after?.reset_time);
  if (!afterTs) return;
  const changed = !beforeTs || beforeTs.toMillis() !== afterTs.toMillis();
  if (!changed) return;
  const db = getDb();
  const periodRef = db.collection('aggregates').doc(businessId).collection('periods').doc('current');
  const periodSnap = await periodRef.get();
  if (periodSnap.exists) {
    const cur = periodSnap.data() || {};
    const historyId = `${_asTimestamp(cur.startTime)?.toMillis() || admin.firestore.Timestamp.now().toMillis()}_${afterTs.toMillis()}`;
    const histRef = db.collection('aggregates').doc(businessId).collection('periods').doc(historyId);
    await histRef.set({
      ...cur,
      status: 'archived',
      endTime: afterTs,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  await periodRef.set({
    status: 'current',
    startTime: afterTs,
    currency: after?.mainCurrency || 'TZS',
    paymentsCash: 0,
    paymentsBank: 0,
    paymentsMobile: 0,
    debtCollected: 0,
    expensesTotal: 0,
    purchasesPaidTotal: 0,
    availableBalance: 0,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  await _rebuildCurrentPeriod(businessId, after || await _getBusiness(businessId));
});
