// ValPay Portfolio 4: operational queries on the seeded data
// Run after seed.mongodb.js:  mongosh "mongodb://localhost:27017/valpay" --file queries.mongodb.js
db = db.getSiblingDB('valpay');

// print one document per line; long documents wrap at a field boundary
const wrapLine = (s, width = 160) => {
  const parts = s.split(/(?<=,)(?=")/);
  const lines = [];
  let cur = '';
  parts.forEach((p) => { if (cur && (cur + p).length > width) { lines.push(cur); cur = '    ' + p; } else cur += p; });
  lines.push(cur);
  return lines.join('\n');
};
const show = (rows) => rows.forEach((r) => print(wrapLine(EJSON.stringify(r, { relaxed: true }))));
const title = (t) => { print(''); print('=== ' + t + ' ==='); };
const PERIOD_END = ISODate('2026-11-01T00:00:00Z');   // end of the seeded data

// Q1. KYC review queue: PENDING documents, oldest first (partial index pending_review_queue)
title('Q1. KYC review queue (PENDING, oldest first, first 10)');
print('Pending documents: ' + db.kyc_documents.countDocuments({ status: 'PENDING' }));
show(db.kyc_documents.find(
  { status: 'PENDING' },
  { _id: 0, customer_id: 1, account_number: 1, document_type: 1, submitted_at: 1, 'metadata.provider': 1 }
).sort({ submitted_at: 1 }).limit(10).toArray());

// Q2. KYC funnel: documents by type and status
title('Q2. KYC funnel by document type and status');
show(db.kyc_documents.aggregate([
  { $group: { _id: { type: '$document_type', status: '$status' }, n: { $sum: 1 } } },
  { $group: { _id: '$_id.type', total: { $sum: '$n' }, by_status: { $push: { k: '$_id.status', v: '$n' } } } },
  { $project: { _id: 0, document_type: '$_id', total: 1, by_status: { $arrayToObject: '$by_status' } } },
  { $project: { document_type: 1, total: 1,
      verified: { $ifNull: ['$by_status.VERIFIED', 0] }, pending: { $ifNull: ['$by_status.PENDING', 0] },
      rejected: { $ifNull: ['$by_status.REJECTED', 0] } } },
  { $sort: { total: -1 } }
]).toArray());

// Q3. Why documents get rejected
title('Q3. Rejection reasons by document type');
show(db.kyc_documents.aggregate([
  { $match: { status: 'REJECTED' } },
  { $group: { _id: { document_type: '$document_type', reason: '$metadata.rejection_reason' }, n: { $sum: 1 } } },
  { $sort: { n: -1, '_id.document_type': 1 } },
  { $project: { _id: 0, document_type: '$_id.document_type', reason: '$_id.reason', n: 1 } }
]).toArray());

// Q4. Tier derived from VERIFIED documents (compare with customer.kyc_tier in PostgreSQL)
title('Q4. KYC tier derived from verified documents');
show(db.kyc_documents.aggregate([
  { $match: { status: 'VERIFIED' } },
  { $group: { _id: '$customer_id', docs: { $addToSet: '$document_type' } } },
  { $project: { tier: { $switch: { branches: [
      { case: { $setIsSubset: [['BVN', 'NIN', 'UTILITY_BILL'], '$docs'] }, then: 'TIER3' },
      { case: { $setIsSubset: [['BVN', 'NIN'], '$docs'] }, then: 'TIER2' },
      { case: { $in: ['BVN', '$docs'] }, then: 'TIER1' } ], default: 'NONE' } } } },
  { $group: { _id: '$tier', customers: { $sum: 1 } } },
  { $sort: { _id: 1 } },
  { $project: { _id: 0, tier: '$_id', customers: 1 } }
]).toArray());

// Q5. Customer timeline: latest 12 events for one customer (index customer_timeline)
title('Q5. Customer timeline, customer_id 57 (latest 12 events)');
show(db.activity_events.find(
  { customer_id: 57 },
  { _id: 0, ts: 1, event: 1, device_id: 1, ip: 1, reference: 1, amount_ngn: 1, rule: 1 }
).sort({ ts: -1 }).limit(12).toArray());

// Q6. Transfers initiated in a time window (index event_time)
title('Q6. Transfers initiated 1-7 October 2026');
const w = { event: 'transfer_initiated', ts: { $gte: ISODate('2026-10-01T00:00:00Z'), $lt: ISODate('2026-10-08T00:00:00Z') } };
show(db.activity_events.aggregate([
  { $match: w },
  { $group: { _id: '$txn_status', transfers: { $sum: 1 }, total_ngn: { $sum: '$amount_ngn' } } },
  { $project: { _id: 0, txn_status: '$_id', transfers: 1, total_ngn: { $round: ['$total_ngn', 2] } } },
  { $sort: { transfers: -1 } }
]).toArray());
print('Largest five in the window:');
show(db.activity_events.find(w, { _id: 0, ts: 1, reference: 1, account_number: 1, beneficiary: 1, amount_ngn: 1 })
  .sort({ amount_ngn: -1 }).limit(5).toArray());

// Q7. Fraud rule hits by rule
title('Q7. Fraud rule hits by rule');
show(db.activity_events.aggregate([
  { $match: { event: 'fraud_rule_hit' } },
  { $group: { _id: '$rule', hits: { $sum: 1 }, customers: { $addToSet: '$customer_id' },
              avg_score: { $avg: '$score' }, max_score: { $max: '$score' },
              step_up: { $sum: { $cond: [{ $eq: ['$action', 'STEP_UP'] }, 1, 0] } },
              blocked: { $sum: { $cond: [{ $eq: ['$action', 'BLOCK'] }, 1, 0] } } } },
  { $project: { _id: 0, rule: '$_id', hits: 1, customers: { $size: '$customers' },
                avg_score: { $round: ['$avg_score', 3] }, max_score: 1, step_up: 1, blocked: 1 } },
  { $sort: { hits: -1 } }
]).toArray());

// Q8. Monthly fraud trend for 2026
title('Q8. Fraud rule hits per month, 2026');
show(db.activity_events.aggregate([
  { $match: { event: 'fraud_rule_hit', ts: { $gte: ISODate('2026-01-01T00:00:00Z'), $lt: PERIOD_END } } },
  { $group: { _id: { $dateToString: { format: '%Y-%m', date: '$ts' } }, hits: { $sum: 1 } } },
  { $sort: { _id: 1 } },
  { $project: { _id: 0, month: '$_id', hits: 1 } }
]).toArray());

// Q9. Riskiest device fingerprints (fraud_signals DEVICE_SUMMARY, index type_risk)
title('Q9. Top 8 risky devices');
show(db.fraud_signals.find(
  { signal_type: 'DEVICE_SUMMARY' },
  { _id: 0, device_id: 1, risk_score: 1, customer_count: 1, rule_hits: 1, failed_logins: 1, ip_count: 1, last_seen: 1 }
).sort({ risk_score: -1, rule_hits: -1, device_id: 1 }).limit(8).toArray());

// Q10. Open fraud cases waiting for an analyst (index case_queue)
title('Q10. Open fraud cases (newest first, first 8)');
print('Open cases: ' + db.fraud_signals.countDocuments({ signal_type: 'RULE_HIT', case_status: 'OPEN' }));
show(db.fraud_signals.find(
  { signal_type: 'RULE_HIT', case_status: 'OPEN' },
  { _id: 0, detected_at: 1, customer_id: 1, rule: 1, score: 1, action: 1, reference: 1 }
).sort({ detected_at: -1 }).limit(8).toArray());

// Q11. Trace a ledger reference from PostgreSQL into the event stream (index txn_reference)
title('Q11. Trace VP-TXN-OK-004 (the Portfolio 3 transfer) and the session around it');
const xfer = db.activity_events.findOne({ reference: 'VP-TXN-OK-004' });
show([xfer].map(({ _id, ...rest }) => rest));
show(db.activity_events.find(
  { customer_id: xfer.customer_id, ts: { $gte: new Date(xfer.ts.getTime() - 10 * 60000), $lte: xfer.ts } },
  { _id: 0, ts: 1, event: 1, device_id: 1, ip: 1 }
).sort({ ts: 1 }).toArray());

// Q12. Customers whose accounts were hit from a shared device and who still have KYC pending ($lookup)
title('Q12. Customers on shared-device rule hits with KYC still pending');
show(db.fraud_signals.aggregate([
  { $match: { signal_type: 'RULE_HIT', rule: 'shared_device_multi_account' } },
  { $group: { _id: '$customer_id', hits: { $sum: 1 }, last_hit: { $max: '$detected_at' } } },
  { $lookup: { from: 'kyc_documents', let: { c: '$_id' }, pipeline: [
      { $match: { $expr: { $and: [{ $eq: ['$customer_id', '$$c'] }, { $eq: ['$status', 'PENDING'] }] } } },
      { $project: { _id: 0, document_type: 1, submitted_at: 1 } } ], as: 'pending_kyc' } },
  { $match: { 'pending_kyc.0': { $exists: true } } },
  { $sort: { hits: -1, last_hit: 1, _id: 1 } },
  { $project: { _id: 0, customer_id: '$_id', hits: 1, last_hit: 1, pending_kyc: 1 } }
]).toArray());
