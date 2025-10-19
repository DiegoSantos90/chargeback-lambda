# 🚀 **Chargeback API - Lambda Function**# Chargeback API



Serverless version of the Chargeback API using AWS Lambda, designed for high scalability and cost efficiency.A robust and scalable REST API for managing chargeback operations, built with Go using Clean Architecture principles and Test-Driven Development (TDD).



## 🏗️ **Architecture**## 🚀 Features



```- **Clean Architecture**: Modular design with clear separation of concerns

API Gateway → Lambda Function → DynamoDB- **Domain-Driven Design**: Rich domain entities with business logic encapsulation

     ↓- **RESTful API**: HTTP handlers with comprehensive validation

CloudWatch Logs & X-Ray Tracing- **AWS DynamoDB Integration**: Scalable NoSQL database with optimized queries

```- **Comprehensive Testing**: 56% test coverage with unit and integration tests

- **Configuration Management**: Environment-based configuration with sensible defaults

**Key Components:**- **CORS Support**: Cross-origin resource sharing enabled

- **AWS Lambda** - Serverless compute- **Graceful Shutdown**: Proper signal handling and resource cleanup

- **API Gateway** - HTTP API routing  

- **DynamoDB** - NoSQL database## 🏗️ Architecture

- **CloudWatch** - Logging and monitoring

- **X-Ray** - Distributed tracing```

cmd/

## 🎯 **Features**├── api/                    # Application entry point

└── main.go                # Main application with dependency injection

- ✅ **Serverless** - No infrastructure management

- ✅ **Auto-scaling** - Handles traffic spikes automaticallyinternal/

- ✅ **Cost-effective** - Pay only for requests├── domain/                # Domain layer (business logic)

- ✅ **High availability** - Multi-AZ by default│   ├── entity/            # Domain entities

- ✅ **Structured logging** - JSON logs in CloudWatch│   └── repository/        # Repository interfaces

- ✅ **API validation** - Request/response validation├── usecase/               # Application layer (use cases)

- ✅ **Error handling** - Proper HTTP status codes├── infra/                 # Infrastructure layer

│   ├── db/               # Database configuration

## 🛠️ **Development**│   └── repository/       # Repository implementations

├── api/                   # Interface layer

### **Prerequisites**│   └── http/             # HTTP handlers

- Go 1.25+└── server/               # Server configuration

- AWS CLI configured```

- Docker (for local DynamoDB)

- SAM CLI (optional, for local testing)## 📋 Prerequisites



### **Local Development**- Go 1.21 or higher

```bash- AWS CLI configured (for DynamoDB)

# Start local DynamoDB- Docker (optional, for local DynamoDB)

make setup-local-db

## 🛠️ Installation

# Create table

make create-table1. **Clone the repository**

   ```bash

# Run HTTP server for development   git clone https://github.com/DiegoSantos90/chargeback-api.git

make dev   cd chargeback-api

   ```

# Run tests

make test2. **Install dependencies**

   ```bash

# Run integration tests   go mod download

./scripts/test_api.sh   ```

```

3. **Set up environment variables**

### **Lambda Development**   ```bash

```bash   export PORT=8080

# Build Lambda deployment package   export AWS_REGION=us-east-1

make build-lambda   export DYNAMODB_TABLE=chargebacks

   # For local development

# Test Lambda locally with SAM   export DYNAMODB_ENDPOINT=http://localhost:8000

make test-lambda   ```



# Deploy to AWS4. **Configure AWS Credentials**

make deploy-lambda   

```   The application supports multiple ways to configure AWS credentials:



## 📦 **Deployment**   **Option 1: Environment Variables (Local Development)**

   ```bash

### **Quick Deploy**   export AWS_ACCESS_KEY_ID=your-access-key

```bash   export AWS_SECRET_ACCESS_KEY=your-secret-key

# Build and deploy   export AWS_SESSION_TOKEN=your-session-token  # Optional for temporary credentials

make build-lambda   ```

make deploy-lambda

```   **Option 2: AWS Profile (Local Development)**

   ```bash

## 🧪 **Testing**   export AWS_PROFILE=your-profile-name

   ```

### **API Tests**

```bash   **Option 3: IAM Roles (Production - Recommended)**

# Local testing   - For EC2: Attach an IAM role to your EC2 instance

./scripts/test_api.sh   - For ECS/Fargate: Use task roles

   - For Lambda: Function execution role

# Lambda testing   - No environment variables needed - automatic credential detection

make test-lambda

```   **Option 4: DynamoDB Local (Local Development)**

   ```bash

## 📊 **API Endpoints**   export DYNAMODB_ENDPOINT=http://localhost:8000

   # When using local DynamoDB, dummy credentials are automatically used

### **Health Check**   ```

```bash

GET /health   **Copy example environment file:**

```   ```bash

   cp .env.example .env

### **Create Chargeback**   # Edit .env with your configuration

```bash   ```

POST /chargebacks

Content-Type: application/json## 🚀 Quick Start



{### Local Development with DynamoDB Local

  "transaction_id": "txn_123456789",

  "merchant_id": "merchant_001", 1. **Start DynamoDB Local**

  "amount": 99.99,   ```bash

  "currency": "USD",   docker run -p 8000:8000 amazon/dynamodb-local

  "card_number": "4111111111111111",   ```

  "reason": "fraud",

  "description": "Unauthorized transaction",2. **Create DynamoDB table**

  "transaction_date": "2025-10-19T10:30:00Z"   ```bash

}   aws dynamodb create-table \

```     --table-name chargebacks \

     --attribute-definitions \

**Valid Reasons:** `fraud`, `authorization_error`, `processing_error`, `consumer_dispute`       AttributeName=id,AttributeType=S \

       AttributeName=transaction_id,AttributeType=S \

## 📚 **Related Repositories**       AttributeName=merchant_id,AttributeType=S \

       AttributeName=status,AttributeType=S \

- [chargeback-api](https://github.com/DiegoSantos90/chargeback-api) - HTTP Server version     --key-schema \

       AttributeName=id,KeyType=HASH \

## 📄 **License**     --global-secondary-indexes \

       IndexName=transaction-id-index,KeySchema=[{AttributeName=transaction_id,KeyType=HASH}],Projection={ProjectionType=ALL},BillingMode=PAY_PER_REQUEST \

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.       IndexName=merchant-id-index,KeySchema=[{AttributeName=merchant_id,KeyType=HASH}],Projection={ProjectionType=ALL},BillingMode=PAY_PER_REQUEST \

       IndexName=status-index,KeySchema=[{AttributeName=status,KeyType=HASH}],Projection={ProjectionType=ALL},BillingMode=PAY_PER_REQUEST \

---     --billing-mode PAY_PER_REQUEST \

     --endpoint-url http://localhost:8000

**Built with ❤️ for serverless architecture**   ```

3. **Run the application**
   ```bash
   make run
   # or
   go run cmd/api/main.go
   ```

## 🧪 Testing

### Run All Tests
```bash
make test
```

### Run Tests with Coverage
```bash
make test-coverage
```

### Run Specific Test Suites
```bash
# Domain layer tests
make test-domain

# Infrastructure tests  
make test-infra

# Integration tests
make test-integration
```

### Test Coverage Report
After running `make test-coverage`, open `coverage/coverage.html` in your browser to view the detailed coverage report.

## 📖 API Documentation

### Endpoints

#### Create Chargeback
```http
POST /api/v1/chargebacks
Content-Type: application/json

{
  "transaction_id": "txn_123456789",
  "merchant_id": "merchant_abc123",
  "amount": 99.99,
  "currency": "USD",
  "card_number": "4111111111111111",
  "reason": "fraud",
  "description": "Unauthorized transaction"
}
```

#### Response
```http
HTTP/1.1 201 Created
Content-Type: application/json

{
  "id": "cb_1634567890123456789",
  "transaction_id": "txn_123456789",
  "merchant_id": "merchant_abc123",
  "amount": 99.99,
  "currency": "USD",
  "card_number": "****-****-****-1111",
  "reason": "fraud",
  "status": "pending",
  "description": "Unauthorized transaction",
  "transaction_date": "2023-10-15T10:30:00Z",
  "chargeback_date": "2023-10-15T12:00:00Z",
  "created_at": "2023-10-15T12:00:00Z",
  "updated_at": "2023-10-15T12:00:00Z"
}
```

#### Health Check
```http
GET /health

HTTP/1.1 200 OK
Content-Type: application/json

{
  "status": "healthy",
  "timestamp": "2023-10-15T12:00:00Z"
}
```

### Chargeback Reasons
- `fraud` - Fraudulent transaction
- `duplicate` - Duplicate charge
- `subscription` - Subscription-related dispute
- `product_not_received` - Product or service not received
- `credit_not_processed` - Credit not processed

### Chargeback Status
- `pending` - Initial state
- `approved` - Chargeback approved
- `rejected` - Chargeback rejected

## 🏭 Production Deployment

### Environment Variables
```bash
# Required
PORT=8080
AWS_REGION=us-east-1
DYNAMODB_TABLE=chargebacks

# Optional (for local development)
DYNAMODB_ENDPOINT=http://localhost:8000
```

### AWS Deployment
1. **Create DynamoDB table** in your AWS account
2. **Configure IAM permissions** for DynamoDB access
3. **Deploy using your preferred method**:
   - AWS Lambda + API Gateway
   - ECS/Fargate
   - EC2
   - AWS App Runner

### Docker
```bash
# Build image
docker build -t chargeback-api .

# Run container
docker run -p 8080:8080 \
  -e AWS_REGION=us-east-1 \
  -e DYNAMODB_TABLE=chargebacks \
  chargeback-api
```

## 🧪 Development

### Make Commands
```bash
make build          # Build the application
make run            # Run the application locally
make test           # Run all tests
make test-coverage  # Run tests with coverage report
make test-domain    # Run domain layer tests
make test-infra     # Run infrastructure tests
make clean          # Clean build artifacts
make help           # Show available commands
```

### Code Quality
- **Linting**: Uses `golangci-lint` for code analysis
- **Testing**: Comprehensive test suite with mocks
- **Coverage**: Minimum 50% test coverage maintained
- **Documentation**: Extensive inline documentation

## 📊 Monitoring and Observability

### Metrics
- Request/response metrics
- Database operation metrics
- Error rates and latencies

### Logging
- Structured logging with contextual information
- Request tracing
- Error tracking

### Health Checks
- `/health` endpoint for application health
- Database connectivity checks

## 🔒 Security

- **Input Validation**: Comprehensive request validation
- **Card Number Masking**: PCI compliance for sensitive data
- **CORS Configuration**: Secure cross-origin requests
- **Environment Secrets**: Secure configuration management

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Authors

- **Diego Santos** - *Initial work* - [@DiegoSantos90](https://github.com/DiegoSantos90)

## 🙏 Acknowledgments

- Clean Architecture principles by Robert C. Martin
- AWS SDK for Go team
- Go community for excellent tooling
