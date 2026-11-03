// ValPay Portfolio 4: deterministic MongoDB seed
// ---------------------------------------------------------------------------
// Run from this folder:  mongosh "mongodb://localhost:27017/valpay" --file seed.mongodb.js
// (scripts/nosql_evidence.sh runs it for you and writes evidence/script-output/load_summary.txt)
//
// Links to the relational model (Portfolio 1, scripts/seed.sql):
//   * customer_id is customer.customer_id (1-203). 1 = Valentine Efagene,
//     2 = Chioma Okonkwo, 3 = the ValPay ops wallet (no retail KYC or app
//     activity), 4-203 = the 200 bulk customers.
//   * account_number is wallet_account.account_number (VP1000000001,
//     VP1000000002, VP2000000001-VP2000000200).
//   * transfer_initiated events reuse the exact references, senders,
//     beneficiaries and amounts of the 28,000 bulk TRANSFER rows in seed.sql,
//     recomputed here with the same md5() formula, so any event can be traced
//     to wallet_transaction.reference in PostgreSQL.
//   * Derived KYC tiers match customer.kyc_tier (BVN = TIER1, BVN + NIN =
//     TIER2, BVN + NIN + utility bill = TIER3).
//
// Nothing uses Math.random(): every value comes from md5 of a fixed key, so a
// reload gives exactly the same documents.
// ---------------------------------------------------------------------------

const crypto = require('crypto');
const fs = require('fs');

db = db.getSiblingDB('valpay');

// ---- deterministic helpers -------------------------------------------------
const md5hex = (s) => crypto.createHash('md5').update(String(s)).digest('hex');
// same as ('x' || substr(md5(key), 1, 8))::bit(32)::bigint in PostgreSQL
const h32 = (s) => parseInt(md5hex(s).slice(0, 8), 16);
const pick = (arr, key) => arr[h32(key) % arr.length];
const DAY = 86400000, HOUR = 3600000, MIN = 60000, SEC = 1000;
const pad = (n, w) => String(n).padStart(w, '0');
const ymd = (d) => d.toISOString().slice(0, 10).replace(/-/g, '');

// ---- customers (mirrors scripts/seed.sql) ----------------------------------
const FN = ['Adaeze','Tunde','Ngozi','Emeka','Funke','Ibrahim','Aisha','Chinedu',
            'Bola','Kelechi','Yemi','Zainab','Obinna','Amaka','Segun','Halima',
            'Uche','Temitope','Musa','Ifeoma'];
const LN = ['Okafor','Adeyemi','Bello','Eze','Ogunleye','Abubakar','Nwosu','Balogun',
            'Okoro','Lawal','Ibe','Danjuma','Afolabi','Uzor','Ojo','Mohammed',
            'Chukwu','Adebayo','Usman'];

const customers = [
  { customer_id: 1, account_number: 'VP1000000001', full_name: 'Valentine Efagene', kyc_tier: 'TIER2',
    created_at: new Date('2026-08-08T10:00:00Z') },
  { customer_id: 2, account_number: 'VP1000000002', full_name: 'Chioma Okonkwo', kyc_tier: 'TIER2',
    created_at: new Date('2026-08-09T14:00:00Z') }
];
for (let i = 1; i <= 200; i++) {
  customers.push({
    customer_id: i + 3,
    idx: i,
    account_number: 'VP2' + pad(i, 9),
    full_name: FN[i % 20] + ' ' + LN[(i * 7) % 19],
    kyc_tier: i % 10 === 0 ? 'TIER3' : (i % 3 === 0 ? 'TIER1' : 'TIER2'),
    created_at: new Date(Date.UTC(2024, 5, 1, 9, 0, 0) + i * DAY + ((i * 37) % 600) * MIN)
  });
}
const byAccount = {};
customers.forEach((c) => { byAccount[c.account_number] = c; });
const bulkByIdx = (idx) => customers[idx + 1]; // idx 1-200 -> customer_id idx+3

// devices and home IP per customer
const IP_PREFIX = ['102.89', '105.112', '197.210', '129.205', '41.184', '102.90'];
const CHANNEL = ['android', 'android', 'android', 'ios', 'ios', 'web'];
customers.forEach((c) => {
  const k = 'cust:' + c.customer_id;
  c.primary_device = 'dev_' + md5hex(k + ':dev1').slice(0, 12);
  c.second_device = 'dev_' + md5hex(k + ':dev2').slice(0, 12);
  c.home_ip = pick(IP_PREFIX, k + ':ip') + '.' + (h32(k + ':o3') % 254 + 1) + '.' + (h32(k + ':o4') % 254 + 1);
  c.channel = pick(CHANNEL, k + ':ch');
  c.farm = (c.customer_id * 31) % 25 < 5 && c.customer_id > 3 ? (c.customer_id * 31) % 25 : null;
});
// five shared "device farm" fingerprints used by mule accounts and credential stuffing
const FARM = [0, 1, 2, 3, 4].map((k) => ({
  device_id: 'dev_' + md5hex('farm:' + k).slice(0, 12),
  ip: '185.220.101.' + (11 + k * 7)
}));

// ---- reset ------------------------------------------------------------------
['kyc_documents', 'activity_events', 'fraud_signals'].forEach((n) => db.getCollection(n).drop());

// ---- kyc_documents: validator = kyc_schema.json + one cross-field rule -------
const schemaPath = (typeof __dirname !== 'undefined' ? __dirname + '/' : '') + 'kyc_schema.json';
const kycSchema = JSON.parse(fs.readFileSync(schemaPath, 'utf8'));
db.createCollection('kyc_documents', {
  validator: {
    $and: [
      kycSchema,
      // a REJECTED document must say why ($jsonSchema has no if/then)
      { $or: [{ status: { $ne: 'REJECTED' } }, { 'metadata.rejection_reason': { $type: 'string' } }] }
    ]
  },
  validationLevel: 'strict',
  validationAction: 'error'
});

const REVIEWERS = ['compliance.agent01', 'compliance.agent02', 'compliance.agent03', 'kyc.auto'];
const REASONS = {
  NIN: ['name_mismatch', 'blurry_image', 'nin_not_found'],
  BVN: ['phone_mismatch', 'dob_mismatch'],
  PASSPORT: ['expired_document', 'blurry_image', 'glare_on_photo_page'],
  UTILITY_BILL: ['older_than_3_months', 'address_mismatch', 'blurry_image']
};
const DISCOS = ['IKEDC', 'EKEDC', 'AEDC', 'PHED', 'EEDC'];
const CITIES = [['Ikeja', 'Lagos'], ['Lekki', 'Lagos'], ['Yaba', 'Lagos'], ['Wuse', 'FCT'],
                ['Benin City', 'Edo'], ['Port Harcourt', 'Rivers'], ['Enugu', 'Enugu'], ['Ibadan', 'Oyo']];
const masked = (key) => '****' + pad(h32(key) % 10000, 4);

function metadataFor(c, type, key, status) {
  let m;
  if (type === 'NIN') {
    m = { masked_id: masked(key + ':id'), provider: 'NIMC', name_on_record: c.full_name,
          name_match_score: Number((0.86 + (h32(key + ':nm') % 14) / 100).toFixed(2)) };
  } else if (type === 'BVN') {
    m = { masked_id: masked(key + ':id'), provider: 'NIBSS', phone_match: true,
          date_of_birth_match: true };
  } else if (type === 'PASSPORT') {
    m = { masked_id: 'A' + masked(key + ':id').slice(4) + '***', issuing_country: 'NG',
          expiry_date: new Date(Date.UTC(2027 + (h32(key + ':exp') % 8), h32(key + ':m') % 12, 1)) };
  } else {
    const city = pick(CITIES, key + ':city');
    m = { provider: pick(DISCOS, key + ':disco'),
          bill_month: '2026-0' + (1 + (h32(key + ':bm') % 9)),
          address: { line1: (h32(key + ':no') % 120 + 1) + ' ' + pick(['Allen Avenue', 'Admiralty Way', 'Herbert Macaulay Way', 'Aminu Kano Crescent', 'Sapele Road', 'Aba Road'], key + ':st'),
                     city: city[0], state: city[1] } };
  }
  if (status === 'REJECTED') {
    m.rejection_reason = pick(REASONS[type], key + ':why');
    if (type !== 'BVN') { delete m.name_match_score; }
    if (m.rejection_reason === 'name_mismatch') m.name_match_score = 0.41;
  }
  return m;
}

const kyc = [];
function addDoc(c, type, status, submitted, attempt) {
  const key = c.customer_id + ':' + type + ':' + attempt;
  const d = {
    customer_id: NumberInt(c.customer_id),
    account_number: c.account_number,
    document_type: type,
    status: status,
    metadata: metadataFor(c, type, key, status),
    submitted_at: submitted
  };
  if (status !== 'PENDING') {
    d.reviewed_at = new Date(submitted.getTime() + (2 + h32(key + ':rv') % 46) * HOUR);
    d.reviewer = type === 'BVN' ? 'kyc.auto' : pick(REVIEWERS, key + ':who');
  }
  kyc.push(d);
}

// hand-made documents for customers 1 and 2 (match the original samples)
kyc.push({ customer_id: NumberInt(1), account_number: 'VP1000000001', document_type: 'BVN', status: 'VERIFIED',
  metadata: { masked_id: '****1187', provider: 'NIBSS', phone_match: true, date_of_birth_match: true },
  submitted_at: new Date('2026-08-08T10:15:00Z'), reviewed_at: new Date('2026-08-08T10:16:00Z'), reviewer: 'kyc.auto' });
kyc.push({ customer_id: NumberInt(1), account_number: 'VP1000000001', document_type: 'NIN', status: 'VERIFIED',
  metadata: { masked_id: '****4321', provider: 'NIMC', name_on_record: 'Valentine Efagene', name_match_score: 0.98 },
  submitted_at: new Date('2026-08-10T12:00:00Z'), reviewed_at: new Date('2026-08-10T15:40:00Z'), reviewer: 'compliance.agent02' });
kyc.push({ customer_id: NumberInt(2), account_number: 'VP1000000002', document_type: 'BVN', status: 'VERIFIED',
  metadata: { masked_id: '****8890', provider: 'NIBSS', phone_match: true, date_of_birth_match: true },
  submitted_at: new Date('2026-08-09T14:20:00Z'), reviewed_at: new Date('2026-08-09T14:21:00Z'), reviewer: 'kyc.auto' });
kyc.push({ customer_id: NumberInt(2), account_number: 'VP1000000002', document_type: 'NIN', status: 'VERIFIED',
  metadata: { masked_id: '****2045', provider: 'NIMC', name_on_record: 'Chioma Okonkwo', name_match_score: 0.95 },
  submitted_at: new Date('2026-08-12T08:05:00Z'), reviewed_at: new Date('2026-08-12T11:30:00Z'), reviewer: 'compliance.agent01' });
kyc.push({ customer_id: NumberInt(2), account_number: 'VP1000000002', document_type: 'UTILITY_BILL', status: 'PENDING',
  metadata: { provider: 'IKEDC', bill_month: '2026-09', address: { line1: '14 Allen Avenue', city: 'Ikeja', state: 'Lagos' } },
  submitted_at: new Date('2026-10-20T09:30:00Z') });

// bulk customers: verified documents for their tier, earlier rejected attempts,
// and recent upgrade requests still waiting in the review queue
customers.filter((c) => c.idx).forEach((c) => {
  const k = 'kyc:' + c.customer_id;
  const needed = c.kyc_tier === 'TIER3' ? ['BVN', 'NIN', 'UTILITY_BILL'] : c.kyc_tier === 'TIER2' ? ['BVN', 'NIN'] : ['BVN'];
  if (c.kyc_tier === 'TIER3' && c.idx % 20 === 0) needed.push('PASSPORT');
  let t = c.created_at.getTime() + (20 + h32(k + ':t0') % 180) * MIN;
  needed.forEach((type) => {
    if (type !== 'BVN' && h32(k + type + ':rej') % 6 === 0) {
      addDoc(c, type, 'REJECTED', new Date(t), 1);           // first attempt rejected
      t += (2 + h32(k + type + ':gap') % 9) * DAY;
      addDoc(c, type, 'VERIFIED', new Date(t), 2);           // resubmitted and accepted
    } else {
      addDoc(c, type, 'VERIFIED', new Date(t), 1);
    }
    t += (1 + h32(k + type + ':next') % 20) * DAY + (h32(k + type + ':min') % 600) * MIN;
  });
  // upgrade requests in October 2026
  const next = c.kyc_tier === 'TIER1' ? 'NIN' : c.kyc_tier === 'TIER2' ? 'UTILITY_BILL' : null;
  if (next && h32(k + ':upg') % 4 === 0) {
    const sub = new Date(Date.UTC(2026, 9, 1, 8) + (h32(k + ':upd') % (31 * 24 * 60)) * MIN);
    if (h32(k + ':upgrej') % 5 === 0) addDoc(c, next, 'REJECTED', sub, 9);
    else addDoc(c, next, 'PENDING', sub, 9);
  }
});
const kycRes = db.kyc_documents.insertMany(kyc, { ordered: true });

// ---- activity_events -----------------------------------------------------------
const ev = [];
function session(c, device, ip, ts, key, ch) {
  ch = ch || c.channel;
  // optional wrong PIN, login, OTP; returns nothing (pushes events)
  if (h32(key + ':lf') % 25 === 0) {
    ev.push({ event: 'login_failed', customer_id: NumberInt(c.customer_id), account_number: c.account_number,
              device_id: device, ip: ip, channel: ch, reason: 'wrong_pin', ts: new Date(ts - 4 * MIN) });
  }
  ev.push({ event: 'login_success', customer_id: NumberInt(c.customer_id), account_number: c.account_number,
            device_id: device, ip: ip, channel: ch, ts: new Date(ts - 3 * MIN) });
}
function ruleHit(c, device, ip, ts, rule, score, action, extra) {
  ev.push(Object.assign({ event: 'fraud_rule_hit', customer_id: NumberInt(c.customer_id), account_number: c.account_number,
    device_id: device, ip: ip, channel: c.channel, rule: rule, score: score, action: action, ts: new Date(ts) }, extra || {}));
}
const score = (key, lo) => Number((lo + (h32(key) % Math.round((0.99 - lo) * 100 + 1)) / 100).toFixed(2));

// 28,000 bulk transfers recomputed from seed.sql
const T0 = Date.UTC(2025, 0, 1);
for (let n = 1; n <= 40000; n++) {
  if (n % 20 >= 14) continue;                              // TOPUP / BILL_PAY rows
  const h1 = h32(n + ':from'), h2 = h32(n + ':to'), h3 = h32(n + ':amount'), h4 = h32(n + ':kobo');
  const fromIdx = (h1 % 200) + 1;
  const toIdx = (h2 % 199) + 1 >= fromIdx ? (h2 % 199) + 2 : (h2 % 199) + 1;
  const ts = T0 + Math.floor((n - 1) * 144504 / 100) * SEC + ((n * 7919) % 1200) * SEC;
  const created = new Date(ts);
  const amount = ((h3 % 2950) + 50) * 10 + (h4 % 100) / 100;
  const status = n % 1999 === 7 ? 'FAILED' : (n > 38000 && n % 151 === 5 ? 'PENDING' : 'SUCCESS');
  const reference = 'VP-TXN-' + ymd(created) + '-' + pad(n, 6);
  const c = bulkByIdx(fromIdx), to = bulkByIdx(toIdx);
  const k = 'txn:' + n;

  let device = c.primary_device, ip = c.home_ip, newDevice = false, farm = null;
  if (c.farm !== null && h32(k + ':farm') % 15 === 0) { farm = FARM[c.farm]; device = farm.device_id; ip = farm.ip; }
  else {
    const d = h32(k + ':dev') % 12;
    if (d === 0) { device = 'dev_' + md5hex(k + ':new').slice(0, 12); newDevice = true; }  // first use of a new phone or browser
    else if (d <= 2) device = c.second_device;                                           // known second device
  }

  let loginIp = ip;
  const travel = !farm && h32(k + ':trv') % 400 === 0;
  if (travel) loginIp = '81.2.69.' + (h32(k + ':uk') % 200 + 20);
  const ch = farm ? 'web' : c.channel;               // the farm drives accounts through a browser
  session(c, device, loginIp, ts, k, ch);
  if (travel) ruleHit(c, device, loginIp, ts - 3 * MIN + 2 * SEC, 'impossible_travel', score(k + ':s1', 0.70), 'STEP_UP', { channel: ch });

  ev.push({ event: 'otp_sent', customer_id: NumberInt(c.customer_id), account_number: c.account_number,
            device_id: device, ip: loginIp, channel: ch, otp_channel: h32(k + ':otp') % 5 === 0 ? 'email' : 'sms',
            purpose: 'transfer', ts: new Date(ts - 1 * MIN) });
  ev.push({ event: 'transfer_initiated', customer_id: NumberInt(c.customer_id), account_number: c.account_number,
            device_id: device, ip: loginIp, channel: ch, reference: reference, amount_ngn: amount,
            beneficiary: to.account_number, txn_status: status, ts: created });

  if (farm) ruleHit(c, device, loginIp, ts + 2 * SEC, 'shared_device_multi_account', score(k + ':s2', 0.72), 'STEP_UP', { channel: ch, reference: reference });
  else if (newDevice && amount >= 20000) ruleHit(c, device, loginIp, ts + 2 * SEC, 'new_device_high_value', score(k + ':s3', 0.55), h32(k + ':a3') % 3 === 0 ? 'STEP_UP' : 'ALLOW', { channel: ch, reference: reference, amount_ngn: amount });
  if (h32(k + ':vel') % 180 === 0) ruleHit(c, device, loginIp, ts + 3 * SEC, 'velocity_5_txn_1min', score(k + ':s4', 0.60), 'STEP_UP', { channel: ch, reference: reference });
}

// credential-stuffing bursts from the device farm: failed PINs then a block
for (let b = 0; b < 240; b++) {
  const k = 'burst:' + b;
  const c = bulkByIdx((h32(k + ':c') % 200) + 1);
  const farm = FARM[b % 5];
  const start = T0 + (h32(k + ':t') % (669 * 24 * 60)) * MIN;
  const tries = 4 + h32(k + ':n') % 3;
  for (let j = 0; j < tries; j++) {
    ev.push({ event: 'login_failed', customer_id: NumberInt(c.customer_id), account_number: c.account_number,
              device_id: farm.device_id, ip: farm.ip, channel: 'web', reason: 'wrong_pin', ts: new Date(start + j * 15 * SEC) });
  }
  ruleHit(c, farm.device_id, farm.ip, start + tries * 15 * SEC, 'failed_login_burst', score(k + ':s', 0.85), 'BLOCK', { channel: 'web', failed_attempts: tries });
}

// Valentine and Chioma: the seed.sql transfers and the Portfolio 3 demo transfer (VP-TXN-OK-004)
const V = customers[0], C2 = customers[1];
[[V, 'VP-TXN-20260915-002', 15000.00, C2, '2026-09-15T11:20:00Z'],
 [C2, 'VP-TXN-20261001-003', 5000.00, V, '2026-10-01T08:45:00Z'],
 [V, 'VP-TXN-OK-004', 2500.00, C2, '2026-10-28T07:05:00Z']].forEach(([c, ref, amt, to, iso]) => {
  const ts = new Date(iso).getTime();
  session(c, c.primary_device, c.home_ip, ts, 'hand:' + ref);
  ev.push({ event: 'otp_sent', customer_id: NumberInt(c.customer_id), account_number: c.account_number,
            device_id: c.primary_device, ip: c.home_ip, channel: c.channel, otp_channel: 'sms', purpose: 'transfer', ts: new Date(ts - MIN) });
  ev.push({ event: 'transfer_initiated', customer_id: NumberInt(c.customer_id), account_number: c.account_number,
            device_id: c.primary_device, ip: c.home_ip, channel: c.channel, reference: ref, amount_ngn: amt,
            beneficiary: to.account_number, txn_status: 'SUCCESS', ts: new Date(ts) });
});

// insert in time order, in batches
ev.sort((a, b) => a.ts - b.ts);
for (let i = 0; i < ev.length; i += 10000) db.activity_events.insertMany(ev.slice(i, i + 10000), { ordered: false });

// ---- fraud_signals: built from activity_events with aggregation + $merge --------
// 1) one case document per rule hit
const NOW = new Date('2026-11-01T00:00:00Z');
db.activity_events.aggregate([
  { $match: { event: 'fraud_rule_hit' } },
  { $project: {
      _id: 0, signal_type: 'RULE_HIT', source_event_id: '$_id', customer_id: 1, account_number: 1,
      device_id: 1, ip: 1, rule: 1, score: 1, action: 1, reference: 1, detected_at: '$ts',
      case_status: { $switch: { branches: [
        { case: { $gte: ['$ts', new Date(NOW.getTime() - 21 * DAY)] }, then: 'OPEN' },
        { case: { $in: ['$rule', ['shared_device_multi_account', 'failed_login_burst']] }, then: 'CONFIRMED_FRAUD' },
        { case: { $gte: ['$score', 0.9] }, then: 'CONFIRMED_FRAUD' } ], default: 'CLOSED_FALSE_POSITIVE' } } } },
  { $merge: { into: 'fraud_signals', whenMatched: 'fail', whenNotMatched: 'insert' } }
]);
// 2) one fingerprint summary per device seen on more than one customer or with any rule hit
db.activity_events.aggregate([
  { $group: {
      _id: '$device_id',
      customers: { $addToSet: '$customer_id' },
      ips: { $addToSet: '$ip' },
      events: { $sum: 1 },
      failed_logins: { $sum: { $cond: [{ $eq: ['$event', 'login_failed'] }, 1, 0] } },
      rule_hits: { $sum: { $cond: [{ $eq: ['$event', 'fraud_rule_hit'] }, 1, 0] } },
      max_score: { $max: '$score' },
      first_seen: { $min: '$ts' }, last_seen: { $max: '$ts' } } },
  { $match: { $or: [{ 'customers.1': { $exists: true } }, { rule_hits: { $gt: 0 } }] } },
  { $project: {
      _id: { $concat: ['device:', '$_id'] }, signal_type: 'DEVICE_SUMMARY', device_id: '$_id',
      customer_count: { $size: '$customers' }, customers: { $sortArray: { input: '$customers', sortBy: 1 } },
      ip_count: { $size: '$ips' }, events: 1, failed_logins: 1, rule_hits: 1, max_score: 1, first_seen: 1, last_seen: 1,
      // simple, explainable risk score: shared devices and repeated hits weigh most
      risk_score: { $round: [{ $min: [1, { $add: [
        { $multiply: [{ $ifNull: ['$max_score', 0] }, 0.5] },
        { $multiply: [{ $min: [{ $subtract: [{ $size: '$customers' }, 1] }, 10] }, 0.04] },
        { $multiply: [{ $min: ['$rule_hits', 20] }, 0.005] } ] }] }, 2] } } },
  { $merge: { into: 'fraud_signals', whenMatched: 'replace', whenNotMatched: 'insert' } }
]);

// ---- indexes ----------------------------------------------------------------------
db.kyc_documents.createIndex({ customer_id: 1, document_type: 1, submitted_at: -1 }, { name: 'customer_doc_latest' });
db.kyc_documents.createIndex({ submitted_at: 1 }, { name: 'pending_review_queue', partialFilterExpression: { status: 'PENDING' } });
db.kyc_documents.createIndex({ status: 1, document_type: 1 }, { name: 'status_doc_type' });

db.activity_events.createIndex({ customer_id: 1, ts: -1 }, { name: 'customer_timeline' });
db.activity_events.createIndex({ event: 1, ts: -1 }, { name: 'event_time' });
db.activity_events.createIndex({ device_id: 1, ts: -1 }, { name: 'device_time' });
db.activity_events.createIndex({ reference: 1 }, { name: 'txn_reference', sparse: true });   // only transfer and rule-hit events carry a reference
// NDPA-style retention: events expire 3 years after ts (nothing in this data set is old enough yet)
db.activity_events.createIndex({ ts: 1 }, { name: 'retention_ttl_3y', expireAfterSeconds: 3 * 365 * 24 * 3600 });

db.fraud_signals.createIndex({ signal_type: 1, risk_score: -1 }, { name: 'type_risk' });
db.fraud_signals.createIndex({ signal_type: 1, case_status: 1, detected_at: -1 }, { name: 'case_queue' });
db.fraud_signals.createIndex({ customer_id: 1, detected_at: -1 }, { name: 'customer_cases', partialFilterExpression: { signal_type: 'RULE_HIT' } });

// ---- load summary -----------------------------------------------------------------
print('=== ValPay MongoDB seed (database: valpay, MongoDB ' + db.version() + ') ===');
print('Customers covered: ' + db.kyc_documents.distinct('customer_id').length + ' (customer_id 1, 2 and 4-203; 3 is the ops wallet)');
print('');
['kyc_documents', 'activity_events', 'fraud_signals'].forEach((n) => {
  print(n.padEnd(16) + String(db.getCollection(n).countDocuments()).padStart(7) + ' documents');
});
print('');
print('activity_events by event:');
db.activity_events.aggregate([{ $group: { _id: '$event', n: { $sum: 1 } } }, { $sort: { n: -1, _id: 1 } }])
  .forEach((r) => print('  ' + r._id.padEnd(20) + String(r.n).padStart(7)));
const span = db.activity_events.aggregate([{ $group: { _id: null, first: { $min: '$ts' }, last: { $max: '$ts' } } }]).toArray()[0];
print('  time span: ' + span.first.toISOString() + ' to ' + span.last.toISOString());
print('');
print('kyc_documents by status:');
db.kyc_documents.aggregate([{ $group: { _id: '$status', n: { $sum: 1 } } }, { $sort: { _id: 1 } }])
  .forEach((r) => print('  ' + r._id.padEnd(20) + String(r.n).padStart(7)));
print('');
print('fraud_signals by signal_type:');
db.fraud_signals.aggregate([{ $group: { _id: '$signal_type', n: { $sum: 1 } } }, { $sort: { _id: 1 } }])
  .forEach((r) => print('  ' + r._id.padEnd(20) + String(r.n).padStart(7)));
print('');
print('Indexes:');
['kyc_documents', 'activity_events', 'fraud_signals'].forEach((n) => {
  db.getCollection(n).getIndexes().forEach((ix) => {
    const opts = [];
    if (ix.partialFilterExpression) opts.push('partial ' + JSON.stringify(ix.partialFilterExpression));
    if (ix.expireAfterSeconds !== undefined) opts.push('TTL ' + ix.expireAfterSeconds + 's');
    if (ix.sparse) opts.push('sparse');
    print('  ' + n + '.' + ix.name + ' ' + JSON.stringify(ix.key) + (opts.length ? '  ' + opts.join(', ') : ''));
  });
});
print('');
print('kyc_documents validator (from kyc_schema.json plus the REJECTED rule):');
printjson(db.getCollectionInfos({ name: 'kyc_documents' })[0].options);
