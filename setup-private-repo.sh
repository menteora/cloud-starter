#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
#  setup-private-repo.sh
#  Configura accesso SSH in lettura/scrittura
#  a un repository GitHub privato su Ubuntu.
# ─────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERR]${NC}   $*" >&2; exit 1; }

# ── 1. Dipendenze ────────────────────────────
command -v git  >/dev/null 2>&1 || error "git non trovato. Installa con: sudo apt install git"
command -v ssh  >/dev/null 2>&1 || error "ssh non trovato. Installa con: sudo apt install openssh-client"

# ── 2. Identità git globale ──────────────────
echo
info "Configurazione identità git"

if [ -z "$(git config --global user.name  2>/dev/null)" ]; then
    read -rp "  Nome utente git: " GIT_NAME
    git config --global user.name "$GIT_NAME"
fi

if [ -z "$(git config --global user.email 2>/dev/null)" ]; then
    read -rp "  Email git:       " GIT_EMAIL
    git config --global user.email "$GIT_EMAIL"
fi

success "Identità: $(git config --global user.name) <$(git config --global user.email)>"

# ── 3. Chiave SSH ────────────────────────────
echo
info "Verifica chiave SSH per GitHub"

KEY_FILE="$HOME/.ssh/id_ed25519"

if [ -f "$KEY_FILE" ]; then
    warn "Chiave esistente trovata: $KEY_FILE"
    read -rp "  Usare quella esistente? [S/n]: " USE_EXISTING
    USE_EXISTING="${USE_EXISTING:-S}"
else
    USE_EXISTING="n"
fi

if [[ "$USE_EXISTING" =~ ^[Nn]$ ]]; then
    read -rp "  Email per la nuova chiave SSH: " SSH_EMAIL
    ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$KEY_FILE" -N ""
    success "Chiave generata: $KEY_FILE"
fi

# ── 4. ssh-agent ─────────────────────────────
echo
info "Avvio ssh-agent e aggiunta della chiave"

eval "$(ssh-agent -s)" >/dev/null
ssh-add "$KEY_FILE" 2>/dev/null && success "Chiave aggiunta all'agente" || warn "Impossibile aggiungere la chiave (protetta da passphrase?)"

# Persistenza ssh-agent in .bashrc
AGENT_SNIPPET='
# -- ssh-agent auto-start (aggiunto da setup-private-repo.sh) --
if [ -z "$SSH_AUTH_SOCK" ]; then
  eval "$(ssh-agent -s)" > /dev/null
  ssh-add ~/.ssh/id_ed25519 2>/dev/null
fi'

if ! grep -q "ssh-agent auto-start" "$HOME/.bashrc" 2>/dev/null; then
    echo "$AGENT_SNIPPET" >> "$HOME/.bashrc"
    info "Snippet ssh-agent aggiunto a ~/.bashrc"
fi

# ── 5. Mostra la chiave pubblica ─────────────
echo
echo -e "${YELLOW}══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  Aggiungi questa chiave pubblica a GitHub:${NC}"
echo -e "${YELLOW}  Settings → SSH and GPG keys → New SSH key${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════${NC}"
echo
cat "${KEY_FILE}.pub"
echo
echo -e "${YELLOW}══════════════════════════════════════════════════${NC}"
echo

read -rp "  Premi INVIO dopo aver aggiunto la chiave su GitHub..."

# ── 6. Test connessione GitHub ───────────────
echo
info "Test connessione a GitHub..."

if ssh -T git@github.com -o StrictHostKeyChecking=accept-new 2>&1 | grep -q "successfully authenticated"; then
    success "Connessione a GitHub riuscita!"
else
    warn "Connessione non confermata. Verifica che la chiave sia stata aggiunta correttamente."
fi

# ── 7. Clona (opzionale) ─────────────────────
echo
read -rp "  URL SSH del repository privato (vuoto per saltare): " REPO_URL

if [ -n "$REPO_URL" ]; then
    REPO_NAME=$(basename "$REPO_URL" .git)
    info "Clonazione di $REPO_URL in ~/$REPO_NAME ..."
    git clone "$REPO_URL" "$HOME/$REPO_NAME"
    success "Repository clonato in: $HOME/$REPO_NAME"
    info "Puoi ora leggere e scrivere con: git pull / git push"
fi

echo
success "Setup completato. Riapri il terminale (o esegui: source ~/.bashrc) per applicare tutte le modifiche."
