// ValPay Portfolio 4: schema validation evidence for kyc_documents
// The validator is kyc_schema.json plus one rule: REJECTED needs metadata.rejection_reason.
// Run after seed.mongodb.js:  mongosh "mongodb://localhost:27017/valpay" --file validation.mongodb.js
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

const before = db.kyc_documents.countDocuments();
print('kyc_documents before tests: ' + before);

function attempt(label, doc) {
  print('');
  print('=== ' + label + ' ===');
  print(wrapLine('Document: ' + EJSON.stringify(doc, { relaxed: true }), 130));
  try {
    const r = db.kyc_documents.insertOne(doc);
    print('Result: ACCEPTED');
    return r.insertedId;
  } catch (e) {
    print('Result: REJECTED, code ' + e.code + ' (' + (e.codeName || 'DocumentValidationFailure') + '): ' + e.errmsg);
    // keep only the useful part of errInfo.details
    const d = e.errInfo && e.errInfo.details;
    if (d) print('Why: ' + JSON.stringify(d.schemaRulesNotSatisfied || d, null, 2));
    return null;
  }
}

const base = { customer_id: NumberInt(57), account_number: 'VP2000000054', document_type: 'PASSPORT', status: 'PENDING',
               metadata: { masked_id: 'A1234***', issuing_country: 'NG' }, submitted_at: ISODate('2026-11-01T09:00:00Z') };

attempt('V1. Unknown document type (DRIVERS_LICENCE)', Object.assign({}, base, { document_type: 'DRIVERS_LICENCE' }));
attempt('V2. Old string customer id and a missing submitted_at', (({ submitted_at, ...rest }) => Object.assign(rest, { customer_id: 'cust_valentine' }))(base));
attempt('V3. Account number not in the VP + 10 digits format', Object.assign({}, base, { account_number: '0123456789' }));
attempt('V4. REJECTED without a rejection_reason', Object.assign({}, base, { status: 'REJECTED', reviewer: 'compliance.agent01', reviewed_at: ISODate('2026-11-01T12:00:00Z') }));
const id = attempt('V5. Valid PASSPORT submission (accepted, then removed)', base);

if (id) db.kyc_documents.deleteOne({ _id: id });
print('');
print('kyc_documents after tests: ' + db.kyc_documents.countDocuments() + ' (test document removed)');
