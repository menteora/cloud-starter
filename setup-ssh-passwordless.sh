#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
#  setup-ssh-passwordless.sh
#  Configura il login SSH senza password
#  verso un server remoto su Ubuntu.
# ─────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERR]${NC}   $*" >&2; exit 1; }

# ── 1. Dipendenze ────────────────────────────
command -v ssh         >/dev/null 2>&1 || error "ssh non trovato. Installa con: sudo apt install openssh-client"
command -v ssh-keygen  >/dev/null 2>&1 || error "ssh-keygen non trovato. Installa con: sudo apt install openssh-client"
command -v ssh-copy-id >/dev/null 2>&1 || error "ssh-copy-id non trovato. Installa con: sudo apt install openssh-client"

# ── 2. Dati del server remoto ────────────────
echo
info "Configurazione server remoto"

read -rp "  Utente remoto (es. ubuntu): " REMOTE_USER
read -rp "  Host o IP del server:       " REMOTE_HOST
read -rp "  Porta SSH [22]:             " REMOTE_PORT
REMOTE_PORT="${REMOTE_PORT:-22}"

# ── 3. Chiave SSH locale ─────────────────────
echo
info "Verifica chiave SSH locale"

KEY_FILE="$HOME/.ssh/id_ed25519"

if [ -f "$KEY_FILE" ]; then
    warn "Chiave esistente trovata: $KEY_FILE"
    read -rp "  Usare quella esistente? [S/n]: " USE_EXISTING
    USE_EXISTING="${USE_EXISTING:-S}"
else
    USE_EXISTING="n"
fi

if [[ "$USE_EXISTING" =~ ^[Nn]$ ]]; then
    read -rp "  Etichetta per la nuova chiave (es. email o hostname): " KEY_LABEL
    ssh-keygen -t ed25519 -C "$KEY_LABEL" -f "$KEY_FILE" -N ""
    success "Chiave generata: $KEY_FILE"
else
    success "Uso chiave esistente: $KEY_FILE"
fi

# ── 4. Copia la chiave sul server ────────────
echo
info "Copia della chiave pubblica su ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PORT}"
info "Ti verrà chiesta la password del server remoto (solo questa volta)."
echo

ssh-copy-id -i "${KEY_FILE}.pub" -p "$REMOTE_PORT" "${REMOTE_USER}@${REMOTE_HOST}"
success "Chiave copiata su ${REMOTE_USER}@${REMOTE_HOST}"

# ── 5. ssh-agent ─────────────────────────────
echo
info "Avvio ssh-agent e aggiunta della chiave"

eval "$(ssh-agent -s)" >/dev/null
ssh-add "$KEY_FILE" 2>/dev/null && success "Chiave aggiunta all'agente" || warn "Impossibile aggiungere la chiave (protetta da passphrase?)"

# Persistenza ssh-agent in .bashrc
AGENT_SNIPPET='
# -- ssh-agent auto-start (aggiunto da setup-ssh-passwordless.sh) --
if [ -z "$SSH_AUTH_SOCK" ]; then
  eval "$(ssh-agent -s)" > /dev/null
  ssh-add ~/.ssh/id_ed25519 2>/dev/null
fi'

if ! grep -q "ssh-agent auto-start" "$HOME/.bashrc" 2>/dev/null; then
    echo "$AGENT_SNIPPET" >> "$HOME/.bashrc"
    info "Snippet ssh-agent aggiunto a ~/.bashrc"
fi

# Alias comodo (opzionale)
echo
read -rp "  Creare un alias rapido per questo server? [S/n]: " CREATE_ALIAS
CREATE_ALIAS="${CREATE_ALIAS:-S}"

if [[ ! "$CREATE_ALIAS" =~ ^[Nn]$ ]]; then
    read -rp "  Nome alias (es. myserver): " ALIAS_NAME
    ALIAS_LINE="alias ${ALIAS_NAME}='ssh -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST}'"
    if ! grep -qF "$ALIAS_LINE" "$HOME/.bashrc" 2>/dev/null; then
        echo "$ALIAS_LINE" >> "$HOME/.bashrc"
        success "Alias aggiunto: $ALIAS_NAME"
        info "Dopo il riavvio del terminale potrai connetterti con: ${ALIAS_NAME}"
    else
        warn "Alias già presente in ~/.bashrc"
    fi
fi

# ── 6. Voce ~/.ssh/config (opzionale) ────────
echo
read -rp "  Aggiungere una voce a ~/.ssh/config? [S/n]: " CREATE_CONFIG
CREATE_CONFIG="${CREATE_CONFIG:-S}"

if [[ ! "$CREATE_CONFIG" =~ ^[Nn]$ ]]; then
    read -rp "  Nome host da usare in config (es. myserver): " CONFIG_HOST
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    CONFIG_ENTRY="
Host ${CONFIG_HOST}
    HostName ${REMOTE_HOST}
    User ${REMOTE_USER}
    Port ${REMOTE_PORT}
    IdentityFile ${KEY_FILE}
    ServerAliveInterval 60"

    CONFIG_FILE="$HOME/.ssh/config"
    if ! grep -qF "Host ${CONFIG_HOST}" "$CONFIG_FILE" 2>/dev/null; then
        echo "$CONFIG_ENTRY" >> "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
        success "Voce aggiunta a ~/.ssh/config"
        info "Ora puoi connetterti con: ssh ${CONFIG_HOST}"
    else
        warn "Voce 'Host ${CONFIG_HOST}' già presente in ~/.ssh/config"
    fi
fi

# ── 7. Test connessione passwordless ─────────
echo
info "Test login passwordless su ${REMOTE_USER}@${REMOTE_HOST}..."

if ssh -p "$REMOTE_PORT" -o BatchMode=yes -o ConnectTimeout=10 \
       "${REMOTE_USER}@${REMOTE_HOST}" echo "LOGIN_OK" 2>/dev/null | grep -q "LOGIN_OK"; then
    success "Login passwordless funzionante!"
else
    warn "Test fallito. Verifica host, utente e che il server accetti chiavi SSH."
    info  "Prova manualmente: ssh -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST}"
fi

echo
success "Setup completato. Riapri il terminale (o esegui: source ~/.bashrc) per applicare tutte le modifiche."
