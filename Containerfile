```dockerfile
# ============================================================
# Containerfile PRO ULTRA
# Django + Python 3.12 + uv + Gunicorn
# ============================================================
#
# Objetivos:
# - Build reproduzível
# - Python 3.12
# - uv com versão fixa
# - Dependências controladas por uv.lock
# - Cache eficiente das dependências
# - Imagem final enxuta
# - Execução como usuário não-root
# - Healthcheck
# - Logs direcionados para stdout/stderr
# - Compatibilidade com Docker/Podman
#
# IMPORTANTE:
# - O projeto deve possuir pyproject.toml e uv.lock.
# - Gunicorn deve estar nas dependências de produção.
# - O endpoint /health/ deve existir no Django.
# - Ajuste config.wsgi:application para o módulo WSGI real.
#
# ============================================================


# ============================================================
# 1. BASE
# ============================================================

FROM python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PATH="/app/.venv/bin:$PATH"

WORKDIR /app


# ============================================================
# 2. DEPENDÊNCIAS DO SISTEMA
# ============================================================

FROM base AS system

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        libpq5 \
    && rm -rf /var/lib/apt/lists/*


# ============================================================
# 3. INSTALAÇÃO DO UV
# ============================================================
#
# A versão é fixada para evitar mudanças inesperadas
# durante futuros builds.
# ============================================================

FROM system AS uv

COPY --from=ghcr.io/astral-sh/uv:0.8.22 /uv /uvx /usr/local/bin/


# ============================================================
# 4. DEPENDÊNCIAS PYTHON
# ============================================================
#
# Copiar somente pyproject.toml e uv.lock antes do código
# permite aproveitar o cache do Docker/Podman.
# ============================================================

FROM uv AS dependencies

COPY pyproject.toml uv.lock ./

RUN uv sync \
    --frozen \
    --no-install-project \
    --no-dev


# ============================================================
# 5. CÓDIGO DA APLICAÇÃO
# ============================================================

FROM dependencies AS application

COPY . .

RUN uv sync \
    --frozen \
    --no-dev


# ============================================================
# 6. PRODUÇÃO
# ============================================================

FROM application AS production


# ============================================================
# 6.1 USUÁRIO NÃO-ROOT
# ============================================================
#
# A aplicação não deve ser executada como root.
# ============================================================

RUN addgroup --system django \
    && adduser --system --ingroup django django


# ============================================================
# 6.2 DIRETÓRIOS DO DJANGO
# ============================================================
#
# staticfiles:
#   arquivos gerados pelo collectstatic.
#
# media:
#   arquivos enviados pelos usuários.
# ============================================================

RUN mkdir -p \
        /app/staticfiles \
        /app/media \
    && chown -R django:django /app


# ============================================================
# 6.3 USUÁRIO DA APLICAÇÃO
# ============================================================

USER django


# ============================================================
# 7. PORTA
# ============================================================

EXPOSE 8000


# ============================================================
# 8. HEALTHCHECK
# ============================================================
#
# O Django deve possuir uma rota:
#
#     GET /health/
#
# retornando HTTP 200 quando a aplicação estiver saudável.
# ============================================================

HEALTHCHECK \
    --interval=30s \
    --timeout=5s \
    --start-period=20s \
    --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health/', timeout=3)" \
    || exit 1


# ============================================================
# 9. INICIALIZAÇÃO
# ============================================================
#
# Gunicorn deve estar instalado nas dependências de produção.
#
# Exemplo no pyproject.toml:
#
#     gunicorn>=23
#
# Substitua:
#
#     config.wsgi:application
#
# pelo módulo WSGI real do projeto.
# ============================================================

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "3", "--access-logfile", "-", "--error-logfile", "-", "config.wsgi:application"]
```
