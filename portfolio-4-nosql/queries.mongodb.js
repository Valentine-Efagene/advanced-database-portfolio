// ValPay — mongosh examples
db = db.getSiblingDB('valpay');

db.createCollection('kyc_documents', {
  validator: { $jsonSchema: { required: ['customer_id', 'document_type', 'status'] } }
});
db.kyc_documents.createIndex({ customer_id: 1, document_type: 1 });
db.activity_events.createIndex({ customer_id: 1, ts: -1 });
db.activity_events.createIndex({ event: 1, ts: -1 });

print('Pending KYC reviews');
printjson(db.kyc_documents.find({ status: 'PENDING' }).toArray());

print('Transfer events last 24h (sample filter)');
printjson(db.activity_events.find({ event: 'transfer_initiated' }).toArray());

print('Fraud rule aggregation');
printjson(db.activity_events.aggregate([
  { $match: { event: 'fraud_rule_hit' } },
  { $group: { _id: '$rule', hits: { $sum: 1 }, avg_score: { $avg: '$score' } } }
]).toArray());
