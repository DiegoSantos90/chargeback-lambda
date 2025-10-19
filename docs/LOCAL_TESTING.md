# Local Testing Guide - Chargeback Lambda

## 📋 Problem Identified

### What was happening?
The SAM Lambda Runtime **did not automatically inherit** AWS credentials from the host environment or `env.json` file. When the Lambda tried to access DynamoDB Local, the AWS SDK inside the container could not find valid credentials.

### Symptom:
```
ResourceNotFoundException: Cannot do operations on a non-existent table
```

### Root Cause:
1. Lambda Runtime runs in an isolated Docker container
2. AWS credentials are not automatically injected into the container
3. AWS SDK uses the "default credential chain" which fails in local environment
4. DynamoDB Local **always requires credentials** (even if they are dummy)

---

## ✅ Solution Implemented

### 1. Separate Templates

**`template.yaml`** - For production (AWS)
- No hardcoded credentials
- Uses IAM Roles in AWS environment
- Table name: `chargebacks` (production)

**`template.local.yaml`** - For local testing
- Dummy credentials explicitly configured
- DynamoDB Local endpoint configured
- Table name: `chargebacks-lambda` (local)

---

## 🚀 How to Run Local Tests

### Prerequisites

1. **DynamoDB Local running:**
```bash
docker run -d -p 8000:8000 --name dynamodb-local amazon/dynamodb-local
```

2. **Create local table:**
```bash
AWS_ACCESS_KEY_ID=dummy AWS_SECRET_ACCESS_KEY=dummy \
aws dynamodb create-table \
  --table-name chargebacks-lambda \
  --endpoint-url http://localhost:8000 \
  --region us-east-1 \
  --attribute-definitions \
    AttributeName=id,AttributeType=S \
    AttributeName=transaction_id,AttributeType=S \
    AttributeName=merchant_id,AttributeType=S \
    AttributeName=status,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --global-secondary-indexes \
    "[
      {
        \"IndexName\": \"transaction-id-index\",
        \"KeySchema\": [{\"AttributeName\":\"transaction_id\",\"KeyType\":\"HASH\"}],
        \"Projection\": {\"ProjectionType\":\"ALL\"}
      },
      {
        \"IndexName\": \"merchant-id-index\",
        \"KeySchema\": [{\"AttributeName\":\"merchant_id\",\"KeyType\":\"HASH\"}],
        \"Projection\": {\"ProjectionType\":\"ALL\"}
      },
      {
        \"IndexName\": \"status-index\",
        \"KeySchema\": [{\"AttributeName\":\"status\",\"KeyType\":\"HASH\"}],
        \"Projection\": {\"ProjectionType\":\"ALL\"}
      }
    ]"
```

3. **Compile the Lambda:**
```bash
make build
```

### Run SAM Local

```bash
# Use LOCAL template (with dummy credentials)
sam local start-api --template template.local.yaml --log-file /tmp/sam.log
```

### Test Endpoints

**Health Check:**
```bash
curl http://localhost:3000/health
```

**Create Chargeback:**
```bash
curl -X POST http://localhost:3000/chargebacks \
  -H "Content-Type: application/json" \
  -d '{
    "transaction_id": "TXN-001",
    "merchant_id": "MERCH-123",
    "amount": 100.50,
    "currency": "USD",
    "card_number": "****1234",
    "reason": "fraud",
    "description": "Test chargeback",
    "transaction_date": "2025-01-15T10:30:00Z"
  }'
```

**Verify data in DynamoDB:**
```bash
AWS_ACCESS_KEY_ID=dummy AWS_SECRET_ACCESS_KEY=dummy \
aws dynamodb scan \
  --table-name chargebacks-lambda \
  --endpoint-url http://localhost:8000 \
  --region us-east-1
```

---

## 🔧 Troubleshooting

### 1. Error: "Cannot do operations on a non-existent table"

**Cause:** AWS credentials are not being injected into the Lambda container

**Solution:**
- ✅ Use `template.local.yaml` instead of `template.yaml`
- ✅ Verify that `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` variables are in the template

### 2. Error: "Connection refused"

**Cause:** Lambda container cannot access DynamoDB Local

**Connectivity test:**
```bash
docker run --rm alpine sh -c "apk add -q curl && curl http://host.docker.internal:8000"
```

**Solution:**
- ✅ Use `host.docker.internal:8000` in endpoint (not `localhost:8000`)
- ✅ Verify DynamoDB Local is running: `docker ps | grep dynamodb`

### 3. Error: "Validation errors"

**Cause:** Incomplete or invalid payload

**Required fields:**
- `transaction_id` (string)
- `merchant_id` (string)
- `amount` (number > 0)
- `currency` (string)
- `card_number` (string)
- `reason` (enum: fraud, authorization_error, processing_error, consumer_dispute)
- `transaction_date` (ISO 8601 datetime)

---

## 📊 Coverage Verification

```bash
make test-coverage
```

---

## 🔐 Security

### ⚠️ IMPORTANT:

1. **NEVER** commit `template.local.yaml` with real credentials
2. "dummy" credentials are **only for local testing**
3. In production, use **IAM Roles** (no hardcoded credentials)
4. The `template.yaml` file (production) should not contain credentials

### Production Configuration:

In production (AWS), add an IAM Role to the Lambda:

```yaml
Resources:
  ChargebackApiFunction:
    Type: AWS::Serverless::Function
    Properties:
      # ... other configs
      Policies:
        - DynamoDBCrudPolicy:
            TableName: chargebacks
```

---

## 📝 Local Testing Checklist

- [ ] DynamoDB Local running (`docker ps`)
- [ ] Table `chargebacks-lambda` created
- [ ] Lambda compiled (`make build`)
- [ ] SAM running with `template.local.yaml`
- [ ] Health check returns 200 OK
- [ ] POST /chargebacks creates record
- [ ] Data appears in DynamoDB scan
- [ ] Logs without errors (`tail -f /tmp/sam.log`)

---

## 🎯 Solution Summary

| Aspect | Problem | Solution |
|---------|----------|---------|
| **Credentials** | Not injected into container | Added to `template.local.yaml` |
| **Endpoint** | `localhost` doesn't work in container | Use `host.docker.internal:8000` |
| **Templates** | Single template for local and prod | Separated: `template.yaml` and `template.local.yaml` |
| **Security** | Risk of committing credentials | Separate local template, production uses IAM |

---

**Created:** October 19, 2025  
**Problem solved:** ResourceNotFoundException in local tests  
**Status:** ✅ Validated and working
