# Proxy Reverso - Nginx

Este é um proxy reverso baseado em Nginx para gerenciar múltiplos domínios e aplicações.

## 🚀 Início Rápido

```bash
# Iniciar o proxy reverso
./start.sh

# Comandos adicionais
./start.sh stop      # Parar o proxy
./start.sh restart   # Reiniciar o proxy
./start.sh logs      # Ver logs em tempo real
./start.sh status    # Ver status dos serviços
./start.sh test      # Testar configurações
```

## 📁 Estrutura de Arquivos

```
proxy-reverso/
├── start.sh                    # Script de inicialização
├── docker-compose.yml          # Configuração Docker
├── nginx.conf                  # Configuração principal do Nginx
├── dominios/                   # Configurações por domínio
│   ├── urbamar.conf            # Configuração do urbamar.com.br
│   ├── template.conf.example   # Template com HTTPS
│   └── *.conf                  # Outros domínios
└── certificados/               # Certificados SSL
    ├── *.pem
    ├── *.crt
    └── *.key
```

## ⚙️ Configuração

### 1. Configurar um Novo Domínio

#### Para HTTP (desenvolvimento/teste):
```bash
# Copiar template simples
cp dominios/urbamar.conf dominios/meudominio.conf

# Editar configuração
nano dominios/meudominio.conf
```

Exemplo de configuração HTTP:
```nginx
server {
    listen 80;
    server_name meudominio.com.br www.meudominio.com.br;

    location / {
        proxy_pass http://meu-container:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

#### Para HTTPS (produção):
```bash
# Copiar template completo
cp dominios/template.conf.example dominios/meudominio.conf

# Editar configuração
nano dominios/meudominio.conf
```

### 2. Certificados SSL

Para usar HTTPS, adicione os certificados na pasta `certificados/`:

```bash
# Estrutura esperada
certificados/
├── meudominio_cert.pem      # Certificado
├── meudominio_key.pem       # Chave privada
└── meudominio_fullchain.pem # Cadeia completa (opcional)
```

### 3. Conectar Aplicações

Para que o proxy funcione, suas aplicações devem estar na mesma rede Docker (`proxy-net`).

Exemplo no docker-compose da aplicação:
```yaml
services:
  minha-app:
    # ... outras configurações
    networks:
      - proxy-net

networks:
  proxy-net:
    external: true
```

## 🔧 Comandos Úteis

### Gerenciamento do Proxy
```bash
# Iniciar
./start.sh

# Ver status
./start.sh status

# Ver logs
./start.sh logs

# Testar configuração
./start.sh test

# Reiniciar
./start.sh restart

# Parar
./start.sh stop
```

### Comandos Docker Diretos
```bash
# Ver containers na rede
docker network inspect proxy-net

# Logs específicos
docker-compose logs nginx

# Recarregar configuração nginx (sem reiniciar)
docker-compose exec nginx nginx -s reload

# Testar configuração
docker-compose exec nginx nginx -t
```

## 🛠️ Troubleshooting

### Problemas Comuns

1. **Erro "rede proxy-net não existe"**:
   ```bash
   docker network create proxy-net
   ```

2. **Erro 502 Bad Gateway**:
   - Verificar se a aplicação de destino está rodando
   - Verificar se está na rede `proxy-net`
   - Verificar o nome do container na configuração

3. **Erro de certificado SSL**:
   - Verificar se os arquivos estão na pasta `certificados/`
   - Verificar permissões dos arquivos
   - Verificar caminhos na configuração

4. **Erro de sintaxe nginx**:
   ```bash
   ./start.sh test
   ```

### Logs e Debugging

```bash
# Logs em tempo real
./start.sh logs

# Logs apenas do nginx
docker-compose logs nginx

# Verificar configuração
docker-compose exec nginx nginx -T

# Testar conectividade
curl -H "Host: meudominio.com.br" http://localhost/
```

## 🌐 Exemplos de Configuração

### Aplicação Next.js
```nginx
server {
    listen 80;
    server_name meusite.com.br;

    location / {
        proxy_pass http://nextjs-app:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Para Next.js hot reload
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### API com Rate Limiting
```nginx
# Definir zona de rate limiting
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

server {
    listen 80;
    server_name api.meusite.com.br;

    location /api/ {
        # Rate limiting
        limit_req zone=api burst=20 nodelay;
        
        proxy_pass http://api-container:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

### Servir Arquivos Estáticos + API
```nginx
server {
    listen 80;
    server_name meusite.com.br;

    # Servir arquivos estáticos
    location /static/ {
        alias /var/www/static/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # API backend
    location /api/ {
        proxy_pass http://backend:8080/;
        proxy_set_header Host $host;
    }

    # Frontend
    location / {
        proxy_pass http://frontend:3000/;
        proxy_set_header Host $host;
    }
}
```

## 🔐 Segurança

### Headers de Segurança
```nginx
# Adicionar ao bloco server
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
add_header X-Content-Type-Options "nosniff";
add_header X-Frame-Options "SAMEORIGIN";
add_header X-XSS-Protection "1; mode=block";
add_header Referrer-Policy "strict-origin-when-cross-origin";
```

### SSL/TLS Seguro
```nginx
# Configurações SSL recomendadas
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 1h;
ssl_stapling on;
ssl_stapling_verify on;
```

## 📊 Monitoramento

### Logs do Nginx
Os logs são salvos em `/var/log/nginx/` no container:
- `access.log`: Logs de acesso
- `error.log`: Logs de erro

### Métricas
Para monitoramento avançado, considere adicionar:
- Nginx Amplify
- Prometheus + nginx-prometheus-exporter
- ELK Stack para análise de logs

## 🚀 Deploy em Produção

1. **Configurar domínios reais** em `dominios/*.conf`
2. **Adicionar certificados SSL** em `certificados/`
3. **Configurar DNS** para apontar para o servidor
4. **Usar HTTPS** para todos os domínios
5. **Configurar rate limiting** conforme necessário
6. **Monitorar logs** regularmente

### Exemplo de Firewall (UFW)
```bash
# Permitir HTTP e HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Bloquear acesso direto às aplicações
sudo ufw deny 3000/tcp
sudo ufw deny 8080/tcp
```

O proxy reverso está pronto para uso! Use `./start.sh` para iniciar.
