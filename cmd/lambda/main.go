package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"

	"github.com/DiegoSantos90/chargeback-lambda/internal/domain/service"
	"github.com/DiegoSantos90/chargeback-lambda/internal/infra/db"
	"github.com/DiegoSantos90/chargeback-lambda/internal/infra/logging"
	dynamoRepo "github.com/DiegoSantos90/chargeback-lambda/internal/infra/repository"
	"github.com/DiegoSantos90/chargeback-lambda/internal/usecase"
)

// Global dependencies (initialized once during cold start)
var (
	createChargebackUC *usecase.CreateChargebackUseCase
	logger             service.Logger
)

func init() {
	ctx := context.Background()

	// Load configuration
	config := loadConfiguration()

	// Initialize logger
	loggerConfig := logging.LoggerConfig{
		Level:       parseLogLevel(getEnvOrDefault("LOG_LEVEL", "info")),
		Format:      logging.FormatJSON, // Lambda always uses JSON
		ServiceName: getEnvOrDefault("SERVICE_NAME", "chargeback-lambda"),
		Version:     getEnvOrDefault("APP_VERSION", "1.0.0"),
	}

	var err error
	logger, err = logging.NewStructuredLogger(loggerConfig, nil)
	if err != nil {
		log.Fatalf("Failed to initialize logger: %v", err)
	}

	// Initialize DynamoDB client
	dynamoClient, err := db.NewDynamoDBClient(ctx, config)
	if err != nil {
		logger.Error(ctx, "Failed to initialize DynamoDB client", map[string]interface{}{
			"error": err.Error(),
		})
		log.Fatalf("Failed to initialize DynamoDB client: %v", err)
	}

	// Initialize repository and use case
	chargebackRepo := dynamoRepo.NewDynamoDBChargebackRepository(dynamoClient, config.TableName)
	createChargebackUC = usecase.NewCreateChargebackUseCase(chargebackRepo)

	logger.Info(ctx, "Lambda function initialized", map[string]interface{}{
		"table_name": config.TableName,
		"region":     config.Region,
	})
}

func handler(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	logger.Info(ctx, "Received request", map[string]interface{}{
		"method": request.HTTPMethod,
		"path":   request.Path,
	})

	// Route based on path and method
	switch {
	case request.Path == "/health" && request.HTTPMethod == http.MethodGet:
		return handleHealth(ctx)
	case strings.HasPrefix(request.Path, "/chargebacks") && request.HTTPMethod == http.MethodPost:
		return handleCreateChargeback(ctx, request)
	case strings.HasPrefix(request.Path, "/api/v1/chargebacks") && request.HTTPMethod == http.MethodPost:
		return handleCreateChargeback(ctx, request)
	default:
		return events.APIGatewayProxyResponse{
			StatusCode: http.StatusNotFound,
			Headers:    map[string]string{"Content-Type": "application/json"},
			Body:       `{"error":"Not Found","message":"Route not found"}`,
		}, nil
	}
}

func handleHealth(ctx context.Context) (events.APIGatewayProxyResponse, error) {
	response := map[string]interface{}{
		"status":  "healthy",
		"service": "chargeback-lambda",
	}

	body, err := json.Marshal(response)
	if err != nil {
		logger.Error(ctx, "Failed to marshal health response", map[string]interface{}{
			"error": err.Error(),
		})
		return events.APIGatewayProxyResponse{
			StatusCode: http.StatusInternalServerError,
			Headers:    map[string]string{"Content-Type": "application/json"},
			Body:       `{"error":"Internal Server Error"}`,
		}, nil
	}

	return events.APIGatewayProxyResponse{
		StatusCode: http.StatusOK,
		Headers:    map[string]string{"Content-Type": "application/json"},
		Body:       string(body),
	}, nil
}

func handleCreateChargeback(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	// Parse request body
	var req usecase.CreateChargebackRequest
	if err := json.Unmarshal([]byte(request.Body), &req); err != nil {
		logger.Error(ctx, "Failed to parse request body", map[string]interface{}{
			"error": err.Error(),
		})
		return events.APIGatewayProxyResponse{
			StatusCode: http.StatusBadRequest,
			Headers:    map[string]string{"Content-Type": "application/json"},
			Body:       fmt.Sprintf(`{"error":"Bad Request","message":"Invalid JSON: %s"}`, err.Error()),
		}, nil
	}

	// Execute use case
	chargeback, err := createChargebackUC.Execute(ctx, req)
	if err != nil {
		logger.Error(ctx, "Failed to create chargeback", map[string]interface{}{
			"error": err.Error(),
		})

		// Check if it's a validation error
		if strings.Contains(err.Error(), "validation") {
			return events.APIGatewayProxyResponse{
				StatusCode: http.StatusBadRequest,
				Headers:    map[string]string{"Content-Type": "application/json"},
				Body:       fmt.Sprintf(`{"error":"Validation Error","message":"%s"}`, err.Error()),
			}, nil
		}

		return events.APIGatewayProxyResponse{
			StatusCode: http.StatusInternalServerError,
			Headers:    map[string]string{"Content-Type": "application/json"},
			Body:       `{"error":"Internal Server Error","message":"Failed to create chargeback"}`,
		}, nil
	}

	// Marshal response
	body, err := json.Marshal(chargeback)
	if err != nil {
		logger.Error(ctx, "Failed to marshal chargeback response", map[string]interface{}{
			"error": err.Error(),
		})
		return events.APIGatewayProxyResponse{
			StatusCode: http.StatusInternalServerError,
			Headers:    map[string]string{"Content-Type": "application/json"},
			Body:       `{"error":"Internal Server Error"}`,
		}, nil
	}

	logger.Info(ctx, "Chargeback created successfully", map[string]interface{}{
		"chargeback_id": chargeback.ID,
	})

	return events.APIGatewayProxyResponse{
		StatusCode: http.StatusCreated,
		Headers:    map[string]string{"Content-Type": "application/json"},
		Body:       string(body),
	}, nil
}

func loadConfiguration() db.DynamoDBConfig {
	return db.DynamoDBConfig{
		Endpoint:  getEnvOrDefault("DYNAMODB_ENDPOINT", ""),
		Region:    getEnvOrDefault("AWS_REGION", "us-east-1"),
		TableName: getEnvOrDefault("DYNAMODB_TABLE", "chargebacks-lambda"),
	}
}

func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func parseLogLevel(level string) service.LogLevel {
	switch strings.ToLower(level) {
	case "debug":
		return service.LogLevelDebug
	case "info":
		return service.LogLevelInfo
	case "warn", "warning":
		return service.LogLevelWarn
	case "error":
		return service.LogLevelError
	default:
		return service.LogLevelInfo
	}
}

func main() {
	lambda.Start(handler)
}
