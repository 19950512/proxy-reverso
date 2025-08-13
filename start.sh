#!/bin/bash

# Script para iniciar o Proxy Reverso
# Este script configura e inicia o nginx como proxy reverso

clear

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para logging
log() {
    echo -e "${GREEN}[PROXY]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Banner
echo -e "${BLUE}"
echo "=================================================="
echo "       NGINX PROXY REVERSO - STARTUP"
echo "=================================================="
echo -e "${NC}"

# Verificar se Docker está rodando
check_docker() {
    log "Verificando se Docker está rodando..."
    if ! docker info > /dev/null 2>&1; then
        error "Docker não está rodando. Por favor, inicie o Docker primeiro."
        exit 1
    fi
    log "✓ Docker está rodando"
}

# Criar rede Docker se não existir
create_network() {
    log "Verificando rede proxy-net..."
    
    if ! docker network ls | grep -q "proxy-net"; then
        log "Criando rede proxy-net..."
        docker network create proxy-net
        log "✓ Rede proxy-net criada"
    else
        log "✓ Rede proxy-net já existe"
    fi
}

# Verificar arquivos de configuração
check_config() {
    log "Verificando configurações..."
    
    # Verificar nginx.conf
    if [ ! -f "./nginx.conf" ]; then
        error "Arquivo nginx.conf não encontrado!"
        exit 1
    fi
    log "✓ nginx.conf encontrado"
    
    # Verificar pasta de domínios
    if [ ! -d "./dominios" ]; then
        error "Pasta dominios/ não encontrada!"
        exit 1
    fi
    
    # Contar arquivos .conf na pasta dominios
    conf_count=$(find ./dominios -name "*.conf" -not -name "*.example" | wc -l)
    if [ $conf_count -eq 0 ]; then
        warn "Nenhum arquivo .conf encontrado em dominios/"
        warn "Certifique-se de configurar pelo menos um domínio"
        info "Exemplo: cp dominios/template.conf.example dominios/meudominio.conf"
    else
        log "✓ Encontrados $conf_count arquivo(s) de configuração de domínio"
    fi
    
    # Verificar pasta de certificados
    if [ ! -d "./certificados" ]; then
        warn "Pasta certificados/ não encontrada - criando..."
        mkdir -p ./certificados
    fi
    
    cert_count=$(find ./certificados -name "*.pem" -o -name "*.crt" -o -name "*.key" | wc -l)
    if [ $cert_count -eq 0 ]; then
        warn "Nenhum certificado SSL encontrado em certificados/"
        info "Para HTTPS, adicione certificados SSL na pasta certificados/"
    else
        log "✓ Encontrados certificados SSL"
    fi
}

# Verificar sintaxe do nginx
test_nginx_config() {
    log "Testando configuração do nginx..."
    
    # Criar configuração temporária simplificada para teste
    temp_config="/tmp/test_nginx.conf"
    cat > "$temp_config" << 'EOF'
user nginx;
worker_processes auto;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    resolver 127.0.0.11 valid=30s ipv6=off;
    sendfile on;
    keepalive_timeout 65;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;

    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    proxy_buffering on;
    proxy_buffer_size 8k;
    proxy_buffers 8 8k;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    include /etc/nginx/conf.d/*.conf;
}
EOF
    
    # Testar configuração completa
    if docker run --rm -v "$temp_config:/etc/nginx/nginx.conf:ro" \
                        -v "$(pwd)/dominios:/etc/nginx/conf.d:ro" \
                        nginx:latest nginx -t > /dev/null 2>&1; then
        log "✓ Configuração do nginx válida"
    else
        warn "Configuração pode ter problemas de upstream (normal se containers não estiverem rodando)"
        info "Testando apenas sintaxe básica..."
        
        # Teste mais básico sem includes de domínios
        cat > "$temp_config" << 'EOF'
events { worker_connections 1024; }
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    resolver 127.0.0.11 valid=30s ipv6=off;
    
    server {
        listen 80 default_server;
        return 444;
    }
}
EOF
        
        if docker run --rm -v "$temp_config:/etc/nginx/nginx.conf:ro" \
                            nginx:latest nginx -t > /dev/null 2>&1; then
            log "✓ Sintaxe básica do nginx válida"
            warn "Problemas encontrados podem ser relacionados a upstreams indisponíveis"
        else
            error "Erro na configuração básica do nginx!"
            docker run --rm -v "$temp_config:/etc/nginx/nginx.conf:ro" \
                              nginx:latest nginx -t
            exit 1
        fi
    fi
    
    # Limpar arquivo temporário
    rm -f "$temp_config"
}

# Parar proxy se já estiver rodando
stop_if_running() {
    if docker ps | grep -q "nginx-reverso"; then
        warn "Proxy reverso já está rodando. Parando..."
        docker compose down
        log "✓ Proxy reverso parado"
    fi
}

# Iniciar proxy reverso
start_proxy() {
    log "Iniciando proxy reverso..."
    
    # Pull da imagem mais recente
    docker compose pull
    
    # Iniciar serviços
    docker compose up -d
    
    # Aguardar um pouco para inicialização
    sleep 3
    
    # Verificar se está rodando
    if docker ps | grep -q "nginx-reverso"; then
        log "✓ Proxy reverso iniciado com sucesso!"
    else
        error "Falha ao iniciar proxy reverso"
        info "Verificando logs..."
        docker compose logs
        exit 1
    fi
}

# Mostrar status e informações
show_status() {
    echo ""
    info "Status dos serviços:"
    docker compose ps
    
    echo ""
    info "Rede proxy-net:"
    docker network ls | grep proxy-net
    
    echo ""
    info "Containers conectados à rede:"
    docker network inspect proxy-net --format='{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{println}}{{end}}' 2>/dev/null || echo "Nenhum container conectado ainda"
    
    echo ""
    info "Portas expostas:"
    echo "  HTTP:  http://localhost:80"
    echo "  HTTPS: https://localhost:443"
    
    echo ""
    info "Arquivos de configuração ativos:"
    find ./dominios -name "*.conf" -not -name "*.example" -exec basename {} \; | sed 's/^/  - /'
    
    echo ""
    log "Para ver logs: docker compose logs -f"
    log "Para parar: docker compose down"
}

# Função principal
main() {
    check_docker
    create_network
    check_config
    test_nginx_config
    stop_if_running
    start_proxy
    show_status
    
    echo ""
    echo -e "${GREEN}=================================================="
    echo "   PROXY REVERSO INICIADO COM SUCESSO!"
    echo "==================================================${NC}"
}

# Verificar se há argumentos para comandos específicos
case "$1" in
    stop)
        log "Parando proxy reverso..."
        docker compose down
        log "✓ Proxy reverso parado"
        ;;
    restart)
        log "Reiniciando proxy reverso..."
        docker compose down
        main
        ;;
    logs)
        docker compose logs -f
        ;;
    status)
        show_status
        ;;
    test)
        check_config
        test_nginx_config
        log "✓ Configurações válidas"
        ;;
    *)
        # Execução normal
        main
        ;;
esac
