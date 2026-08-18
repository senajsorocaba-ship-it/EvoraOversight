# ÉVORA OVERSIGHT — imagem única para os dois componentes Python do projeto:
#   1) motor/                 — pipeline original (coletores + montador + render), zero deps externas
#   2) ao-SUPABASE-BLOCO1/     — motor de execução que liga o BLOCO 4 (Supabase) à API da Claude
#
# Qual dos dois roda é decidido no docker-compose.yml (working_dir + entrypoint por serviço),
# não aqui — a imagem só precisa conter o código e a única dependência real do projeto.

FROM python:3.12-slim

WORKDIR /app

# Única dependência de todo o projeto (usada só pelo motor de execução do BLOCO 4):
# o SDK oficial da Anthropic. O motor/ original não usa nada além da stdlib.
COPY ao-SUPABASE-BLOCO1/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY motor/ ./motor/
COPY ao-SUPABASE-BLOCO1/evora_motor_execucao.py ./ao-SUPABASE-BLOCO1/evora_motor_execucao.py

# Nunca correr como root dentro do container.
RUN useradd -m -u 1000 evora && chown -R evora:evora /app
USER evora
