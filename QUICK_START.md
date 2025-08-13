# 🚀 Quick Start - Proxy Reverso

## Comandos Principais

```bash
# Iniciar o proxy reverso
./start.sh

# Parar o proxy
./start.sh stop

# Reiniciar o proxy
./start.sh restart

# Ver logs em tempo real
./start.sh logs

# Ver status dos serviços
./start.sh status

# Testar configurações
./start.sh test
```

## ⚡ Configuração Rápida de Novo Domínio

### 1. HTTP (Desenvolvimento)
```bash
# Copiar template
cp dominios/urbamar.conf dominios/meusite.conf

# Editar o arquivo
nano dominios/meusite.conf

# Alterar:
# - server_name para: meusite.com.br
# - $upstream para: meu-container:3000

# Recarregar configuração
./start.sh restart
```

### 2. HTTPS (Produção)
```bash
# Copiar template HTTPS
cp dominios/template.conf.example dominios/meusite.conf

# Adicionar certificados em certificados/
# - meusite_cert.pem
# - meusite_key.pem

# Editar configuração
nano dominios/meusite.conf

# Alterar:
# - server_name para: meusite.com.br
# - ssl_certificate para: /etc/ssl/certs/cloudflare/meusite_cert.pem
# - ssl_certificate_key para: /etc/ssl/certs/cloudflare/meusite_key.pem
# - $upstream para: meu-container:3000

# Recarregar configuração
./start.sh restart
```

## 🔗 Conectar Aplicação à Rede

No `docker-compose.yml` da sua aplicação:

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

## 🧪 Testar Configuração

```bash
# Testar se proxy responde
curl -H "Host: meusite.com.br" http://localhost/

# Testar HTTPS (se configurado)
curl -k -H "Host: meusite.com.br" https://localhost/
```

## 📝 Status Atual

✅ **Rede criada**: `proxy-net`  
✅ **Proxy rodando**: nginx-reverso  
✅ **Portas expostas**: 80 (HTTP) e 443 (HTTPS)  
✅ **Configuração ativa**: urbamar.conf  

## 🆘 Problemas Comuns

- **502 Bad Gateway**: Container de destino não está rodando ou não está na rede `proxy-net`
- **503 Maintenance**: Comportamento normal quando upstream não está disponível
- **Container reiniciando**: Verificar logs com `./start.sh logs`

Para mais detalhes, consulte `PROXY_README.md`
