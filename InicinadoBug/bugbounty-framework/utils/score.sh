#!/bin/bash

# Risk scoring simples
# Prioriza endpoints: auth + params = 🔥, upload = 🔥, api + jwt = 🔥
# Isso te diz onde olhar primeiro.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$FRAMEWORK_DIR/output"
SCORED_FILE="$OUTPUT_DIR/scored_endpoints.txt"
HIGH_RISK_FILE="$OUTPUT_DIR/high_risk_endpoints.txt"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}[+] Calculando risk score${NC}"

# Criar diretório de output
mkdir -p "$OUTPUT_DIR"

# Limpar arquivos anteriores
> "$SCORED_FILE"
> "$HIGH_RISK_FILE"

# Padrões de alto risco
HIGH_RISK_PATTERNS=(
    "auth|login|signin|signup|register|password|reset|forgot|oauth|token|jwt|session"
    "upload|file|download|import|export|backup|restore"
    "admin|panel|dashboard|config|settings|manage|control"
    "api|endpoint|rest|graphql|webhook|callback"
    "delete|remove|destroy|drop|truncate"
    "exec|eval|system|command|shell|cmd"
    "sql|query|database|db|select|insert|update"
    "test|dev|staging|internal|private|secret|key"
)

# Função para calcular score
calculate_score() {
    local url="$1"
    local score=0
    
    # Score base
    score=1
    
    # Verificar padrões de alto risco
    for pattern in "${HIGH_RISK_PATTERNS[@]}"; do
        if echo "$url" | grep -qiE "$pattern"; then
            score=$((score + 10))
        fi
    done
    
    # Verificar se tem parâmetros
    if echo "$url" | grep -q "?"; then
        score=$((score + 5))
        
        # Contar número de parâmetros
        params=$(echo "$url" | cut -d'?' -f2- | cut -d'#' -f1)
        param_count=$(echo "$params" | tr '&' '\n' | wc -l)
        score=$((score + param_count))
    fi
    
    # Verificar se é API
    if echo "$url" | grep -qiE "/api/|/v[0-9]/|/rest/|/graphql"; then
        score=$((score + 15))
    fi
    
    # Verificar se tem JWT ou token
    if echo "$url" | grep -qiE "jwt|token|bearer|authorization"; then
        score=$((score + 20))
    fi
    
    # Verificar se é upload
    if echo "$url" | grep -qiE "upload|file|attach|import"; then
        score=$((score + 25))
    fi
    
    # Verificar se é admin
    if echo "$url" | grep -qiE "admin|panel|dashboard|manage"; then
        score=$((score + 20))
    fi
    
    # Verificar se tem comandos perigosos
    if echo "$url" | grep -qiE "exec|eval|system|command|shell"; then
        score=$((score + 30))
    fi
    
    echo "$score"
}

# Arquivos de entrada
ALIVE_FILE="$OUTPUT_DIR/subdomains_alive.txt"
FILTERED_FILE="$OUTPUT_DIR/filtered/endpoints_filtered.txt"
PRIORITY_FILE="$OUTPUT_DIR/filtered/endpoints_priority.txt"
PARAMS_FILE="$OUTPUT_DIR/params/all_urls.txt"

# Determinar arquivo de entrada
INPUT_FILE=""
if [ -f "$FILTERED_FILE" ] && [ -s "$FILTERED_FILE" ]; then
    INPUT_FILE="$FILTERED_FILE"
elif [ -f "$PRIORITY_FILE" ] && [ -s "$PRIORITY_FILE" ]; then
    INPUT_FILE="$PRIORITY_FILE"
elif [ -f "$PARAMS_FILE" ] && [ -s "$PARAMS_FILE" ]; then
    INPUT_FILE="$PARAMS_FILE"
elif [ -f "$ALIVE_FILE" ] && [ -s "$ALIVE_FILE" ]; then
    INPUT_FILE="$ALIVE_FILE"
fi

if [ -z "$INPUT_FILE" ] || [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}[-] Nenhum arquivo de entrada encontrado!${NC}"
    echo -e "${YELLOW}[*] Execute primeiro: ./recon/run.sh${NC}"
    exit 1
fi

echo -e "${BLUE}[*] Processando: $INPUT_FILE${NC}"

# Processar cada URL
while IFS= read -r url; do
    if [ -z "$url" ]; then
        continue
    fi
    
    # Remover pipe e informações extras
    clean_url=$(echo "$url" | cut -d'|' -f1)
    
    # Adicionar protocolo se necessário
    if [[ ! "$clean_url" =~ ^https?:// ]]; then
        clean_url="http://$clean_url"
    fi
    
    # Calcular score
    score=$(calculate_score "$clean_url")
    
    # Salvar com score
    echo "$score|$clean_url" >> "$SCORED_FILE"
    
    # Se score >= 30, adicionar à lista de alto risco
    if [ "$score" -ge 30 ]; then
        echo "$score|$clean_url" >> "$HIGH_RISK_FILE"
        echo -e "${RED}[🔥] Alto risco ($score): $clean_url${NC}"
    elif [ "$score" -ge 20 ]; then
        echo -e "${YELLOW}[⚠]  Médio risco ($score): $clean_url${NC}"
    fi
done < "$INPUT_FILE"

# Ordenar por score (maior primeiro)
sort -t'|' -k1 -rn "$SCORED_FILE" -o "$SCORED_FILE"
sort -t'|' -k1 -rn "$HIGH_RISK_FILE" -o "$HIGH_RISK_FILE"

TOTAL_COUNT=$(wc -l < "$SCORED_FILE" 2>/dev/null || echo "0")
HIGH_RISK_COUNT=$(wc -l < "$HIGH_RISK_FILE" 2>/dev/null || echo "0")

echo -e "${GREEN}[+] Risk scoring concluído!${NC}"
echo -e "${GREEN}[+] Estatísticas:${NC}"
echo -e "  - Total de endpoints: $TOTAL_COUNT"
echo -e "  - Alto risco (score >= 30): $HIGH_RISK_COUNT"
echo -e "${GREEN}[+] Arquivos gerados:${NC}"
echo -e "  - $SCORED_FILE (ordenado por score)"
echo -e "  - $HIGH_RISK_FILE (apenas alto risco)"

if [ "$HIGH_RISK_COUNT" -gt 0 ]; then
    echo -e "${RED}[!] ATENÇÃO: $HIGH_RISK_COUNT endpoints de alto risco encontrados!${NC}"
    echo -e "${YELLOW}[*] Revise: $HIGH_RISK_FILE${NC}"
fi
