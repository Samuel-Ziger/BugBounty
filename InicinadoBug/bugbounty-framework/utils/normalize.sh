#!/bin/bash

# Normalizador de output
# Padroniza: JSON, TXT, CSV
# Ferramentas falam línguas diferentes. Seu framework fala uma só.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$FRAMEWORK_DIR/output"
NORMALIZED_DIR="$OUTPUT_DIR/normalized"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}[+] Normalizando outputs${NC}"

# Criar diretório normalizado
mkdir -p "$NORMALIZED_DIR"

# Formato padrão: JSON
OUTPUT_FORMAT="${1:-json}"

# Função para normalizar arquivos JSON
normalize_json() {
    local input_file="$1"
    local output_file="$2"
    
    if [ ! -f "$input_file" ] || [ ! -s "$input_file" ]; then
        return
    fi
    
    # Se já for JSON válido, apenas formatar
    if command -v jq &> /dev/null; then
        jq '.' "$input_file" > "$output_file" 2>/dev/null || {
            # Se não for JSON válido, tentar converter
            echo "[]" > "$output_file"
            while IFS= read -r line; do
                if [ -n "$line" ]; then
                    echo "{\"value\":\"$line\"}" | jq '.' >> "$output_file" 2>/dev/null || true
                fi
            done < "$input_file"
        }
    else
        # Fallback: criar JSON simples
        echo "[" > "$output_file"
        first=true
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                if [ "$first" = true ]; then
                    first=false
                else
                    echo "," >> "$output_file"
                fi
                echo -n "{\"value\":\"$line\"}" >> "$output_file"
            fi
        done < "$input_file"
        echo "" >> "$output_file"
        echo "]" >> "$output_file"
    fi
}

# Função para normalizar para CSV
normalize_csv() {
    local input_file="$1"
    local output_file="$2"
    
    if [ ! -f "$input_file" ] || [ ! -s "$input_file" ]; then
        return
    fi
    
    # Se for JSON, converter para CSV
    if command -v jq &> /dev/null && jq empty "$input_file" 2>/dev/null; then
        jq -r 'if type == "array" then .[] | [.url // .value // .] | @csv else [.] | @csv end' "$input_file" > "$output_file" 2>/dev/null || true
    else
        # Se for texto simples, criar CSV com uma coluna
        echo "value" > "$output_file"
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                echo "\"$line\"" >> "$output_file"
            fi
        done < "$input_file"
    fi
}

# Função para normalizar para TXT
normalize_txt() {
    local input_file="$1"
    local output_file="$2"
    
    if [ ! -f "$input_file" ] || [ ! -s "$input_file" ]; then
        return
    fi
    
    # Se for JSON, extrair valores
    if command -v jq &> /dev/null && jq empty "$input_file" 2>/dev/null; then
        jq -r '.url // .value // .' "$input_file" > "$output_file" 2>/dev/null || true
    else
        # Se já for texto, apenas copiar
        cp "$input_file" "$output_file" 2>/dev/null || true
    fi
}

# Normalizar arquivos principais
echo -e "${BLUE}[*] Normalizando subdomínios...${NC}"
if [ -f "$OUTPUT_DIR/subdomains.txt" ]; then
    normalize_${OUTPUT_FORMAT} "$OUTPUT_DIR/subdomains.txt" "$NORMALIZED_DIR/subdomains.${OUTPUT_FORMAT}"
fi

if [ -f "$OUTPUT_DIR/subdomains_alive.txt" ]; then
    normalize_${OUTPUT_FORMAT} "$OUTPUT_DIR/subdomains_alive.txt" "$NORMALIZED_DIR/subdomains_alive.${OUTPUT_FORMAT}"
fi

echo -e "${BLUE}[*] Normalizando HTTP info...${NC}"
if [ -f "$OUTPUT_DIR/http_info.json" ]; then
    normalize_json "$OUTPUT_DIR/http_info.json" "$NORMALIZED_DIR/http_info.json"
fi

echo -e "${BLUE}[*] Normalizando parâmetros...${NC}"
if [ -f "$OUTPUT_DIR/params/parameters.txt" ]; then
    normalize_${OUTPUT_FORMAT} "$OUTPUT_DIR/params/parameters.txt" "$NORMALIZED_DIR/parameters.${OUTPUT_FORMAT}"
fi

echo -e "${BLUE}[*] Normalizando resultados do Nuclei...${NC}"
if [ -f "$OUTPUT_DIR/nuclei/nuclei_all.json" ]; then
    normalize_json "$OUTPUT_DIR/nuclei/nuclei_all.json" "$NORMALIZED_DIR/nuclei_all.json"
fi

echo -e "${BLUE}[*] Normalizando resultados do FFuf...${NC}"
find "$OUTPUT_DIR/ffuf" -name "*.json" 2>/dev/null | while read -r file; do
    filename=$(basename "$file" .json)
    normalize_json "$file" "$NORMALIZED_DIR/ffuf_${filename}.json"
done

echo -e "${BLUE}[*] Normalizando resultados de XSS...${NC}"
if [ -f "$OUTPUT_DIR/xss/vulnerable.txt" ]; then
    normalize_${OUTPUT_FORMAT} "$OUTPUT_DIR/xss/vulnerable.txt" "$NORMALIZED_DIR/xss_vulnerable.${OUTPUT_FORMAT}"
fi

echo -e "${BLUE}[*] Normalizando resultados de SSRF...${NC}"
if [ -f "$OUTPUT_DIR/ssrf/vulnerable.txt" ]; then
    normalize_${OUTPUT_FORMAT} "$OUTPUT_DIR/ssrf/vulnerable.txt" "$NORMALIZED_DIR/ssrf_vulnerable.${OUTPUT_FORMAT}"
fi

echo -e "${GREEN}[+] Normalização concluída!${NC}"
echo -e "${GREEN}[+] Arquivos normalizados salvos em: $NORMALIZED_DIR${NC}"
