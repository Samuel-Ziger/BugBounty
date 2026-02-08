#!/bin/bash

# Screenshot automático
# Usa gowitness ou aquatone para criar contexto visual rápido

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(dirname "$SCRIPT_DIR")"
ALIVE_FILE="$FRAMEWORK_DIR/output/subdomains_alive.txt"
SCREENSHOTS_DIR="$FRAMEWORK_DIR/output/screenshots"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}[+] Iniciando captura de screenshots${NC}"

# Verificar se existe arquivo de subdomínios vivos
if [ ! -f "$ALIVE_FILE" ]; then
    echo -e "${RED}[-] Arquivo subdomains_alive.txt não encontrado!${NC}"
    echo -e "${YELLOW}[*] Execute primeiro: ./recon/run.sh${NC}"
    exit 1
fi

# Criar diretório de screenshots
mkdir -p "$SCREENSHOTS_DIR"

# Tentar usar gowitness primeiro
if command -v gowitness &> /dev/null; then
    echo -e "${GREEN}[+] Usando gowitness...${NC}"
    gowitness file -f "$ALIVE_FILE" \
        --destination "$SCREENSHOTS_DIR" \
        --threads 5 \
        --timeout 10 \
        --screenshot-path "$SCREENSHOTS_DIR" 2>/dev/null || true
    
    echo -e "${GREEN}[+] Screenshots salvos em: $SCREENSHOTS_DIR${NC}"
    exit 0
fi

# Tentar usar aquatone
if command -v aquatone &> /dev/null; then
    echo -e "${GREEN}[+] Usando aquatone...${NC}"
    cat "$ALIVE_FILE" | aquatone \
        -out "$SCREENSHOTS_DIR" \
        -screenshot-timeout 10000 \
        -threads 5 2>/dev/null || true
    
    echo -e "${GREEN}[+] Screenshots salvos em: $SCREENSHOTS_DIR${NC}"
    exit 0
fi

# Fallback: usar cutycapt ou wkhtmltoimage
if command -v cutycapt &> /dev/null; then
    echo -e "${GREEN}[+] Usando cutycapt...${NC}"
    while IFS= read -r url; do
        if [ -n "$url" ]; then
            # Adicionar http:// se não tiver protocolo
            if [[ ! "$url" =~ ^https?:// ]]; then
                url="http://$url"
            fi
            filename=$(echo "$url" | sed 's|https\?://||' | sed 's|/|_|g' | sed 's|:|_|g')
            cutycapt --url="$url" --out="$SCREENSHOTS_DIR/${filename}.png" 2>/dev/null || true
        fi
    done < "$ALIVE_FILE"
    echo -e "${GREEN}[+] Screenshots salvos em: $SCREENSHOTS_DIR${NC}"
    exit 0
fi

if command -v wkhtmltoimage &> /dev/null; then
    echo -e "${GREEN}[+] Usando wkhtmltoimage...${NC}"
    while IFS= read -r url; do
        if [ -n "$url" ]; then
            if [[ ! "$url" =~ ^https?:// ]]; then
                url="http://$url"
            fi
            filename=$(echo "$url" | sed 's|https\?://||' | sed 's|/|_|g' | sed 's|:|_|g')
            wkhtmltoimage --width 1920 --height 1080 "$url" "$SCREENSHOTS_DIR/${filename}.png" 2>/dev/null || true
        fi
    done < "$ALIVE_FILE"
    echo -e "${GREEN}[+] Screenshots salvos em: $SCREENSHOTS_DIR${NC}"
    exit 0
fi

echo -e "${RED}[-] Nenhuma ferramenta de screenshot encontrada!${NC}"
echo -e "${YELLOW}[*] Instale uma das seguintes:${NC}"
echo -e "  - gowitness: go install github.com/sensepost/gowitness@latest"
echo -e "  - aquatone: https://github.com/michenriksen/aquatone"
echo -e "  - cutycapt: apt install cutycapt"
echo -e "  - wkhtmltoimage: apt install wkhtmltopdf"
exit 1
