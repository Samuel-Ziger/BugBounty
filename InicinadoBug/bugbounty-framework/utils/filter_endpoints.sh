#!/bin/bash

# Filtro inteligente de endpoints
# Remove: imagens, css/js
# Prioriza: /api/, /admin, /auth, /upload

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(dirname "$SCRIPT_DIR")"
INPUT_FILE="${1:-$FRAMEWORK_DIR/output/subdomains_alive.txt}"
OUTPUT_DIR="$FRAMEWORK_DIR/output/filtered"
FILTERED_FILE="$OUTPUT_DIR/endpoints_filtered.txt"
PRIORITY_FILE="$OUTPUT_DIR/endpoints_priority.txt"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}[+] Filtrando endpoints${NC}"

# Verificar arquivo de entrada
if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}[-] Arquivo não encontrado: $INPUT_FILE${NC}"
    exit 1
fi

# Criar diretório de output
mkdir -p "$OUTPUT_DIR"

# Limpar arquivos anteriores
> "$FILTERED_FILE"
> "$PRIORITY_FILE"

# Extensões para remover
EXCLUDE_EXTENSIONS="jpg|jpeg|png|gif|svg|ico|css|js|woff|woff2|ttf|eot|pdf|zip|tar|gz|mp4|mp3|avi|mov|wmv|flv|webm"

# Padrões prioritários
PRIORITY_PATTERNS="api|admin|auth|login|signin|signup|register|dashboard|panel|upload|file|download|backup|config|settings|test|dev|staging|internal|private|secret|token|key|password|reset|forgot|oauth|callback|webhook|endpoint|v1|v2|rest|graphql"

echo -e "${GREEN}[+] Processando arquivo: $INPUT_FILE${NC}"

# Ler e filtrar URLs
while IFS= read -r line; do
    if [ -z "$line" ]; then
        continue
    fi
    
    # Adicionar protocolo se não tiver
    url="$line"
    if [[ ! "$url" =~ ^https?:// ]]; then
        url="http://$url"
    fi
    
    # Remover URLs com extensões indesejadas
    if echo "$url" | grep -qiE "\.($EXCLUDE_EXTENSIONS)(\?|$|/)" ; then
        continue
    fi
    
    # Remover URLs que são apenas imagens/css/js
    if echo "$url" | grep -qiE "/(images?|img|assets?|static|css|js|fonts?)/.*\.($EXCLUDE_EXTENSIONS)" ; then
        continue
    fi
    
    # Adicionar à lista filtrada
    echo "$url" >> "$FILTERED_FILE"
    
    # Verificar se é prioritário
    if echo "$url" | grep -qiE "($PRIORITY_PATTERNS)" ; then
        echo "$url" >> "$PRIORITY_FILE"
    fi
done < "$INPUT_FILE"

# Remover duplicatas
sort -u "$FILTERED_FILE" -o "$FILTERED_FILE"
sort -u "$PRIORITY_FILE" -o "$PRIORITY_FILE"

FILTERED_COUNT=$(wc -l < "$FILTERED_FILE" 2>/dev/null || echo "0")
PRIORITY_COUNT=$(wc -l < "$PRIORITY_FILE" 2>/dev/null || echo "0")

echo -e "${GREEN}[+] Filtragem concluída!${NC}"
echo -e "${GREEN}[+] Estatísticas:${NC}"
echo -e "  - Endpoints filtrados: $FILTERED_COUNT"
echo -e "  - Endpoints prioritários: $PRIORITY_COUNT"
echo -e "${GREEN}[+] Arquivos gerados:${NC}"
echo -e "  - $FILTERED_FILE"
echo -e "  - $PRIORITY_FILE"
