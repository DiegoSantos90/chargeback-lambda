#!/bin/bash

# 🧪 Script de Teste Automatizado - Chargeback API
# Este script executa testes automatizados da API Chargeback

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
BASE_URL="http://localhost:8080"
TIMESTAMP=$(date +%s)

echo -e "${BLUE}🚀 Iniciando testes da Chargeback API...${NC}\n"

# Função para fazer requisições HTTP
make_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    local content_type=${4:-"application/json"}
    
    if [ -z "$data" ]; then
        curl -s -w "\n%{http_code}" -X "$method" "$BASE_URL$endpoint"
    else
        curl -s -w "\n%{http_code}" -X "$method" "$BASE_URL$endpoint" \
             -H "Content-Type: $content_type" \
             -d "$data"
    fi
}

# Função para verificar status code
check_status() {
    local expected=$1
    local actual=$2
    local test_name=$3
    
    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}✅ $test_name - Status: $actual${NC}"
        return 0
    else
        echo -e "${RED}❌ $test_name - Esperado: $expected, Recebido: $actual${NC}"
        return 1
    fi
}

# Teste 1: Health Check
echo -e "${YELLOW}📋 Teste 1: Health Check${NC}"
response=$(make_request "GET" "/health")
status_code=$(echo "$response" | tail -1)
response_body=$(echo "$response" | sed '$d')

check_status "200" "$status_code" "Health Check"
echo -e "Resposta: $response_body\n"

# Teste 2: Criar Chargeback por Fraude (Sucesso)
echo -e "${YELLOW}📋 Teste 2: Criar Chargeback - Fraude${NC}"
chargeback_data='{
    "transaction_id": "txn_test_fraud_'$TIMESTAMP'",
    "merchant_id": "merchant_test_script",
    "amount": 299.99,
    "currency": "BRL",
    "card_number": "4111111111111111",
    "reason": "fraud",
    "description": "Teste automatizado - fraude",
    "transaction_date": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
}'

response=$(make_request "POST" "/chargebacks" "$chargeback_data")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed $d)

check_status "201" "$status_code" "Criar Chargeback - Fraude"
echo -e "Resposta: $response_body\n"

# Guardar transaction_id para teste de duplicata
FRAUD_TRANSACTION_ID="txn_test_fraud_$TIMESTAMP"

# Teste 3: Criar Chargeback - Erro de Autorização
echo -e "${YELLOW}📋 Teste 3: Criar Chargeback - Erro de Autorização${NC}"
chargeback_data='{
    "transaction_id": "txn_test_auth_error_'$TIMESTAMP'",
    "merchant_id": "merchant_test_script",
    "amount": 1299.00,
    "currency": "BRL",
    "card_number": "4000000000000002",
    "reason": "authorization_error",
    "description": "Teste automatizado - erro de autorização",
    "transaction_date": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
}'

response=$(make_request "POST" "/chargebacks" "$chargeback_data")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed $d)

check_status "201" "$status_code" "Criar Chargeback - Erro de Autorização"
echo -e "Resposta: $response_body\n"

# Teste 4: Erro - Transaction ID Duplicado
echo -e "${YELLOW}📋 Teste 4: Erro - Transaction ID Duplicado${NC}"
duplicate_data='{
    "transaction_id": "'$FRAUD_TRANSACTION_ID'",
    "merchant_id": "merchant_another",
    "amount": 100.00,
    "currency": "USD",
    "card_number": "4111111111111111",
    "reason": "fraud",
    "transaction_date": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
}'

response=$(make_request "POST" "/chargebacks" "$duplicate_data")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed $d)

check_status "409" "$status_code" "Erro - Transaction ID Duplicado"
echo -e "Resposta: $response_body\n"

# Teste 5: Erro - Transaction ID Vazio
echo -e "${YELLOW}📋 Teste 5: Erro - Transaction ID Vazio${NC}"
empty_transaction_data='{
    "transaction_id": "",
    "merchant_id": "merchant_test",
    "amount": 100.00,
    "currency": "USD",
    "card_number": "4111111111111111",
    "reason": "fraud",
    "transaction_date": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
}'

response=$(make_request "POST" "/chargebacks" "$empty_transaction_data")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed $d)

check_status "500" "$status_code" "Erro - Transaction ID Vazio"
echo -e "Resposta: $response_body\n"

# Teste 6: Erro - Reason Inválido
echo -e "${YELLOW}📋 Teste 6: Erro - Reason Inválido${NC}"
invalid_reason_data='{
    "transaction_id": "txn_invalid_reason_'$TIMESTAMP'",
    "merchant_id": "merchant_test",
    "amount": 100.00,
    "currency": "USD",
    "card_number": "4111111111111111",
    "reason": "invalid_reason",
    "transaction_date": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
}'

response=$(make_request "POST" "/chargebacks" "$invalid_reason_data")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed $d)

check_status "400" "$status_code" "Erro - Reason Inválido"
echo -e "Resposta: $response_body\n"

# Teste 7: Erro - Método HTTP Inválido
echo -e "${YELLOW}📋 Teste 7: Erro - Método HTTP Inválido${NC}"
response=$(make_request "GET" "/chargebacks")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed $d)

check_status "405" "$status_code" "Erro - Método HTTP Inválido"
echo -e "Resposta: $response_body\n"

# Teste 8: Erro - Content-Type Inválido
echo -e "${YELLOW}📋 Teste 8: Erro - Content-Type Inválido${NC}"
test_data='{"transaction_id": "txn_test", "merchant_id": "merchant_test"}'
response=$(make_request "POST" "/chargebacks" "$test_data" "text/plain")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed $d)

check_status "415" "$status_code" "Erro - Content-Type Inválido"
echo -e "Resposta: $response_body\n"

# Teste 9: Criar Chargeback - Erro de Processamento
echo -e "${YELLOW}📋 Teste 9: Criar Chargeback - Erro de Processamento${NC}"
duplicate_charge_data='{
    "transaction_id": "txn_test_processing_'$TIMESTAMP'",
    "merchant_id": "merchant_shopify_test",
    "amount": 89.90,
    "currency": "USD",
    "card_number": "5555555555554444",
    "reason": "processing_error",
    "description": "Teste automatizado - erro de processamento",
    "transaction_date": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
}'

response=$(make_request "POST" "/chargebacks" "$duplicate_charge_data")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed $d)

check_status "201" "$status_code" "Criar Chargeback - Erro de Processamento"
echo -e "Resposta: $response_body\n"

# Teste 10: Criar Chargeback - Disputa do Consumidor
echo -e "${YELLOW}📋 Teste 10: Criar Chargeback - Disputa do Consumidor${NC}"
subscription_data='{
    "transaction_id": "txn_test_consumer_dispute_'$TIMESTAMP'",
    "merchant_id": "merchant_streaming_test",
    "amount": 29.90,
    "currency": "BRL",
    "card_number": "4242424242424242",
    "reason": "consumer_dispute",
    "description": "Teste automatizado - disputa do consumidor",
    "transaction_date": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
}'

response=$(make_request "POST" "/chargebacks" "$subscription_data")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed $d)

check_status "201" "$status_code" "Criar Chargeback - Disputa do Consumidor"
echo -e "Resposta: $response_body\n"

# Resumo dos testes
echo -e "${BLUE}📊 Resumo dos Testes Executados:${NC}"
echo -e "${GREEN}✅ Health Check${NC}"
echo -e "${GREEN}✅ Criar Chargeback - Fraude${NC}"
echo -e "${GREEN}✅ Criar Chargeback - Erro de Autorização${NC}"
echo -e "${GREEN}✅ Criar Chargeback - Erro de Processamento${NC}"
echo -e "${GREEN}✅ Criar Chargeback - Disputa do Consumidor${NC}"
echo -e "${GREEN}✅ Erro - Transaction ID Duplicado${NC}"
echo -e "${GREEN}✅ Erro - Transaction ID Vazio${NC}"
echo -e "${GREEN}✅ Erro - Reason Inválido${NC}"
echo -e "${GREEN}✅ Erro - Método HTTP Inválido${NC}"
echo -e "${GREEN}✅ Erro - Content-Type Inválido${NC}"

echo -e "\n${BLUE}🎉 Todos os testes foram executados com sucesso!${NC}"

# Verificar dados no DynamoDB (opcional)
echo -e "\n${YELLOW}📋 Verificando dados no DynamoDB Local...${NC}"
if command -v aws &> /dev/null; then
    echo -e "${BLUE}Chargebacks criados nesta execução:${NC}"
    aws dynamodb scan \
        --table-name chargebacks \
        --endpoint-url http://localhost:8000 \
        --filter-expression "contains(transaction_id, :timestamp)" \
        --expression-attribute-values "{\":timestamp\":{\"S\":\"$TIMESTAMP\"}}" \
        --query "Items[].{ID:id.S,TransactionID:transaction_id.S,Reason:reason.S,Amount:amount.N}" \
        --output table 2>/dev/null || echo -e "${YELLOW}⚠️  Não foi possível verificar o DynamoDB (verifique se está rodando)${NC}"
else
    echo -e "${YELLOW}⚠️  AWS CLI não encontrado, pulando verificação do DynamoDB${NC}"
fi

echo -e "\n${GREEN}🏁 Testes concluídos!${NC}"