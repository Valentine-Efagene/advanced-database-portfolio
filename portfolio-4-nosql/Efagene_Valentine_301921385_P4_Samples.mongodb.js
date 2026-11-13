// ValPay Portfolio 4: print the excerpts kept in Efagene_Valentine_301921385_P4_SampleKYC.jsonl and Efagene_Valentine_301921385_P4_SampleActivity.jsonl
// (relaxed Extended JSON, one document per line, no _id), so the samples always match the seed.
// scripts/Efagene_Valentine_301921385_NoSQLEvidence.sh splits the output on the ##FILE markers.
db = db.getSiblingDB('valpay');
const out = (c, q, s) => db.getCollection(c).find(q, { _id: 0 }).sort(s).toArray()
  .forEach((d) => print(EJSON.stringify(d, { relaxed: true })));

print('##FILE Efagene_Valentine_301921385_P4_SampleKYC.jsonl');
// Valentine (1) and Chioma (2), then a bulk customer whose first NIN was rejected
out('kyc_documents', { customer_id: { $in: [1, 2] } }, { customer_id: 1, submitted_at: 1 });
const rej = db.kyc_documents.find({ status: 'REJECTED', document_type: 'NIN', customer_id: { $gt: 3 } }).sort({ customer_id: 1 }).limit(1).next();
out('kyc_documents', { customer_id: rej.customer_id, document_type: 'NIN' }, { submitted_at: 1 });

print('##FILE Efagene_Valentine_301921385_P4_SampleActivity.jsonl');
// Valentine's VP-TXN-OK-004 session (Portfolio 3 transfer)
out('activity_events', { customer_id: 1, ts: { $gte: ISODate('2026-10-28T06:55:00Z'), $lte: ISODate('2026-10-28T07:05:00Z') } }, { ts: 1 });
// a transfer from a shared "device farm" fingerprint and its rule hit
const farm = db.activity_events.find({ rule: 'shared_device_multi_account' }).sort({ ts: -1 }).limit(1).next();
out('activity_events', { customer_id: farm.customer_id, ts: { $gte: new Date(farm.ts - 5 * 60000), $lte: farm.ts } }, { ts: 1 });
// a credential-stuffing burst that ends in a BLOCK
const b = db.activity_events.find({ rule: 'failed_login_burst' }).sort({ ts: -1 }).limit(1).next();
out('activity_events', { device_id: b.device_id, customer_id: b.customer_id, ts: { $gte: new Date(b.ts - 120000), $lte: b.ts } }, { ts: 1 });
