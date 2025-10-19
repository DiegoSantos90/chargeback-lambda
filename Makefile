# Makefile for Chargeback Lambda Function

.PHONY: test test-coverage test-internal test-unit test-integration test-domain test-infra clean lint fmt vet deps help build-lambda deploy-lambda test-lambda-local start-sam stop-sam

# Build configuration
APP_NAME=chargeback-lambda
BUILD_DIR=bin
COVERAGE_DIR=coverage
LAMBDA_ZIP=lambda-function.zip
FUNCTION_NAME=chargeback-api

# Go test configuration
INTERNAL_PACKAGES=./internal/...
UNIT_PACKAGES=./internal/domain/... ./internal/usecase/...
INTEGRATION_PACKAGES=./internal/infra/...
DOMAIN_PACKAGES=./internal/domain/...
INFRA_PACKAGES=./internal/infra/...

# Default target
help: ## Show this help message
	@echo "🚀 Chargeback Lambda - Available targets:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Clean
clean: ## Clean build artifacts and coverage reports
	@echo "🧹 Cleaning..."
	@rm -rf $(BUILD_DIR) $(COVERAGE_DIR) *.out *.html $(LAMBDA_ZIP)
	@echo "✅ Clean complete"

# Dependencies
deps: ## Download and tidy dependencies
	@echo "📦 Downloading dependencies..."
	@go mod download
	@go mod tidy
	@echo "✅ Dependencies updated"

mod-tidy: ## Tidy go modules
	@echo "📦 Tidying modules..."
	@go mod tidy

# Code quality
fmt: ## Format Go code
	@echo "🎨 Formatting code..."
	@go fmt ./...
	@echo "✅ Code formatted"

vet: ## Run go vet
	@echo "🔍 Running go vet..."
	@go vet ./...
	@echo "✅ Vet complete"

lint: ## Run golangci-lint (requires golangci-lint to be installed)
	@echo "🔍 Running linter..."
	@golangci-lint run || echo "⚠️  Install golangci-lint: https://golangci-lint.run/usage/install/"

check: fmt vet lint test ## Run all quality checks

# Tests
test: ## Run all tests
	@echo "🧪 Running all tests..."
	@go test -v ./...

test-internal: ## Run tests only for internal packages (excluding examples)
	@echo "🧪 Running internal tests..."
	@go test -v $(INTERNAL_PACKAGES)

test-unit: ## Run unit tests (domain + usecase)
	@echo "🧪 Running unit tests..."
	@go test -v $(UNIT_PACKAGES)

test-integration: ## Run integration tests (infra)
	@echo "🧪 Running integration tests..."
	@go test -v $(INTEGRATION_PACKAGES)

test-domain: ## Run domain layer tests only
	@echo "🏛️ Running domain tests..."
	@go test -v $(DOMAIN_PACKAGES)

test-infra: ## Run infrastructure tests only
	@echo "🔧 Running infrastructure tests..."
	@go test -v $(INFRA_PACKAGES)

test-focus: ## Run tests excluding examples, docs, and build artifacts
	@echo "🎯 Running focused tests..."
	@go test -v $(INTERNAL_PACKAGES)

test-coverage: ## Generate coverage report for internal packages only
	@echo "📊 Generating coverage report..."
	@mkdir -p $(COVERAGE_DIR)
	@go test -coverprofile=$(COVERAGE_DIR)/coverage.out $(INTERNAL_PACKAGES)
	@go tool cover -html=$(COVERAGE_DIR)/coverage.out -o $(COVERAGE_DIR)/coverage.html
	@go tool cover -func=$(COVERAGE_DIR)/coverage.out
	@echo "📈 Coverage report: $(COVERAGE_DIR)/coverage.html"

test-coverage-summary: ## Show coverage summary for internal packages
	@echo "📊 Coverage Summary (Internal Packages Only):"
	@echo "=============================================="
	@go test -cover $(INTERNAL_PACKAGES) 2>/dev/null | grep -E "(coverage:|ok)" | sort

coverage-check: test-coverage ## Check if coverage meets minimum thresholds
	@echo "🎯 Checking coverage thresholds..."
	@go tool cover -func=$(COVERAGE_DIR)/coverage.out | grep "total:" | awk '{if ($$3+0 < 70) {print "❌ Coverage " $$3 " below 70% threshold"; exit 1} else {print "✅ Coverage " $$3 " meets threshold"}}'

ci-test: test-coverage ## Run tests for CI/CD (with coverage)
	@echo "🏗️  CI tests complete"

# DynamoDB Local
setup-local-db: ## Start local DynamoDB using Docker
	@echo "🗄️ Starting local DynamoDB..."
	@docker run -d -p 8000:8000 --name dynamodb-local amazon/dynamodb-local || echo "DynamoDB container already running"
	@echo "✅ DynamoDB Local running on http://localhost:8000"

stop-local-db: ## Stop local DynamoDB
	@echo "🛑 Stopping local DynamoDB..."
	@docker stop dynamodb-local || true
	@docker rm dynamodb-local || true
	@echo "✅ DynamoDB Local stopped"

create-table: ## Create DynamoDB table locally
	@echo "📋 Creating DynamoDB table..."
	@AWS_ACCESS_KEY_ID=dummy AWS_SECRET_ACCESS_KEY=dummy AWS_REGION=us-east-1 \
	aws dynamodb create-table \
		--table-name chargebacks \
		--attribute-definitions \
			AttributeName=id,AttributeType=S \
			AttributeName=transaction_id,AttributeType=S \
			AttributeName=merchant_id,AttributeType=S \
			AttributeName=status,AttributeType=S \
		--key-schema \
			AttributeName=id,KeyType=HASH \
		--global-secondary-indexes \
			'IndexName=transaction-id-index,KeySchema=[{AttributeName=transaction_id,KeyType=HASH}],Projection={ProjectionType=ALL}' \
			'IndexName=merchant-id-index,KeySchema=[{AttributeName=merchant_id,KeyType=HASH}],Projection={ProjectionType=ALL}' \
			'IndexName=status-index,KeySchema=[{AttributeName=status,KeyType=HASH}],Projection={ProjectionType=ALL}' \
		--billing-mode PAY_PER_REQUEST \
		--endpoint-url http://localhost:8000 \
		|| echo "Table may already exist"
	@echo "✅ Table created"

drop-table: ## Delete DynamoDB table locally
	@echo "🗑️  Dropping DynamoDB table..."
	@AWS_ACCESS_KEY_ID=dummy AWS_SECRET_ACCESS_KEY=dummy AWS_REGION=us-east-1 \
	aws dynamodb delete-table \
		--table-name chargebacks \
		--endpoint-url http://localhost:8000 \
		|| echo "Table may not exist"
	@echo "✅ Table dropped"

recreate-table: drop-table create-table ## Drop and recreate DynamoDB table
	@echo "🔄 Table recreated successfully"

list-tables: ## List all DynamoDB tables
	@echo "📋 Listing DynamoDB tables..."
	@AWS_ACCESS_KEY_ID=dummy AWS_SECRET_ACCESS_KEY=dummy AWS_REGION=us-east-1 \
	aws dynamodb list-tables --endpoint-url http://localhost:8000

describe-table: ## Describe the chargebacks table
	@echo "📋 Describing chargebacks table..."
	@AWS_ACCESS_KEY_ID=dummy AWS_SECRET_ACCESS_KEY=dummy AWS_REGION=us-east-1 \
	aws dynamodb describe-table --table-name chargebacks --endpoint-url http://localhost:8000

debug-db: ## Debug DynamoDB Local status and tables
	@echo "🔍 Debugging DynamoDB Local..."
	@echo "Checking if DynamoDB Local is running:"
	@curl -s http://localhost:8000 | head -2 || echo "❌ DynamoDB Local not responding"
	@echo "✅ DynamoDB Local is responding"
	@echo "Listing tables:"
	@AWS_ACCESS_KEY_ID=dummy AWS_SECRET_ACCESS_KEY=dummy AWS_REGION=us-east-1 \
	aws dynamodb list-tables --endpoint-url http://localhost:8000

# Lambda-specific targets
build-lambda: ## Build Lambda deployment package
	@echo "🔨 Building Lambda function..."
	@mkdir -p $(BUILD_DIR)
	@GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="-w -s" -o $(BUILD_DIR)/bootstrap cmd/lambda/main.go
	@cd $(BUILD_DIR) && zip ../$(LAMBDA_ZIP) bootstrap
	@echo "✅ Lambda package ready: $(LAMBDA_ZIP)"

deploy-lambda: build-lambda ## Deploy to AWS Lambda
	@echo "🚀 Deploying to AWS Lambda..."
	@aws lambda update-function-code \
		--function-name $(FUNCTION_NAME) \
		--zip-file fileb://$(LAMBDA_ZIP) \
		--region us-east-1 || \
	aws lambda create-function \
		--function-name $(FUNCTION_NAME) \
		--runtime provided.al2 \
		--role arn:aws:iam::$$(aws sts get-caller-identity --query Account --output text):role/lambda-execution-role \
		--handler bootstrap \
		--zip-file fileb://$(LAMBDA_ZIP) \
		--region us-east-1
	@echo "✅ Deployment complete"

test-lambda-local: ## Test Lambda function locally with SAM (using local template)
	@echo "🧪 Testing Lambda function locally..."
	@./scripts/start-local-env.sh

start-sam: build-lambda ## Start SAM local API
	@echo "🚀 Starting SAM Local API..."
	@sam local start-api --template template.local.yaml --log-file /tmp/sam.log

stop-sam: ## Stop SAM local API
	@echo "🛑 Stopping SAM Local API..."
	@pkill -f "sam local start-api" || echo "SAM not running"

dynamodb-scan: ## Scan DynamoDB local table
	@echo "📋 Scanning chargebacks-lambda table..."
	@AWS_ACCESS_KEY_ID=dummy AWS_SECRET_ACCESS_KEY=dummy aws dynamodb scan \
		--table-name chargebacks-lambda \
		--endpoint-url http://localhost:8000 \
		--region us-east-1 \
		--output json | jq '.Items | length as $$count | {count: $$count, items: . | map({id: .id.S, transaction_id: .transaction_id.S, amount: .amount.N, status: .status.S})}'

test-api: ## Test API endpoints
	@echo "🧪 Testing API endpoints..."
	@echo "\n1. Health Check:"
	@curl -s http://localhost:3000/health | jq .
	@echo "\n2. Creating test chargeback:"
	@curl -s -X POST http://localhost:3000/chargebacks \
		-H "Content-Type: application/json" \
		-d '{"transaction_id":"TEST-$(shell date +%s)","merchant_id":"MERCH-TEST","amount":99.99,"currency":"USD","card_number":"****1111","reason":"fraud","description":"Test chargeback","transaction_date":"2025-01-15T10:30:00Z"}' | jq .

clean-lambda: ## Clean Lambda build artifacts
	@echo "🧹 Cleaning Lambda artifacts..."
	@rm -f $(LAMBDA_ZIP)
	@rm -f $(BUILD_DIR)/bootstrap
	@echo "✅ Lambda artifacts cleaned"
