#!/bin/bash

# Alive checker robusto
# Detecta: 403 bypass candidates, WAF, redirects interessantes, auth walls

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(dirname "$SCRIPT_DIR")"
INPUT_FILE="${1:-$FRAMEWORK_DIR/output/subdomains.txt}"
OUTPUT_DIR="$FRAMEWORK_DIR/output/alive"
ALIVE_FILE="$OUTPUT_DIR/alive.txt"
BYPASS_CANDIDATES="$OUTPUT_DIR/403_bypass_candidates.txt"
WAF_DETECTED="$OUTPUT_DIR/waf_detected.txt"
REDIRECTS="$OUTPUT_DIR/redirects.txt"
AUTH_WALLS="$OUTPUT_DIR/auth_walls.txt"
DETAILED_INFO="$OUTPUT_DIR/detailed_info.json"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}[+] Verificando subdomínios vivos (checker robusto)${NC}"

# Verificar arquivo de entrada
if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}[-] Arquivo não encontrado: $INPUT_FILE${NC}"
    exit 1
fi

# Criar diretório de output
mkdir -p "$OUTPUT_DIR"

# Limpar arquivos anteriores
> "$ALIVE_FILE"
> "$BYPASS_CANDIDATES"
> "$WAF_DETECTED"
> "$REDIRECTS"
> "$AUTH_WALLS"
> "$DETAILED_INFO"

# Headers para bypass de 403
BYPASS_HEADERS=(
    "X-Forwarded-For: 127.0.0.1"
    "X-Real-IP: 127.0.0.1"
    "X-Originating-IP: 127.0.0.1"
    "X-Remote-IP: 127.0.0.1"
    "X-Remote-Addr: 127.0.0.1"
    "X-Forwarded-Host: localhost"
    "Referer: https://www.google.com"
    "User-Agent: Mozilla/5.0"
)

echo -e "${GREEN}[+] Processando subdomínios...${NC}"

# Processar cada subdomínio
while IFS= read -r subdomain; do
    if [ -z "$subdomain" ]; then
        continue
    fi
    
    # Adicionar protocolo se não tiver
    url="$subdomain"
    if [[ ! "$url" =~ ^https?:// ]]; then
        url="http://$url"
    fi
    
    echo -e "${BLUE}[*] Verificando: $subdomain${NC}"
    
    # Verificação básica
    response=$(curl -s -o /dev/null -w "%{http_code}|%{redirect_url}|%{size_download}|%{time_total}" \
        --max-time 10 \
        --connect-timeout 5 \
        "$url" 2>/dev/null || echo "000|||0|0")
    
    http_code=$(echo "$response" | cut -d'|' -f1)
    redirect_url=$(echo "$response" | cut -d'|' -f2)
    size=$(echo "$response" | cut -d'|' -f3)
    time=$(echo "$response" | cut -d'|' -f4)
    
    # Verificar se está vivo
    if [[ "$http_code" =~ ^[23] ]]; then
        echo "$subdomain" >> "$ALIVE_FILE"
        echo -e "${GREEN}[+] Vivo: $subdomain (HTTP $http_code)${NC}"
    elif [ "$http_code" = "403" ]; then
        echo -e "${YELLOW}[!] 403 encontrado: $subdomain${NC}"
        echo "$subdomain" >> "$BYPASS_CANDIDATES"
        
        # Testar bypass headers
        for header in "${BYPASS_HEADERS[@]}"; do
            header_name=$(echo "$header" | cut -d':' -f1)
            header_value=$(echo "$header" | cut -d':' -f2- | xargs)
            
            bypass_response=$(curl -s -o /dev/null -w "%{http_code}" \
                --max-time 5 \
                -H "$header_name: $header_value" \
                "$url" 2>/dev/null || echo "000")
            
            if [[ "$bypass_response" =~ ^[23] ]]; then
                echo -e "${GREEN}[+] Bypass possível com $header_name: $subdomain${NC}"
                echo "$subdomain|$header" >> "$BYPASS_CANDIDATES"
                break
            fi
        done
    elif [ "$http_code" = "401" ] || [ "$http_code" = "407" ]; then
        echo -e "${YELLOW}[!] Auth wall: $subdomain${NC}"
        echo "$subdomain" >> "$AUTH_WALLS"
    elif [ "$http_code" =~ ^30[1237] ]; then
        echo -e "${YELLOW}[!] Redirect: $subdomain -> $redirect_url${NC}"
        echo "$subdomain|$redirect_url" >> "$REDIRECTS"
    fi
    
    # Detectar WAF usando wafw00f ou análise de headers
    if command -v wafw00f &> /dev/null; then
        waf_result=$(wafw00f "$url" 2>/dev/null | grep -i "waf" || true)
        if [ -n "$waf_result" ]; then
            echo -e "${RED}[!] WAF detectado: $subdomain${NC}"
            echo "$subdomain|$waf_result" >> "$WAF_DETECTED"
        fi
    fi
    
    # Usar httpx para informações detalhadas
    if command -v httpx &> /dev/null; then
        httpx -u "$url" \
            -status-code \
            -content-length \
            -title \
            -tech-detect \
            -json \
            -silent \
            >> "$DETAILED_INFO" 2>/dev/null || true
    fi
    
done < "$INPUT_FILE"

# Remover duplicatas
sort -u "$ALIVE_FILE" -o "$ALIVE_FILE"
sort -u "$BYPASS_CANDIDATES" -o "$BYPASS_CANDIDATES"
sort -u "$WAF_DETECTED" -o "$WAF_DETECTED"
sort -u "$REDIRECTS" -o "$REDIRECTS"
sort -u "$AUTH_WALLS" -o "$AUTH_WALLS"

ALIVE_COUNT=$(wc -l < "$ALIVE_FILE" 2>/dev/null || echo "0")
BYPASS_COUNT=$(wc -l < "$BYPASS_CANDIDATES" 2>/dev/null || echo "0")
WAF_COUNT=$(wc -l < "$WAF_DETECTED" 2>/dev/null || echo "0")
REDIRECT_COUNT=$(wc -l < "$REDIRECTS" 2>/dev/null || echo "0")
AUTH_COUNT=$(wc -l < "$AUTH_WALLS" 2>/dev/null || echo "0")

echo -e "${GREEN}[+] Verificação concluída!${NC}"
echo -e "${GREEN}[+] Estatísticas:${NC}"
echo -e "  - Subdomínios vivos: $ALIVE_COUNT"
echo -e "  - Candidatos a bypass 403: $BYPASS_COUNT"
echo -e "  - WAF detectados: $WAF_COUNT"
echo -e "  - Redirects: $REDIRECT_COUNT"
echo -e "  - Auth walls: $AUTH_COUNT"
echo -e "${GREEN}[+] Arquivos gerados em: $OUTPUT_DIR${NC}"
