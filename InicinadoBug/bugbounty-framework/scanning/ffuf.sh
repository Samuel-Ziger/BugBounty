#!/bin/bash

# Content discovery com ffuf
# Diretórios, parâmetros, APIs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(dirname "$SCRIPT_DIR")"
ALIVE_FILE="$FRAMEWORK_DIR/output/subdomains_alive.txt"
OUTPUT_DIR="$FRAMEWORK_DIR/output/ffuf"
WORDLIST_DIR="$FRAMEWORK_DIR/tools/wordlists"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configurações padrão
MODE="${1:-directory}"  # directory, parameter, api
WORDLIST="${2:-/usr/share/wordlists/dirb/common.txt}"
EXTENSIONS="${3:-php,html,js,txt,xml,json}"

echo -e "${GREEN}[+] Iniciando content discovery com ffuf${NC}"
echo -e "${YELLOW}[*] Modo: $MODE${NC}"
echo -e "${YELLOW}[*] Wordlist: $WORDLIST${NC}"

# Verificar se ffuf está instalado
if ! command -v ffuf &> /dev/null; then
    echo -e "${RED}[-] ffuf não encontrado!${NC}"
    echo -e "${YELLOW}[*] Instale: go install github.com/ffuf/ffuf/v2@latest${NC}"
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

# Verificar se wordlist existe
if [ ! -f "$WORDLIST" ]; then
    echo -e "${YELLOW}[!] Wordlist não encontrada: $WORDLIST${NC}"
    echo -e "${YELLOW}[*] Usando wordlist padrão do sistema...${NC}"
    WORDLIST="/usr/share/wordlists/dirb/common.txt"
    
    if [ ! -f "$WORDLIST" ]; then
        echo -e "${RED}[-] Wordlist padrão também não encontrada!${NC}"
        echo -e "${YELLOW}[*] Baixe uma wordlist ou especifique o caminho${NC}"
        exit 1
    fi
fi

# Processar cada URL
while IFS= read -r url; do
    if [ -z "$url" ]; then
        continue
    fi
    
    # Adicionar protocolo se não tiver
    if [[ ! "$url" =~ ^https?:// ]]; then
        url="http://$url"
    fi
    
    # Nome do arquivo de saída baseado na URL
    output_name=$(echo "$url" | sed 's|https\?://||' | sed 's|/|_|g' | sed 's|:|_|g')
    
    echo -e "${GREEN}[+] Escaneando: $url${NC}"
    
    case "$MODE" in
        directory)
            # Fuzzing de diretórios
            ffuf -u "${url}/FUZZ" \
                -w "$WORDLIST" \
                -e "$EXTENSIONS" \
                -mc 200,204,301,302,307,401,403 \
                -c \
                -o "$OUTPUT_DIR/${output_name}_directories.json" \
                -of json \
                -t 50 \
                -timeout 10 \
                -s \
                2>/dev/null || true
            ;;
        parameter)
            # Fuzzing de parâmetros
            ffuf -u "${url}?FUZZ=test" \
                -w "$WORDLIST" \
                -mc 200,204,301,302,307,401,403 \
                -c \
                -o "$OUTPUT_DIR/${output_name}_parameters.json" \
                -of json \
                -t 50 \
                -timeout 10 \
                -s \
                2>/dev/null || true
            ;;
        api)
            # Fuzzing de endpoints de API
            ffuf -u "${url}/api/v1/FUZZ" \
                -w "$WORDLIST" \
                -mc 200,201,204,301,302,401,403 \
                -c \
                -o "$OUTPUT_DIR/${output_name}_api.json" \
                -of json \
                -t 50 \
                -timeout 10 \
                -s \
                2>/dev/null || true
            ;;
        *)
            echo -e "${RED}[-] Modo inválido: $MODE${NC}"
            echo -e "${YELLOW}[*] Modos disponíveis: directory, parameter, api${NC}"
            exit 1
            ;;
    esac
done < "$ALIVE_FILE"

echo -e "${GREEN}[+] Content discovery concluído!${NC}"
echo -e "${GREEN}[+] Resultados salvos em: $OUTPUT_DIR${NC}"
