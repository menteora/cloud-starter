# cloud-starter

Strumenti di avvio rapido per ambienti cloud su Ubuntu.

---

## Setup repository privato in lettura/scrittura

Lo script `setup-private-repo.sh` guida passo-passo la configurazione dell'accesso SSH a un repository GitHub privato (lettura e scrittura) su Ubuntu.

### Cosa fa lo script

1. Verifica che `git` e `ssh` siano installati
2. Configura l'identità git globale (nome e email) se non è già presente
3. Genera una chiave SSH `ed25519` (o riutilizza quella esistente)
4. Avvia `ssh-agent` e aggiunge la chiave, con snippet di persistenza in `~/.bashrc`
5. Mostra la chiave pubblica da incollare su **GitHub → Settings → SSH and GPG keys**
6. Testa la connessione a GitHub
7. (Opzionale) clona il repository privato nella home

---

### Download e primo avvio

Scarica lo script direttamente nella home, rendilo eseguibile e lancialo:

```bash
curl -fsSL https://raw.githubusercontent.com/menteora/cloud-starter/main/setup-private-repo.sh \
     -o ~/setup-private-repo.sh

chmod +x ~/setup-private-repo.sh

~/setup-private-repo.sh
```

> **Nota:** `chmod +x` è necessario una sola volta. Dopo il primo avvio puoi richiamare lo script con `~/setup-private-repo.sh` senza ripetere il comando.

---

### Rendere eseguibile uno script bash scaricato

Quando scarichi un file `.sh` sul tuo sistema Ubuntu, di default non ha il permesso di esecuzione. Per abilitarlo:

```bash
# Sintassi generale
chmod +x /percorso/del/file.sh

# Esempio: script nella home
chmod +x ~/setup-private-repo.sh
```

Puoi verificare i permessi con:

```bash
ls -l ~/setup-private-repo.sh
# Output atteso (nota la 'x'):
# -rwxr-xr-x 1 utente utente ... setup-private-repo.sh
```

Per eseguirlo senza specificare il percorso completo da qualsiasi directory:

```bash
# Opzione A – percorso esplicito dalla home
~/setup-private-repo.sh

# Opzione B – spostarlo in una directory nel PATH
mv ~/setup-private-repo.sh ~/.local/bin/setup-private-repo
# (assicurati che ~/.local/bin sia nel tuo PATH)
```

---

### Prerequisiti

| Strumento | Installazione |
|-----------|--------------|
| `git`     | `sudo apt install git` |
| `openssh-client` | `sudo apt install openssh-client` |
| `curl`    | `sudo apt install curl` |
