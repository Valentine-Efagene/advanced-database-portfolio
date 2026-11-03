// ValPay Portfolio 4: index evidence with explain('executionStats')
// Each test drops the collection's secondary indexes, explains the query
// (COLLSCAN), creates only the index under test and explains again (IXSCAN),
// then restores every index exactly as seed.mongodb.js created it.
// Run after seed.mongodb.js:  mongosh "mongodb://localhost:27017/valpay" --file explain.mongodb.js
db = db.getSiblingDB('valpay');

function stages(p) {
  // flatten the winning plan into "STAGE(index) <- STAGE ..." from top to bottom
  const out = [];
  while (p) {
    out.push(p.stage + (p.indexName ? '(' + p.indexName + ')' : ''));
    p = p.inputStage || (p.inputStages ? p.inputStages[0] : null);
  }
  return out.join(' <- ');
}
function report(label, cursor) {
  const ex = cursor.explain('executionStats');
  const qp = ex.queryPlanner.winningPlan.queryPlan || ex.queryPlanner.winningPlan;
  const es = ex.executionStats;
  print('  ' + label);
  print('    winning plan       : ' + stages(qp));
  print('    nReturned          : ' + es.nReturned);
  print('    totalKeysExamined  : ' + es.totalKeysExamined);
  print('    totalDocsExamined  : ' + es.totalDocsExamined);
  print('    executionTimeMillis: ' + es.executionTimeMillis);
  return es;
}
function test(title, coll, indexName, run) {
  const c = db.getCollection(coll);
  const specs = c.getIndexes().filter((ix) => ix.name !== '_id_');
  const spec = specs.find((ix) => ix.name === indexName);
  const opts = {};
  ['name', 'sparse', 'partialFilterExpression', 'expireAfterSeconds'].forEach((k) => { if (spec[k] !== undefined) opts[k] = spec[k]; });
  print('');
  print('=== ' + title + ' ===');
  print('Collection: ' + coll + ' (' + c.countDocuments() + ' documents)');
  print('Index under test: ' + indexName + ' ' + JSON.stringify(spec.key) +
        (spec.sparse ? ' sparse' : '') + (spec.partialFilterExpression ? ' partial ' + JSON.stringify(spec.partialFilterExpression) : ''));
  // baseline: only the mandatory _id index, so no other index can help
  c.dropIndexes();
  const before = report('BEFORE (only _id index)', run());
  c.createIndex(spec.key, opts);
  const after = report('AFTER (' + indexName + ' created)', run());
  print('  Docs examined: ' + before.totalDocsExamined + ' -> ' + after.totalDocsExamined +
        ' (' + (before.totalDocsExamined / Math.max(after.totalDocsExamined, 1)).toFixed(0) + 'x fewer)');
  // put every other index back exactly as seed.mongodb.js created it
  specs.filter((ix) => ix.name !== indexName).forEach((ix) => {
    const o = {};
    ['name', 'sparse', 'partialFilterExpression', 'expireAfterSeconds'].forEach((k) => { if (ix[k] !== undefined) o[k] = ix[k]; });
    c.createIndex(ix.key, o);
  });
}

// E1. Customer timeline (queries.mongodb.js Q5)
test('E1. Customer timeline: customer_id 57, latest 20 events', 'activity_events',
  'customer_timeline',
  () => db.activity_events.find({ customer_id: 57 }).sort({ ts: -1 }).limit(20));

// E2. Transfers in a 7-day window (queries.mongodb.js Q6)
test('E2. transfer_initiated events, 1-7 October 2026', 'activity_events',
  'event_time',
  () => db.activity_events.find({ event: 'transfer_initiated',
    ts: { $gte: ISODate('2026-10-01T00:00:00Z'), $lt: ISODate('2026-10-08T00:00:00Z') } }));

// E3. Trace one ledger reference (queries.mongodb.js Q11)
test('E3. Trace reference VP-TXN-20261026-039684', 'activity_events',
  'txn_reference',
  () => db.activity_events.find({ reference: 'VP-TXN-20261026-039684' }));

// E4. KYC review queue on the partial index (queries.mongodb.js Q1)
test('E4. KYC review queue: PENDING, oldest first', 'kyc_documents',
  'pending_review_queue',
  () => db.kyc_documents.find({ status: 'PENDING' }).sort({ submitted_at: 1 }));

// The partial index only holds PENDING documents...
print('');
print('=== Partial index coverage ===');
print('  pending_review_queue indexes ' + db.kyc_documents.countDocuments({ status: 'PENDING' }) +
      ' of ' + db.kyc_documents.countDocuments() + ' kyc_documents (status PENDING only)');
// ...and the planner will not use it for other statuses
print('');
print('=== The partial index is not used for VERIFIED documents ===');
report('status VERIFIED sorted by submitted_at', db.kyc_documents.find({ status: 'VERIFIED' }).sort({ submitted_at: 1 }));
