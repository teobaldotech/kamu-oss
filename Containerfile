```dockerfile
# ============================================================
# Dockerfile PRO
# Django + Python + uv + Tailwind
# ============================================================
#
# Objetivos:
# - Criar uma imagem enxuta para produção.
# - Utilizar uv para gerenciamento das dependências Python.
# - Aproveitar o cache das camadas do Docker.
# - Executar a aplicação com usuário não-root.
# - Disponibilizar Healthcheck para monitoramento.
#
# ============================================================


# ------------------------------------------------------------
# 1. IMAGEM BASE
# ------------------------------------------------------------
# Utiliza uma imagem slim do Python para reduzir o tamanho
# final da imagem e manter somente os componentes essenciais.
# ------------------------------------------------------------
FROM python:3.12-slim AS base


# Evita a criação de arquivos .pyc.
# Mantém os logs do Python disponíveis imediatamente no Docker.
# Ativa informações adicionais em caso de falhas.
# Configurações relacionadas ao uv.
# Inclui o ambiente virtual da aplicação no PATH.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PATH="/app/.venv/bin:$PATH"


# Define o diretório principal da aplicação.
WORKDIR /app


# ------------------------------------------------------------
# 2. DEPENDÊNCIAS DO SISTEMA
# ------------------------------------------------------------
FROM base AS system


# Instala somente pacotes necessários para execução.
#
# curl:
#   utilizado por ferramentas auxiliares e verificações.
#
# ca-certificates:
#   permite conexões HTTPS confiáveis.
#
# libpq5:
#   biblioteca necessária para aplicações que utilizam
#   PostgreSQL em runtime.
#
# --no-install-recommends:
#   evita instalação de pacotes adicionais desnecessários.
#
# A limpeza do apt reduz o tamanho da imagem.
# ------------------------------------------------------------
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        libpq5 \
    && rm -rf /var/lib/apt/lists/*


# ------------------------------------------------------------
# 3. INSTALAÇÃO DO UV
# ------------------------------------------------------------
FROM system AS uv


# Copia os executáveis oficiais do uv para a imagem.
#
# O uv será utilizado para instalar e sincronizar
# as dependências Python definidas em pyproject.toml
# e uv.lock.
# ------------------------------------------------------------
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/


# ------------------------------------------------------------
# 4. INSTALAÇÃO DAS DEPENDÊNCIAS
# ------------------------------------------------------------
FROM uv AS dependencies


# Copia somente os arquivos responsáveis pelas dependências.
#
# Essa separação é importante:
# alterações no código-fonte não invalidam automaticamente
# a camada de instalação das dependências.
# ------------------------------------------------------------
COPY pyproject.toml uv.lock ./


# Instala as dependências exatamente conforme o lockfile.
#
# --frozen:
#   impede alterações no uv.lock.
#
# --no-install-project:
#   instala as dependências sem instalar o projeto
#   propriamente dito nesta etapa.
#
# --no-dev:
#   exclui dependências de desenvolvimento da imagem final.
# ------------------------------------------------------------
RUN uv sync \
    --frozen \
    --no-install-project \
    --no-dev


# ------------------------------------------------------------
# 5. CÓDIGO DA APLICAÇÃO
# ------------------------------------------------------------
FROM dependencies AS application


# Copia o código restante da aplicação.
#
# O .dockerignore determina quais arquivos serão excluídos
# do contexto antes desta operação.
# ------------------------------------------------------------
COPY . .


# Sincroniza novamente o ambiente para garantir que o projeto
# e suas dependências estejam corretamente disponíveis.
# ------------------------------------------------------------
RUN uv sync \
    --frozen \
    --no-dev


# ------------------------------------------------------------
# 6. CONFIGURAÇÃO DA IMAGEM DE PRODUÇÃO
# ------------------------------------------------------------
FROM application AS production


# Cria um grupo e usuário sem privilégios administrativos.
#
# Executar a aplicação como root aumenta o impacto de uma
# eventual vulnerabilidade na aplicação.
# ------------------------------------------------------------
RUN addgroup --system django \
    && adduser --system --ingroup django django


# Cria os diretórios utilizados pela aplicação.
#
# staticfiles:
#   destino comum do collectstatic.
#
# media:
#   arquivos enviados pelos usuários.
#
# O chown garante que o usuário django tenha acesso.
# ------------------------------------------------------------
RUN mkdir -p \
        /app/staticfiles \
        /app/media \
    && chown -R django:django /app


# A partir deste ponto, a aplicação não será executada
# como root.
# ------------------------------------------------------------
USER django


# Porta utilizada pelo servidor Gunicorn.
EXPOSE 8000


# ------------------------------------------------------------
# 7. HEALTHCHECK
# ------------------------------------------------------------
# Verifica periodicamente se a aplicação está respondendo.
#
# O endpoint /health/ deve existir na aplicação Django.
#
# Caso o endpoint não exista, crie uma rota simples para
# retornar HTTP 200 quando a aplicação estiver saudável.
# ------------------------------------------------------------
HEALTHCHECK \
    --interval=30s \
    --timeout=5s \
    --start-period=20s \
    --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health/', timeout=3)" \
    || exit 1


# ------------------------------------------------------------
# 8. INICIALIZAÇÃO
# ------------------------------------------------------------
# Inicia o Gunicorn.
#
# --bind:
#   disponibiliza o servidor em todas as interfaces.
#
# --workers:
#   executa múltiplos workers para atender requisições.
#
# access/error-log:
#   envia os logs para stdout/stderr, permitindo que o Docker
#   e ferramentas de observabilidade capturem os registros.
#
# IMPORTANTE:
# substitua config.wsgi:application pelo módulo WSGI real
# do seu projeto Django.
# ------------------------------------------------------------
CMD [
    "gunicorn",
    "--bind", "0.0.0.0:8000",
    "--workers", "3",
    "--access-logfile", "-",
    "--error-logfile", "-",
    "config.wsgi:application"
]
```
