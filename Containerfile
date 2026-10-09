```dockerfile
# ============================================================
# Containerfile PRO ULTRA — Django + FIRST
# Python 3.12 + uv + Gunicorn
# Docker / Podman
# ============================================================
#
# PRINCÍPIOS FIRST:
# F - Fast: cache de dependências e verificações rápidas.
# I - Independent: testes isolados do ambiente de produção.
# R - Repeatable: uv.lock e dependências fixadas.
# S - Self-validating: build falha se os testes falharem.
# T - Timely: validação integrada ao fluxo de desenvolvimento.
#
# Requisitos:
# - pyproject.toml e uv.lock
# - manage.py na raiz
# - Gunicorn nas dependências de produção
# - Endpoint /health/ retornando HTTP 200
# - Módulo WSGI ajustado para o projeto
#
# ============================================================

# 1. IMAGEM BASE
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
        libpq5 \
    && rm -rf /var/lib/apt/lists/*


# ============================================================
# 3. INSTALAÇÃO DO UV
# ============================================================

FROM system AS uv

COPY --from=ghcr.io/astral-sh/uv:0.8.22 \
    /uv /uvx /usr/local/bin/


# ============================================================
# 4. DEPENDÊNCIAS DE PRODUÇÃO
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

# Instala o projeto sem modificar o lockfile.
RUN uv sync \
    --frozen \
    --no-dev \
    && python -m compileall -q .


# ============================================================
# 6. ESTÁGIO DE TESTES — FIRST
# ============================================================
#
# Este estágio instala também as dependências de
# desenvolvimento e executa as verificações automatizadas.
#
# Se os testes falharem, o marcador não será criado.
# A imagem de produção depende desse marcador.
# ============================================================

FROM uv AS test

COPY pyproject.toml uv.lock ./

RUN uv sync --frozen

COPY . .

# Verifica a configuração e executa os testes.
# Qualquer erro interrompe o build.
RUN python manage.py check \
    && python manage.py test \
    && touch /tmp/test-success


# ============================================================
# 7. IMAGEM DE PRODUÇÃO
# ============================================================
#
# O COPY do marcador obriga o build a concluir o estágio
# de testes antes de finalizar a imagem de produção.
#
# A imagem final herda application, não test. Assim,
# as dependências exclusivas de desenvolvimento não
# são copiadas do ambiente de testes.
# ============================================================

FROM application AS production

# Dependência explícita do estágio de testes.
COPY --from=test /tmp/test-success /tmp/test-success

# Criação de usuário e grupo sem privilégios administrativos.
RUN addgroup --system django \
    && adduser --system --ingroup django django \
    && mkdir -p /app/staticfiles /app/media \
    && chown -R django:django /app \
    && rm -f /tmp/test-success


# ============================================================
# 8. CONFIGURAÇÃO DE RUNTIME
# ============================================================

ENV PORT=8000 \
    WEB_CONCURRENCY=3

EXPOSE 8000


# ============================================================
# 9. HEALTHCHECK
# ============================================================
#
# A rota /health/ deve retornar HTTP 200.
# Uma resposta HTTP de erro ou uma falha de conexão
# faz o healthcheck falhar.
# ============================================================

HEALTHCHECK \
    --interval=30s \
    --timeout=5s \
    --start-period=20s \
    --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health/', timeout=3)"]


# ============================================================
# 10. USUÁRIO NÃO-ROOT
# ============================================================

USER django


# ============================================================
# 11. INICIALIZAÇÃO DO GUNICORN
# ============================================================
#
# Ajuste config.wsgi:application para o módulo WSGI real.
# Os logs de acesso e erros são enviados ao container.
# exec permite que o Gunicorn receba sinais do runtime.
# ============================================================

CMD ["sh", "-c", "exec gunicorn --bind 0.0.0.0:${PORT} --workers ${WEB_CONCURRENCY} --access-logfile - --error-logfile - config.wsgi:application"]
```
