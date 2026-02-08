#!/bin/bash

# Orquestrador principal
# Executa tudo em ordem
# Cache inteligente
# Retry automático

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOMAINS_FILE="$SCRIPT_DIR/domains.txt"
OUTPUT_DIR="$SCRIPT_DIR/output"
CACHE_DIR="$SCRIPT_DIR/.cache"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Função de ajuda
show_help() {
    echo -e "${GREEN}BugBounty Framework - Orquestrador${NC}"
    echo ""
    echo "Uso: ./run.sh [comando] [opções]"
    echo ""
    echo "Comandos disponíveis:"
    echo "  recon          - Executa recon completo (subdomínios + screenshots)"
    echo "  scanning       - Executa scanning (nuclei + ffuf)"
    echo "  exploitation   - Executa testes de exploração (xss + ssrf)"
    echo "  all            - Executa tudo em ordem"
    echo "  params         - Extrai parâmetros"
    echo "  enrich         - Enriquecimento de contexto"
    echo "  filter         - Filtra endpoints"
    echo "  score          - Calcula risk score"
    echo "  normalize      - Normaliza outputs"
    echo ""
    echo "Exemplos:"
    echo "  ./run.sh recon"
    echo "  ./run.sh all"
    echo "  ./run.sh scanning"
}

# Verificar se domains.txt existe
check_domains() {
    if [ ! -f "$DOMAINS_FILE" ]; then
        echo -e "${RED}[-] Arquivo domains.txt não encontrado!${NC}"
        echo -e "${YELLOW}[*] Crie o arquivo domains.txt na raiz do framework${NC}"
        exit 1
    fi
    
    DOMAINS=$(grep -v '^#' "$DOMAINS_FILE" | grep -v '^$' | wc -l)
    if [ "$DOMAINS" -eq 0 ]; then
        echo -e "${RED}[-] Nenhum domínio encontrado em domains.txt!${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}[+] $DOMAINS domínio(s) encontrado(s)${NC}"
}

# Criar estrutura de diretórios
setup_directories() {
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$CACHE_DIR"
    mkdir -p "$OUTPUT_DIR/recon"
    mkdir -p "$OUTPUT_DIR/scanning"
    mkdir -p "$OUTPUT_DIR/exploitation"
    mkdir -p "$OUTPUT_DIR/utils"
}

# Função para executar com retry
run_with_retry() {
    local script_path="$1"
    shift
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if bash "$script_path" "$@"; then
            return 0
        else
            retry=$((retry + 1))
            if [ $retry -lt $max_retries ]; then
                echo -e "${YELLOW}[!] Tentativa $retry falhou, tentando novamente...${NC}"
                sleep 2
            fi
        fi
    done
    
    echo -e "${RED}[-] Comando falhou após $max_retries tentativas${NC}"
    return 1
}

# Comando: recon
cmd_recon() {
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}[+] Executando RECON${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    
    run_with_retry "$SCRIPT_DIR/recon/run.sh"
    
    echo ""
    echo -e "${GREEN}[+] Capturando screenshots...${NC}"
    run_with_retry "$SCRIPT_DIR/recon/screenshots.sh"
    
    echo -e "${GREEN}[+] Recon concluído!${NC}"
}

# Comando: params
cmd_params() {
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}[+] Extraindo parâmetros${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    
    run_with_retry "$SCRIPT_DIR/recon/params.sh"
    
    echo -e "${GREEN}[+] Extração de parâmetros concluída!${NC}"
}

# Comando: enrich
cmd_enrich() {
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}[+] Enriquecendo contexto${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    
    run_with_retry "$SCRIPT_DIR/recon/enrich.sh"
    
    echo -e "${GREEN}[+] Enriquecimento concluído!${NC}"
}

# Comando: filter
cmd_filter() {
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}[+] Filtrando endpoints${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    
    run_with_retry "$SCRIPT_DIR/utils/filter_endpoints.sh"
    
    echo -e "${GREEN}[+] Filtragem concluída!${NC}"
}

# Comando: scanning
cmd_scanning() {
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}[+] Executando SCANNING${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    
    echo -e "${GREEN}[+] Executando Nuclei...${NC}"
    run_with_retry "$SCRIPT_DIR/scanning/nuclei.sh" "high,critical"
    
    echo ""
    echo -e "${GREEN}[+] Executando FFuf...${NC}"
    run_with_retry "$SCRIPT_DIR/scanning/ffuf.sh" "directory"
    
    echo -e "${GREEN}[+] Scanning concluído!${NC}"
}

# Comando: exploitation
cmd_exploitation() {
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}[+] Executando EXPLOITATION${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    
    echo -e "${GREEN}[+] Testando XSS...${NC}"
    run_with_retry "$SCRIPT_DIR/exploitation/xss.sh"
    
    echo ""
    echo -e "${GREEN}[+] Testando SSRF...${NC}"
    run_with_retry "$SCRIPT_DIR/exploitation/ssrf.sh"
    
    echo -e "${GREEN}[+] Exploitation concluído!${NC}"
}

# Comando: score
cmd_score() {
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}[+] Calculando risk score${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    
    run_with_retry "$SCRIPT_DIR/utils/score.sh"
    
    echo -e "${GREEN}[+] Risk scoring concluído!${NC}"
}

# Comando: normalize
cmd_normalize() {
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}[+] Normalizando outputs${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    
    run_with_retry "$SCRIPT_DIR/utils/normalize.sh" "json"
    
    echo -e "${GREEN}[+] Normalização concluída!${NC}"
}

# Comando: all
cmd_all() {
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}[+] Executando pipeline completo${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo ""
    
    # 1. Recon
    cmd_recon
    echo ""
    
    # 2. Params
    cmd_params
    echo ""
    
    # 3. Enrich
    cmd_enrich
    echo ""
    
    # 4. Filter
    cmd_filter
    echo ""
    
    # 5. Scanning
    cmd_scanning
    echo ""
    
    # 6. Exploitation
    cmd_exploitation
    echo ""
    
    # 7. Score
    cmd_score
    echo ""
    
    # 8. Normalize
    cmd_normalize
    echo ""
    
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}[+] Pipeline completo concluído!${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}[+] Resumo:${NC}"
    echo -e "  - Subdomínios: $OUTPUT_DIR/subdomains.txt"
    echo -e "  - Vivos: $OUTPUT_DIR/subdomains_alive.txt"
    echo -e "  - Alto risco: $OUTPUT_DIR/high_risk_endpoints.txt"
    echo -e "  - Normalizados: $OUTPUT_DIR/normalized/"
}

# Main
main() {
    # Verificar domínios
    check_domains
    
    # Criar diretórios
    setup_directories
    
    # Processar comando
    COMMAND="${1:-help}"
    
    case "$COMMAND" in
        recon)
            cmd_recon
            ;;
        params)
            cmd_params
            ;;
        enrich)
            cmd_enrich
            ;;
        filter)
            cmd_filter
            ;;
        scanning)
            cmd_scanning
            ;;
        exploitation)
            cmd_exploitation
            ;;
        score)
            cmd_score
            ;;
        normalize)
            cmd_normalize
            ;;
        all)
            cmd_all
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}[-] Comando inválido: $COMMAND${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Executar
main "$@"
