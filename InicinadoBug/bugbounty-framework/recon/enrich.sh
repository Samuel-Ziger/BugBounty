#!/bin/bash

# Context enrichment
# Detecta: tecnologias, frameworks, headers fracos, cloud provider
# Alimenta: Nuclei, Exploitation manual

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(dirname "$SCRIPT_DIR")"
ALIVE_FILE="$FRAMEWORK_DIR/output/subdomains_alive.txt"
OUTPUT_DIR="$FRAMEWORK_DIR/output/enrichment"
ENRICHMENT_FILE="$OUTPUT_DIR/enrichment.json"
TECH_FILE="$OUTPUT_DIR/technologies.txt"
FRAMEWORKS_FILE="$OUTPUT_DIR/frameworks.txt"
HEADERS_FILE="$OUTPUT_DIR/weak_headers.txt"
CLOUD_FILE="$OUTPUT_DIR/cloud_providers.txt"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}[+] Iniciando context enrichment${NC}"

# Verificar arquivo de entrada
if [ ! -f "$ALIVE_FILE" ]; then
    echo -e "${RED}[-] Arquivo subdomains_alive.txt não encontrado!${NC}"
    echo -e "${YELLOW}[*] Execute primeiro: ./recon/run.sh${NC}"
    exit 1
fi

# Criar diretório de output
mkdir -p "$OUTPUT_DIR"

# Limpar arquivos anteriores
> "$ENRICHMENT_FILE"
> "$TECH_FILE"
> "$FRAMEWORKS_FILE"
> "$HEADERS_FILE"
> "$CLOUD_FILE"

# Headers fracos conhecidos
WEAK_HEADERS=(
    "X-Powered-By"
    "Server"
    "X-AspNet-Version"
    "X-AspNetMvc-Version"
    "X-Drupal-Cache"
    "X-Generator"
    "X-Version"
)

# Padrões de cloud providers
CLOUD_PATTERNS=(
    "aws"
    "amazon"
    "amazonaws"
    "cloudfront"
    "s3"
    "azure"
    "microsoft"
    "azurewebsites"
    "blob.core.windows.net"
    "gcp"
    "googlecloud"
    "googleusercontent"
    "appspot.com"
    "cloudflare"
    "fastly"
    "heroku"
    "herokuapp.com"
    "digitalocean"
    "linode"
    "vultr"
)

echo -e "${GREEN}[+] Enriquecendo contexto...${NC}"

# Usar httpx para detecção de tecnologias
if command -v httpx &> /dev/null; then
    echo -e "${BLUE}[*] Usando httpx para detecção de tecnologias...${NC}"
    httpx -l "$ALIVE_FILE" \
        -tech-detect \
        -title \
        -status-code \
        -server \
        -json \
        -o "$ENRICHMENT_FILE" \
        -silent \
        2>/dev/null || true
fi

# Processar resultados
if [ -f "$ENRICHMENT_FILE" ] && [ -s "$ENRICHMENT_FILE" ]; then
    echo -e "${GREEN}[+] Processando resultados...${NC}"
    
    # Extrair tecnologias
    if command -v jq &> /dev/null; then
        jq -r '.tech[]? // empty' "$ENRICHMENT_FILE" 2>/dev/null | sort -u > "$TECH_FILE" || true
        
        # Extrair frameworks
        jq -r '.tech[]? // empty' "$ENRICHMENT_FILE" 2>/dev/null | \
            grep -iE "framework|django|rails|laravel|spring|express|react|vue|angular" | \
            sort -u > "$FRAMEWORKS_FILE" || true
        
        # Extrair informações de headers
        jq -r 'select(.tech != null) | "\(.url)|\(.tech | join(","))"' "$ENRICHMENT_FILE" 2>/dev/null > "$HEADERS_FILE" || true
    else
        # Fallback sem jq
        grep -oP '"tech":\s*\[[^\]]*\]' "$ENRICHMENT_FILE" | \
            grep -oP '"[^"]+"' | \
            sed 's/"//g' | \
            sort -u > "$TECH_FILE" || true
    fi
fi

# Detectar cloud providers
echo -e "${BLUE}[*] Detectando cloud providers...${NC}"
while IFS= read -r url; do
    if [ -z "$url" ]; then
        continue
    fi
    
    for pattern in "${CLOUD_PATTERNS[@]}"; do
        if echo "$url" | grep -qi "$pattern"; then
            echo "$url|$pattern" >> "$CLOUD_FILE"
            break
        fi
    done
    
    # Verificar headers HTTP para cloud
    headers=$(curl -s -I --max-time 5 "$url" 2>/dev/null || true)
    for pattern in "${CLOUD_PATTERNS[@]}"; do
        if echo "$headers" | grep -qi "$pattern"; then
            echo "$url|$pattern (header)" >> "$CLOUD_FILE"
            break
        fi
    done
done < "$ALIVE_FILE"

# Detectar headers fracos
echo -e "${BLUE}[*] Detectando headers fracos...${NC}"
while IFS= read -r url; do
    if [ -z "$url" ]; then
        continue
    fi
    
    headers=$(curl -s -I --max-time 5 "$url" 2>/dev/null || true)
    
    for weak_header in "${WEAK_HEADERS[@]}"; do
        if echo "$headers" | grep -qi "^$weak_header:"; then
            header_value=$(echo "$headers" | grep -i "^$weak_header:" | cut -d':' -f2- | xargs)
            echo "$url|$weak_header: $header_value" >> "$HEADERS_FILE"
        fi
    done
done < "$ALIVE_FILE"

# Remover duplicatas
sort -u "$TECH_FILE" -o "$TECH_FILE"
sort -u "$FRAMEWORKS_FILE" -o "$FRAMEWORKS_FILE"
sort -u "$HEADERS_FILE" -o "$HEADERS_FILE"
sort -u "$CLOUD_FILE" -o "$CLOUD_FILE"

TECH_COUNT=$(wc -l < "$TECH_FILE" 2>/dev/null || echo "0")
FRAMEWORKS_COUNT=$(wc -l < "$FRAMEWORKS_FILE" 2>/dev/null || echo "0")
HEADERS_COUNT=$(wc -l < "$HEADERS_FILE" 2>/dev/null || echo "0")
CLOUD_COUNT=$(wc -l < "$CLOUD_FILE" 2>/dev/null || echo "0")

echo -e "${GREEN}[+] Enrichment concluído!${NC}"
echo -e "${GREEN}[+] Estatísticas:${NC}"
echo -e "  - Tecnologias detectadas: $TECH_COUNT"
echo -e "  - Frameworks detectados: $FRAMEWORKS_COUNT"
echo -e "  - Headers fracos: $HEADERS_COUNT"
echo -e "  - Cloud providers: $CLOUD_COUNT"
echo -e "${GREEN}[+] Arquivos gerados em: $OUTPUT_DIR${NC}"
