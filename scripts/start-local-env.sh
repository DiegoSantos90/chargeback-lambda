#!/bin/bash

# Script para iniciar ambiente de testes locais
# Uso: ./scripts/start-local-env.sh

set -e

echo "🚀 Iniciando ambiente de testes locais..."

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 1. Verificar se DynamoDB Local está rodando
echo -e "\n${YELLOW}1. Verificando DynamoDB Local...${NC}"
if docker ps | grep -q dynamodb-local; then
    echo -e "${GREEN}✓ DynamoDB Local já está rodando${NC}"
else
    echo -e "${YELLOW}→ Iniciando DynamoDB Local...${NC}"
    docker run -d -p 8000:8000 --name dynamodb-local amazon/dynamodb-local
    sleep 3
    echo -e "${GREEN}✓ DynamoDB Local iniciado${NC}"
fi

# 2. Verificar se a tabela existe
echo -e "\n${YELLOW}2. Verificando tabela chargebacks-lambda...${NC}"
TABLE_EXISTS=$(AWS_ACCESS_KEY_ID=dummy AWS_SECRET_ACCESS_KEY=dummy \
    aws dynamodb list-tables \
    --endpoint-url http://localhost:8000 \
    --region us-east-1 \
    --output text | grep -c "chargebacks-lambda" || echo "0")

if [ "$TABLE_EXISTS" -eq "0" ]; then
    echo -e "${YELLOW}→ Criando tabela chargebacks-lambda...${NC}"
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
        ]" > /dev/null 2>&1
    sleep 2
    echo -e "${GREEN}✓ Tabela criada com sucesso${NC}"
else
    echo -e "${GREEN}✓ Tabela já existe${NC}"
fi

# 3. Compilar a Lambda
echo -e "\n${YELLOW}3. Compilando Lambda...${NC}"
if [ -f "Makefile" ]; then
    make build > /dev/null 2>&1
    echo -e "${GREEN}✓ Lambda compilada${NC}"
else
    GOOS=linux GOARCH=amd64 go build -tags lambda.norpc -o bin/bootstrap cmd/lambda/main.go
    echo -e "${GREEN}✓ Lambda compilada${NC}"
fi

# 4. Verificar se SAM está rodando
echo -e "\n${YELLOW}4. Verificando SAM Local...${NC}"
if lsof -i :3000 > /dev/null 2>&1; then
    echo -e "${YELLOW}→ SAM já está rodando na porta 3000${NC}"
    read -p "   Deseja reiniciar? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        pkill -f "sam local start-api" || true
        sleep 2
    else
        echo -e "${GREEN}✓ Mantendo SAM em execução${NC}"
        exit 0
    fi
fi

# 5. Iniciar SAM Local
echo -e "\n${YELLOW}5. Iniciando SAM Local...${NC}"
sam local start-api --template template.local.yaml --log-file /tmp/sam.log > /tmp/sam-output.log 2>&1 &
SAM_PID=$!
echo $SAM_PID > /tmp/sam.pid
sleep 4

# 6. Verificar se SAM iniciou corretamente
echo -e "\n${YELLOW}6. Verificando health check...${NC}"
HEALTH_CHECK=$(curl -s http://localhost:3000/health 2>&1)
if echo "$HEALTH_CHECK" | grep -q "healthy"; then
    echo -e "${GREEN}✓ SAM Local rodando corretamente!${NC}"
    echo -e "  Response: $HEALTH_CHECK"
else
    echo -e "${RED}✗ Falha ao iniciar SAM Local${NC}"
    echo -e "${RED}  Verifique os logs em /tmp/sam.log${NC}"
    exit 1
fi

# 7. Sumário
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Ambiente de testes locais pronto!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e ""
echo -e "📍 API Local:    ${GREEN}http://localhost:3000${NC}"
echo -e "📍 DynamoDB:     ${GREEN}http://localhost:8000${NC}"
echo -e "📍 SAM PID:      ${GREEN}$SAM_PID${NC}"
echo -e "📍 Logs SAM:     ${GREEN}/tmp/sam.log${NC}"
echo -e ""
echo -e "${YELLOW}Comandos úteis:${NC}"
echo -e "  • Logs SAM:           ${GREEN}tail -f /tmp/sam.log${NC}"
echo -e "  • Parar SAM:          ${GREEN}pkill -f 'sam local start-api'${NC}"
echo -e "  • Ver tabela:         ${GREEN}make dynamodb-scan${NC}"
echo -e "  • Testar endpoint:    ${GREEN}make test-api${NC}"
echo -e ""
echo -e "${YELLOW}Exemplos de testes:${NC}"
echo -e "  ${GREEN}curl http://localhost:3000/health${NC}"
echo -e "  ${GREEN}curl -X POST http://localhost:3000/chargebacks -H 'Content-Type: application/json' -d '{...}'${NC}"
echo -e ""
