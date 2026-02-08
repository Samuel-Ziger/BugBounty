#!/bin/bash

# Param mining + filtering
# Usa: gau, waybackurls, katana
# Extrai parâmetros, deduplica, classifica (GET / POST)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(dirname "$SCRIPT_DIR")"
DOMAINS_FILE="$FRAMEWORK_DIR/domains.txt"
ALIVE_FILE="$FRAMEWORK_DIR/output/subdomains_alive.txt"
OUTPUT_DIR="$FRAMEWORK_DIR/output/params"
URLS_FILE="$OUTPUT_DIR/all_urls.txt"
PARAMS_FILE="$OUTPUT_DIR/parameters.txt"
GET_PARAMS="$OUTPUT_DIR/get_params.txt"
POST_PARAMS="$OUTPUT_DIR/post_params.txt"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}[+] Iniciando param mining${NC}"

# Criar diretório de output
mkdir -p "$OUTPUT_DIR"

# Limpar arquivos anteriores
> "$URLS_FILE"
> "$PARAMS_FILE"
> "$GET_PARAMS"
> "$POST_PARAMS"

# Ler domínios
DOMAINS=$(grep -v '^#' "$DOMAINS_FILE" | grep -v '^$' | tr '\n' ' ')

if [ -z "$DOMAINS" ]; then
    echo -e "${RED}[-] Nenhum domínio encontrado em domains.txt${NC}"
    exit 1
fi

# GAU - Get All URLs
echo -e "${GREEN}[+] Executando gau...${NC}"
for domain in $DOMAINS; do
    if command -v gau &> /dev/null; then
        gau "$domain" --subs >> "$URLS_FILE" 2>/dev/null || true
    else
        echo -e "${YELLOW}[!] gau não encontrado, pulando...${NC}"
    fi
done

# Waybackurls
echo -e "${GREEN}[+] Executando waybackurls...${NC}"
for domain in $DOMAINS; do
    if command -v waybackurls &> /dev/null; then
        waybackurls "$domain" >> "$URLS_FILE" 2>/dev/null || true
    else
        echo -e "${YELLOW}[!] waybackurls não encontrado, pulando...${NC}"
    fi
done

# Katana - Crawling
echo -e "${GREEN}[+] Executando katana...${NC}"
if [ -f "$ALIVE_FILE" ]; then
    if command -v katana &> /dev/null; then
        katana -list "$ALIVE_FILE" \
            -depth 3 \
            -js-crawl \
            -forms \
            -silent \
            >> "$URLS_FILE" 2>/dev/null || true
    else
        echo -e "${YELLOW}[!] katana não encontrado, pulando...${NC}"
    fi
fi

# Remover duplicatas
echo -e "${GREEN}[+] Removendo duplicatas...${NC}"
sort -u "$URLS_FILE" -o "$URLS_FILE"

URLS_COUNT=$(wc -l < "$URLS_FILE")
echo -e "${GREEN}[+] Total de URLs encontradas: $URLS_COUNT${NC}"

# Extrair parâmetros
echo -e "${GREEN}[+] Extraindo parâmetros...${NC}"

# Extrair parâmetros GET
grep -oP '\?[^#\s]*' "$URLS_FILE" | sed 's/?//' | sort -u > "$GET_PARAMS" 2>/dev/null || true

# Extrair parâmetros únicos (nomes)
cat "$GET_PARAMS" | cut -d'=' -f1 | sort -u > "$PARAMS_FILE" 2>/dev/null || true

# Tentar identificar POST (formulários encontrados pelo katana)
if command -v grep &> /dev/null; then
    grep -i "method.*post\|action.*post" "$URLS_FILE" | \
        grep -oP 'name=["\x27][^"\x27]*' | \
        sed 's/name=["\x27]//' | \
        sort -u > "$POST_PARAMS" 2>/dev/null || true
fi

# Usar arjun ou paramspider se disponível para extrair mais parâmetros
echo -e "${GREEN}[+] Extraindo parâmetros adicionais...${NC}"

# ParamSpider
if command -v paramspider &> /dev/null; then
    for domain in $DOMAINS; do
        paramspider -d "$domain" --level 2 --exclude png,jpg,gif,jpeg,svg,css,js >> "$PARAMS_FILE" 2>/dev/null || true
    done
fi

# Arjun (se tiver URLs específicas)
if command -v arjun &> /dev/null && [ -f "$ALIVE_FILE" ]; then
    head -10 "$ALIVE_FILE" | while read -r url; do
        if [ -n "$url" ]; then
            if [[ ! "$url" =~ ^https?:// ]]; then
                url="http://$url"
            fi
            arjun -u "$url" -oT "$OUTPUT_DIR/arjun_${url//\//_}.txt" 2>/dev/null || true
        fi
    done
fi

# Remover duplicatas finais
sort -u "$PARAMS_FILE" -o "$PARAMS_FILE"
sort -u "$GET_PARAMS" -o "$GET_PARAMS"
sort -u "$POST_PARAMS" -o "$POST_PARAMS"

PARAMS_COUNT=$(wc -l < "$PARAMS_FILE" 2>/dev/null || echo "0")
GET_COUNT=$(wc -l < "$GET_PARAMS" 2>/dev/null || echo "0")
POST_COUNT=$(wc -l < "$POST_PARAMS" 2>/dev/null || echo "0")

echo -e "${GREEN}[+] Param mining concluído!${NC}"
echo -e "${GREEN}[+] Estatísticas:${NC}"
echo -e "  - Parâmetros únicos: $PARAMS_COUNT"
echo -e "  - URLs com GET: $GET_COUNT"
echo -e "  - Parâmetros POST: $POST_COUNT"
echo -e "${GREEN}[+] Arquivos gerados em: $OUTPUT_DIR${NC}"
