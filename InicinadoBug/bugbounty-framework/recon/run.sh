#!/bin/bash

# Recon (passivo + ativo)
# Entrada: lista de domínios de domains.txt
# Saída: subdomínios vivos + HTTP info

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(dirname "$SCRIPT_DIR")"
DOMAINS_FILE="$FRAMEWORK_DIR/domains.txt"
OUTPUT_DIR="$FRAMEWORK_DIR/output"
SUBDOMAINS_FILE="$OUTPUT_DIR/subdomains.txt"
ALIVE_FILE="$OUTPUT_DIR/subdomains_alive.txt"
HTTP_INFO_FILE="$OUTPUT_DIR/http_info.json"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}[+] Iniciando recon passivo + ativo${NC}"

# Verificar se domains.txt existe
if [ ! -f "$DOMAINS_FILE" ]; then
    echo -e "${RED}[-] Arquivo domains.txt não encontrado!${NC}"
    exit 1
fi

# Criar diretório de output
mkdir -p "$OUTPUT_DIR"

# Limpar arquivos anteriores
> "$SUBDOMAINS_FILE"
> "$ALIVE_FILE"
> "$HTTP_INFO_FILE"

# Ler domínios
DOMAINS=$(grep -v '^#' "$DOMAINS_FILE" | grep -v '^$' | tr '\n' ' ')

if [ -z "$DOMAINS" ]; then
    echo -e "${RED}[-] Nenhum domínio encontrado em domains.txt${NC}"
    exit 1
fi

echo -e "${YELLOW}[*] Domínios encontrados: $DOMAINS${NC}"

# Subfinder
echo -e "${GREEN}[+] Executando subfinder...${NC}"
for domain in $DOMAINS; do
    if command -v subfinder &> /dev/null; then
        subfinder -d "$domain" -silent >> "$SUBDOMAINS_FILE" 2>/dev/null || true
    else
        echo -e "${YELLOW}[!] subfinder não encontrado, pulando...${NC}"
    fi
done

# Amass
echo -e "${GREEN}[+] Executando amass...${NC}"
for domain in $DOMAINS; do
    if command -v amass &> /dev/null; then
        amass enum -passive -d "$domain" >> "$SUBDOMAINS_FILE" 2>/dev/null || true
    else
        echo -e "${YELLOW}[!] amass não encontrado, pulando...${NC}"
    fi
done

# Assetfinder
echo -e "${GREEN}[+] Executando assetfinder...${NC}"
for domain in $DOMAINS; do
    if command -v assetfinder &> /dev/null; then
        assetfinder "$domain" >> "$SUBDOMAINS_FILE" 2>/dev/null || true
    else
        echo -e "${YELLOW}[!] assetfinder não encontrado, pulando...${NC}"
    fi
done

# Remover duplicatas e ordenar
echo -e "${GREEN}[+] Removendo duplicatas...${NC}"
sort -u "$SUBDOMAINS_FILE" -o "$SUBDOMAINS_FILE"

SUBDOMAINS_COUNT=$(wc -l < "$SUBDOMAINS_FILE")
echo -e "${GREEN}[+] Total de subdomínios encontrados: $SUBDOMAINS_COUNT${NC}"

# Verificar subdomínios vivos com httpx
echo -e "${GREEN}[+] Verificando subdomínios vivos com httpx...${NC}"
if command -v httpx &> /dev/null; then
    httpx -l "$SUBDOMAINS_FILE" \
        -silent \
        -status-code \
        -content-length \
        -title \
        -tech-detect \
        -json \
        -o "$HTTP_INFO_FILE" \
        -o "$ALIVE_FILE" 2>/dev/null || true
    
    # Extrair apenas URLs do JSON para o arquivo de texto
    if [ -f "$HTTP_INFO_FILE" ]; then
        jq -r '.url' "$HTTP_INFO_FILE" 2>/dev/null > "$ALIVE_FILE" || \
        grep -oP '"url":\s*"\K[^"]+' "$HTTP_INFO_FILE" > "$ALIVE_FILE" || true
    fi
else
    echo -e "${YELLOW}[!] httpx não encontrado, usando curl básico...${NC}"
    while IFS= read -r subdomain; do
        if curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://$subdomain" | grep -q "200\|301\|302\|403"; then
            echo "$subdomain" >> "$ALIVE_FILE"
        fi
    done < "$SUBDOMAINS_FILE"
fi

ALIVE_COUNT=$(wc -l < "$ALIVE_FILE" 2>/dev/null || echo "0")
echo -e "${GREEN}[+] Subdomínios vivos: $ALIVE_COUNT${NC}"

echo -e "${GREEN}[+] Recon concluído!${NC}"
echo -e "${GREEN}[+] Arquivos gerados:${NC}"
echo -e "  - $SUBDOMAINS_FILE"
echo -e "  - $ALIVE_FILE"
echo -e "  - $HTTP_INFO_FILE"
