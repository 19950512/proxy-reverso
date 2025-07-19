# 🧭 NGINX Reverso Compartilhado para Múltiplos Projetos Docker

Este repositório contém a configuração de um **NGINX reverso** para hospedar **vários projetos Docker em um único servidor (EC2/Droplet/VPS)**, todos acessando a mesma porta `80`.

A ideia é centralizar o NGINX como **gateway principal** para as requisições HTTP, e ele irá **rotear os domínios para os containers corretos**, como `projeto1.com.br`, `projeto2.com.br`, etc.

---

## 🧠 Como Funciona

- O container `nginx-reverso` escuta nas portas `80` e `443`.
- Cada projeto roda em sua própria porta interna (`3000`, `3001`, etc), sem expor nada para o host.
- O NGINX compartilha uma **rede Docker externa** com os containers dos projetos.
- Cada domínio tem sua própria configuração separada em `dominios/nome-do-projeto.conf`.

---

## 📁 Estrutura

```
nginx/
├── docker-compose.yml       # Container do NGINX reverso
├── nginx.conf               # Configuração principal que importa os domínios
└── dominios/
    ├── projeto1.conf         # Proxy para o projeto projeto1
    ├── projeto2.conf        # Proxy para outro projeto
    └── ...
```

---

## ✅ Pré-requisitos

Antes de subir os serviços, **crie a rede externa compartilhada**:

```bash
docker network create proxy-net
```

---

## 🚀 Subindo o NGINX

```bash
docker compose up -d
```

---

## 🌐 Domínios e DNS

Certifique-se de que os domínios configurados nos arquivos `.conf` (ex: `projeto1.com.br`) apontam para o IP da sua EC2.

Se estiver testando localmente, adicione ao `/etc/hosts`:

```
127.0.0.1 projeto1.com.br
127.0.0.1 projeto2.com.br
```

---

## 📦 Exemplo de domínio (projeto1.conf)

```nginx
server {
  listen 80;
  server_name projeto1.com.br www.projeto1.com.br;

  location / {
    proxy_pass http://projeto1:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }
}
```

---

## 👨‍🔧 Conectando os projetos

Cada projeto deve expor sua porta internamente e usar a rede `proxy-net`:

```yaml
services:
  app:
    build: .
    container_name: projeto1
    expose:
      - "3000"
    networks:
      - proxy-net

networks:
  proxy-net:
    external: true
```