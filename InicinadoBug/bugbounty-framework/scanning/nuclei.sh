#!/bin/bash

# Scanning básico com Nuclei
# Templates por severidade (low, medium, high, critical)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(dirname "$SCRIPT_DIR")"
ALIVE_FILE="$FRAMEWORK_DIR/output/subdomains_alive.txt"
OUTPUT_DIR="$FRAMEWORK_DIR/output/nuclei"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Severidades padrão (pode ser sobrescrito via argumentos)
SEVERITY="${1:-high,critical}"

echo -e "${GREEN}[+] Iniciando scan com Nuclei${NC}"
echo -e "${YELLOW}[*] Severidades: $SEVERITY${NC}"

# Verificar se nuclei está instalado
if ! command -v nuclei &> /dev/null; then
    echo -e "${RED}[-] nuclei não encontrado!${NC}"
    echo -e "${YELLOW}[*] Instale: go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest${NC}"
    exit 1
fi

# Verificar se existe arquivo de subdomínios vivos
if [ ! -f "$ALIVE_FILE" ]; then
    echo -e "${RED}[-] Arquivo subdomains_alive.txt não encontrado!${NC}"
    echo -e "${YELLOW}[*] Execute primeiro: ./recon/run.sh${NC}"
    exit 1
fi

# Criar diretório de output
mkdir -p "$OUTPUT_DIR"

# Criar arquivos separados por severidade
LOW_FILE="$OUTPUT_DIR/nuclei_low.txt"
MEDIUM_FILE="$OUTPUT_DIR/nuclei_medium.txt"
HIGH_FILE="$OUTPUT_DIR/nuclei_high.txt"
CRITICAL_FILE="$OUTPUT_DIR/nuclei_critical.txt"
ALL_FILE="$OUTPUT_DIR/nuclei_all.json"

# Limpar arquivos anteriores
> "$LOW_FILE"
> "$MEDIUM_FILE"
> "$HIGH_FILE"
> "$CRITICAL_FILE"
> "$ALL_FILE"

# Executar nuclei
echo -e "${GREEN}[+] Executando nuclei...${NC}"

# Atualizar templates
echo -e "${YELLOW}[*] Atualizando templates do Nuclei...${NC}"
nuclei -update-templates -silent 2>/dev/null || true

# Executar scan
nuclei -l "$ALIVE_FILE" \
    -severity "$SEVERITY" \
    -json \
    -o "$ALL_FILE" \
    -rate-limit 50 \
    -timeout 10 \
    -retries 2 \
    -no-color 2>/dev/null || true

# Separar por severidade
if [ -f "$ALL_FILE" ] && [ -s "$ALL_FILE" ]; then
    echo -e "${GREEN}[+] Separando resultados por severidade...${NC}"
    
    # Filtrar por severidade usando jq ou grep
    if command -v jq &> /dev/null; then
        jq -r 'select(.info.severity == "low") | .' "$ALL_FILE" > "$LOW_FILE" 2>/dev/null || true
        jq -r 'select(.info.severity == "medium") | .' "$ALL_FILE" > "$MEDIUM_FILE" 2>/dev/null || true
        jq -r 'select(.info.severity == "high") | .' "$ALL_FILE" > "$HIGH_FILE" 2>/dev/null || true
        jq -r 'select(.info.severity == "critical") | .' "$ALL_FILE" > "$CRITICAL_FILE" 2>/dev/null || true
    else
        # Fallback usando grep
        grep -i '"severity":"low"' "$ALL_FILE" > "$LOW_FILE" 2>/dev/null || true
        grep -i '"severity":"medium"' "$ALL_FILE" > "$MEDIUM_FILE" 2>/dev/null || true
        grep -i '"severity":"high"' "$ALL_FILE" > "$HIGH_FILE" 2>/dev/null || true
        grep -i '"severity":"critical"' "$ALL_FILE" > "$CRITICAL_FILE" 2>/dev/null || true
    fi
    
    # Contar resultados
    LOW_COUNT=$(wc -l < "$LOW_FILE" 2>/dev/null || echo "0")
    MEDIUM_COUNT=$(wc -l < "$MEDIUM_FILE" 2>/dev/null || echo "0")
    HIGH_COUNT=$(wc -l < "$HIGH_FILE" 2>/dev/null || echo "0")
    CRITICAL_COUNT=$(wc -l < "$CRITICAL_FILE" 2>/dev/null || echo "0")
    
    echo -e "${GREEN}[+] Resultados:${NC}"
    echo -e "  ${RED}Critical: $CRITICAL_COUNT${NC}"
    echo -e "  ${YELLOW}High: $HIGH_COUNT${NC}"
    echo -e "  ${YELLOW}Medium: $MEDIUM_COUNT${NC}"
    echo -e "  ${GREEN}Low: $LOW_COUNT${NC}"
else
    echo -e "${YELLOW}[!] Nenhum resultado encontrado${NC}"
fi

echo -e "${GREEN}[+] Scan concluído!${NC}"
echo -e "${GREEN}[+] Arquivos gerados em: $OUTPUT_DIR${NC}"
