# 🎯 BugBounty Framework

Framework completo e automatizado para Bug Bounty, organizado em módulos essenciais, intermediários e avançados.

## 📋 Índice

- [Instalação](#instalação)
- [Configuração](#configuração)
- [Uso](#uso)
- [Estrutura](#estrutura)
- [Scripts](#scripts)
- [Output](#output)

## 🚀 Instalação

### Pré-requisitos

```bash
# Ferramentas essenciais
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/owasp-amass/amass/v4/...@master
go install github.com/tomnomnom/assetfinder@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install github.com/ffuf/ffuf/v2@latest

# Ferramentas de recon
go install github.com/lc/gau/v2/cmd/gau@latest
go install github.com/tomnomnom/waybackurls@latest
go install github.com/projectdiscovery/katana/cmd/katana@latest

# Screenshots
go install github.com/sensepost/gowitness@latest

# XSS
go install github.com/hahwul/dalfox/v2@latest

# Outras ferramentas úteis
sudo apt install jq curl wget
```

### Clone e Setup

```bash
cd bugbounty-framework
chmod +x run.sh recon/*.sh scanning/*.sh exploitation/*.sh utils/*.sh
```

## ⚙️ Configuração

### 1. Adicionar Domínios

Edite o arquivo `domains.txt` na raiz do framework:

```bash
# Adicione seus domínios aqui, um por linha
example.com
target.com
subdomain.target.com
```

## 🎮 Uso

### Comando Principal

```bash
./run.sh [comando]
```

### Comandos Disponíveis

#### 🔍 Recon (Reconhecimento)

```bash
# Recon completo (subdomínios + screenshots)
./run.sh recon

# Ou executar scripts individuais
./recon/run.sh          # Subdomínios vivos + HTTP info
./recon/screenshots.sh  # Screenshots automáticos
./recon/params.sh       # Extração de parâmetros
./recon/enrich.sh       # Enriquecimento de contexto
```

#### 🔎 Scanning

```bash
# Scanning completo
./run.sh scanning

# Ou scripts individuais
./scanning/nuclei.sh high,critical  # Scan com Nuclei
./scanning/ffuf.sh directory        # Content discovery
```

#### 💥 Exploitation

```bash
# Testes de exploração
./run.sh exploitation

# Ou scripts individuais
./exploitation/xss.sh   # Pipeline XSS
./exploitation/ssrf.sh  # Preflight SSRF
```

#### 🛠️ Utilitários

```bash
# Filtrar endpoints
./utils/filter_endpoints.sh

# Verificar subdomínios vivos (robusto)
./utils/alive.sh

# Calcular risk score
./utils/score.sh

# Normalizar outputs
./utils/normalize.sh json
```

#### 🚀 Pipeline Completo

```bash
# Executa tudo em ordem
./run.sh all
```

## 📁 Estrutura

```
bugbounty-framework/
├── domains.txt              # Lista de domínios alvo
├── run.sh                   # Orquestrador principal
│
├── recon/                   # Reconhecimento
│   ├── run.sh              # Recon passivo + ativo
│   ├── screenshots.sh      # Screenshots automáticos
│   ├── params.sh           # Param mining + filtering
│   └── enrich.sh           # Context enrichment
│
├── scanning/               # Scanning
│   ├── nuclei.sh          # Scan com Nuclei
│   └── ffuf.sh            # Content discovery
│
├── exploitation/          # Exploração
│   ├── xss.sh             # XSS pipeline
│   └── ssrf.sh            # SSRF preflight
│
├── utils/                 # Utilitários
│   ├── filter_endpoints.sh # Filtro inteligente
│   ├── alive.sh           # Alive checker robusto
│   ├── normalize.sh       # Normalizador de output
│   └── score.sh           # Risk scoring
│
└── output/                # Resultados
    ├── subdomains.txt
    ├── subdomains_alive.txt
    ├── http_info.json
    ├── params/
    ├── nuclei/
    ├── ffuf/
    ├── xss/
    ├── ssrf/
    └── normalized/
```

## 📜 Scripts Detalhados

### 🔴 Scripts ESSENCIAIS (MVP)

#### 1. `recon/run.sh`
- **Entrada**: `domains.txt`
- **Saída**: 
  - `output/subdomains.txt` - Todos os subdomínios
  - `output/subdomains_alive.txt` - Subdomínios vivos
  - `output/http_info.json` - Informações HTTP detalhadas
- **Ferramentas**: subfinder, amass, assetfinder, httpx

#### 2. `recon/screenshots.sh`
- **Entrada**: `output/subdomains_alive.txt`
- **Saída**: `output/screenshots/`
- **Ferramentas**: gowitness, aquatone, cutycapt, wkhtmltoimage

#### 3. `scanning/nuclei.sh`
- **Entrada**: `output/subdomains_alive.txt`
- **Saída**: 
  - `output/nuclei/nuclei_all.json`
  - `output/nuclei/nuclei_critical.txt`
  - `output/nuclei/nuclei_high.txt`
- **Uso**: `./scanning/nuclei.sh high,critical`

#### 4. `scanning/ffuf.sh`
- **Entrada**: `output/subdomains_alive.txt`
- **Saída**: `output/ffuf/`
- **Modos**: directory, parameter, api
- **Uso**: `./scanning/ffuf.sh directory`

### 🟡 Scripts INTERMEDIÁRIOS

#### 5. `recon/params.sh`
- **Entrada**: `domains.txt`
- **Saída**: 
  - `output/params/all_urls.txt`
  - `output/params/parameters.txt`
  - `output/params/get_params.txt`
  - `output/params/post_params.txt`
- **Ferramentas**: gau, waybackurls, katana, paramspider, arjun

#### 6. `utils/filter_endpoints.sh`
- **Entrada**: `output/subdomains_alive.txt`
- **Saída**: 
  - `output/filtered/endpoints_filtered.txt`
  - `output/filtered/endpoints_priority.txt`
- **Remove**: imagens, css/js
- **Prioriza**: /api/, /admin, /auth, /upload

#### 7. `utils/alive.sh`
- **Entrada**: `output/subdomains.txt`
- **Saída**: 
  - `output/alive/alive.txt`
  - `output/alive/403_bypass_candidates.txt`
  - `output/alive/waf_detected.txt`
  - `output/alive/redirects.txt`
  - `output/alive/auth_walls.txt`

### 🔴 Scripts AVANÇADOS

#### 8. `recon/enrich.sh`
- **Entrada**: `output/subdomains_alive.txt`
- **Saída**: 
  - `output/enrichment/technologies.txt`
  - `output/enrichment/frameworks.txt`
  - `output/enrichment/weak_headers.txt`
  - `output/enrichment/cloud_providers.txt`

#### 9. `exploitation/xss.sh`
- **Entrada**: `output/params/parameters.txt`
- **Saída**: 
  - `output/xss/vulnerable.txt`
  - `output/xss/reflections.txt`
- **Ferramentas**: dalfox (se disponível)

#### 10. `exploitation/ssrf.sh`
- **Entrada**: `output/params/all_urls.txt`
- **Saída**: 
  - `output/ssrf/suspicious_params.txt`
  - `output/ssrf/vulnerable.txt`
- **Testa**: esquemas, IP internos, metadata cloud

### 🧩 Scripts Customizados

#### 11. `run.sh` (Orquestrador)
- Executa tudo em ordem
- Cache inteligente
- Retry automático
- **Uso**: `./run.sh [comando]`

#### 12. `utils/normalize.sh`
- Padroniza outputs (JSON, TXT, CSV)
- **Uso**: `./utils/normalize.sh json`

#### 13. `utils/score.sh`
- Prioriza endpoints por risco
- **Saída**: `output/scored_endpoints.txt`, `output/high_risk_endpoints.txt`

## 📊 Output

Todos os resultados são salvos em `output/`:

```
output/
├── subdomains.txt              # Todos os subdomínios
├── subdomains_alive.txt        # Subdomínios vivos
├── http_info.json              # Informações HTTP
├── screenshots/                # Screenshots
├── params/                     # Parâmetros extraídos
├── nuclei/                     # Resultados Nuclei
├── ffuf/                       # Resultados FFuf
├── xss/                        # Resultados XSS
├── ssrf/                       # Resultados SSRF
├── filtered/                   # Endpoints filtrados
├── alive/                      # Análise de subdomínios
├── enrichment/                  # Enriquecimento
├── scored_endpoints.txt        # Endpoints com score
├── high_risk_endpoints.txt     # Endpoints de alto risco
└── normalized/                # Outputs normalizados
```

## 🔥 Fluxo Recomendado

### 1. Setup Inicial
```bash
# Adicionar domínios
echo "example.com" >> domains.txt
```

### 2. Recon Básico
```bash
./run.sh recon
```

### 3. Extrair Parâmetros
```bash
./run.sh params
```

### 4. Filtrar e Priorizar
```bash
./utils/filter_endpoints.sh
./utils/score.sh
```

### 5. Scanning
```bash
./run.sh scanning
```

### 6. Exploitation
```bash
./run.sh exploitation
```

### 7. Pipeline Completo
```bash
./run.sh all
```

## 💡 Dicas

1. **Sempre revise `high_risk_endpoints.txt` primeiro** - contém os endpoints mais promissores
2. **Use `normalize.sh`** para padronizar outputs antes de análises
3. **Screenshots ajudam muito** - reveja `output/screenshots/` para contexto visual
4. **Parâmetros são ouro** - sempre execute `params.sh` antes de exploitation
5. **Risk score economiza tempo** - foca nos endpoints com maior score primeiro

## 🐛 Troubleshooting

### Erro: "Ferramenta não encontrada"
- Instale a ferramenta faltante usando os comandos em [Instalação](#instalação)

### Erro: "domains.txt não encontrado"
- Crie o arquivo `domains.txt` na raiz do framework

### Scripts não executáveis
```bash
chmod +x run.sh recon/*.sh scanning/*.sh exploitation/*.sh utils/*.sh
```

## 📝 Notas

- Todos os scripts leem domínios de `domains.txt`
- Outputs são salvos em `output/`
- Scripts são idempotentes (podem ser executados múltiplas vezes)
- Use `./run.sh all` para pipeline completo automatizado

## 🤝 Contribuindo

Sinta-se livre para adicionar novos scripts e melhorias!

## 📄 Licença

Uso livre para fins de segurança e Bug Bounty.

---

**Happy Hunting! 🎯**
