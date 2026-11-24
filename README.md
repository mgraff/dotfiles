# dotfiles

Les mêmes fichiers de configuration sur toutes les machines (Fedora, Debian),
mis à jour automatiquement chaque jour depuis ce dépôt.

## Fonctionnalités

Une case vide dans la dernière colonne signifie que c'est automatique.

| Paquet | Fonctionnalité | Raccourci / commande |
|---|---|---|
| **dotfiles** | Mise à jour quotidienne et 2 min après l'ouverture de session, rattrapée au réveil ou au démarrage, relancée toutes les 5 min en cas d'échec | `dotfiles update` |
| | Suivre une branche pour la tester, revenir à une des 5 versions précédentes | `dotfiles switch X`, `dotfiles rollback` |
| | Commit refusé s'il contient une erreur de syntaxe bash | |
| | Paquet ignoré tant que son outil n'est pas installé, outils manquants signalés avec la commande d'installation | `dotfiles status` |
| | Shell relancé après une mise à jour, rappel dans les autres terminaux | `exec bash` |
| **bash** : prompt | Deux lignes : chemin complet (racine git et projet compose en gras, « … » seulement si trop long), cadenas si le dossier n'est pas modifiable | |
| | Conteneur toolbox/distrobox, `utilisateur@machine` seulement en root ou en SSH (même après `sudo su -`) | |
| | git : branche, opération en cours (`REBASING 1/3`, `MERGING`…), état (conflit, stash, modifié, indexé, non suivi, avance/retard) | |
| | compose : projet, services en marche / déclarés, services arrêtés, healthcheck en échec, redémarrage en boucle, fichier modifié depuis le lancement (docker ou podman) | |
| | Code de retour, durée si plus de 2 s, heure ; `❯` rouge après un échec | |
| **bash** : historique | 10 000 commandes horodatées, sans doublons ; chaque commande est écrite dans le fichier dès son lancement (visible dans les terminaux ouverts ensuite), fichier dédoublonné à la fermeture du shell | |
| | Recherche par sous-chaîne du texte déjà tapé, insensible à la casse | `↑` / `↓` |
| | Recherche floue dans une liste fzf | `Ctrl-R` |
| | Commandes les plus utilisées | `history-stat [n]` |
| | `!!`, `!$`… développés avant exécution | `sudo !!` + `Espace` |
| **bash** : complétion | Insensible à la casse, `-` et `_` équivalents, liste dès le premier Tab, en couleur | `Tab` |
| | Liste filtrable de fichiers (respecte `.gitignore`), sélection multiple | `**<Tab>`, `cd **<Tab>` |
| | Seulement les fichiers modifiés ou nouveaux, avec leur diff à droite | `git add/diff/restore **<Tab>` |
| | Complétions de kubectl, npm, pip, toolbox et dotfiles | `Tab` |
| **bash** : édition | Effacer jusqu'à l'espace ou au `/` précédent / suivant | `Ctrl-Backspace` / `Ctrl-Suppr` |
| | Demande en langage naturel transformée en commande par Claude Code | `Alt-A` (`Ctrl-_` pour revenir) |
| | `**` parcourt les sous-dossiers ; `>` n'écrase pas un fichier existant | `ls **/*.py`, `>\|` pour forcer |
| | `exit` prévient s'il reste des tâches en arrière-plan | |
| **bash** : environnement | Éditeur : nvim, sinon vim, sinon vi | |
| | less sans pager pour un texte court, recherche insensible à la casse ; pages de manuel en couleur ; less ouvre archives et PDF | |
| | Calculatrice avec 2 décimales et fonctions mathématiques | `bc` |
| | Même comportement sur Fedora et Debian (couleurs de ls et grep, bash-completion, GPG) | |
| **tmux** | Préfixe `Ctrl-A`, rechargement de la configuration | `Ctrl-A r` |
| | Désactiver tous les raccourcis (tmux imbriqué via SSH), badge OFF | `F12` |
| | Panes : découper dans le dossier courant, naviguer, zoomer, synchroniser | `Ctrl-A \|` / `-`, `Alt-flèches`, `Ctrl-A +`, `Ctrl-A S` |
| | Fenêtres : créer et nommer, changer, déplacer | `Alt-Shift-T` ou `Ctrl-A c`, `Alt-Shift-flèches`, `Alt-Shift-PgUp/PgDn` |
| | Sessions : sauvegarder l'agencement (onglets, panes, dossiers, texte visible), le restaurer, supprimer une sauvegarde ; `tmux new -s nom` restaure la sauvegarde du même nom | `Ctrl-A Ctrl-S`, `Ctrl-A Ctrl-R`, `Ctrl-A Ctrl-D` |
| | Souris, 100 000 lignes d'historique, numérotation à partir de 1 | |
| | Copie en mode vi vers le presse-papiers, y compris depuis un hôte distant (OSC 52) | `Ctrl-A [`, `Entrée` |
| | Onglets : badges synchronisation, SSH, root, mode copie, zoom | |
| | Barre : morceau Spotify en cours, nom d'hôte, services systemd en échec, redémarrage nécessaire, heure | |
| | Configuration rechargée dans le serveur en cours à chaque mise à jour | |
| **nvim** | Numéros de ligne, recherche smartcase, annulations conservées, espaces visibles, texte copié surligné | |
| | Presse-papiers du système (OSC 52 en SSH) | `y`, `p` |
| | Enregistrer avec sudo | `:W` |
| | Messages de commit : repères à 50 et 72 colonnes, retour à la ligne à 72 | |
| **git** | `pull` en rebase avec autostash, premier `push` qui crée la branche distante, `fetch` qui nettoie | |
| | Diffs plus lisibles (blocs déplacés), conflits avec la version d'origine (zdiff3), résolutions retenues (rerere) | |
| | `log` sur une ligne par commit, qui suit les renommages ; `status` court ; branches récentes en premier ; tags triés par version | `git log --format=medium` pour le détail |
| | Diff sous le message de commit, commande mal tapée corrigée après confirmation | |
| | Dépôts GitHub clonés en https, poussés en ssh | |
| | Identité propre à chaque machine, signalée si absente ; fichiers ignorés partout (éditeurs, `.venv`…) | `git config --global` |
| **ssh** | Réglages propres à la machine dans un fichier local prioritaire | `~/.ssh/config.local` |
| | Connexions partagées par hôte, ouvertes 10 min | `ssh -O exit hôte`, `ssh -S none hôte` |
| | Connexion morte détectée en 2 min, hôte injoignable abandonné en 10 s | |
| | Hôte inconnu accepté sans question, clé changée refusée ; clé ajoutée à l'agent ; noms d'hôtes complétables | |
| **dig** | Seulement la réponse | `dig +all` pour tout |
| **k9s** | Lecture seule sur tous les contextes | `k9s --write` |
| | Couleurs de tmux, sans logo, logs plus longs avec l'heure | |

## Installation

Il faut `git` et `curl` :

```
bash <(curl -fsSL https://raw.githubusercontent.com/mgraff/dotfiles/master/install.sh) install https://github.com/mgraff/dotfiles.git
```

Les fichiers déjà présents à la place des nouveaux sont déplacés dans
`~/.local/share/dotfiles/backup/<date>/`.

## Organisation

```
install.sh              installe et met à jour (devient la commande « dotfiles »)
tests/e2e.sh            teste une branche dans un HOME jetable (--debian : Debian 13)
CLAUDE.md               consignes pour Claude Code
bash/home/…             ~/.bashrc, ~/.inputrc, ~/.bashrc.d/…
                        et la complétion de la commande dotfiles
bash/hook.sh            complétions kubectl/npm/pip/toolbox
bash/check.sh           signale les outils manquants
nvim/home/…             ~/.config/nvim/init.lua (léger, sans plugin)
nvim/requires           installé seulement si nvim est présent
tmux/home/…             ~/.tmux.conf
                        et ~/.local/bin/tmux-now-playing (Spotify dans la barre)
                        et ~/.local/bin/tmux-host-alerts (badge : services en échec, redémarrage)
                        et ~/.local/bin/tmux-layout (sauvegarde et restauration d'une session)
tmux/requires           installé seulement si tmux est présent
tmux/hook.sh            recharge la configuration du serveur tmux en cours
git/home/…              ~/.config/git/config (réglages communs)
                        et ~/.config/git/ignore (fichiers ignorés partout)
git/requires            installé seulement si git est présent
git/hook.sh             crée ~/.gitconfig
git/check.sh            signale une identité manquante
ssh/home/…              ~/.ssh/config (réglages communs)
ssh/requires            installé seulement si ssh est présent
ssh/hook.sh             crée ~/.ssh/config.local et ~/.ssh/sockets, droits de ~/.ssh
dig/home/…              ~/.digrc (seulement la réponse ; dig +all pour tout)
dig/requires            installé seulement si dig est présent
k9s/home/…              ~/.config/k9s/config.yaml (lecture seule par défaut)
                        et ~/.config/k9s/skins/dotfiles.yaml (couleurs de tmux)
k9s/requires            installé seulement si k9s est présent
```

- Un dossier par paquet : tout ce qui est dans `<paquet>/home/` est placé dans
  `~` avec la même arborescence.
- `<paquet>/hook.sh` (facultatif) est lancé après chaque installation ou mise à
  jour.
- `<paquet>/check.sh` (facultatif) vérifie sans rien modifier (outils
  manquants, identité git…). Il est lancé à chaque `dotfiles update`, même
  quand tout est déjà à jour, et par `dotfiles status` ; ce qu'il affiche
  apparaît en jaune.
- `<paquet>/requires` (facultatif) liste les commandes dont le paquet a besoin,
  une par ligne. S'il en manque une, le paquet est ignoré : ses fichiers ne sont
  pas installés (ou sont retirés s'ils l'étaient) et son hook n'est pas lancé.
  Dès que l'outil est installé, la mise à jour suivante installe le paquet.
- Pour ajouter un paquet, par exemple htop : créer `htop/home/.config/htop/htoprc`.

## Fonctionnement

- Le dépôt est cloné dans `~/.local/share/dotfiles/repo.git`. Chaque commit
  installé est extrait dans `~/.local/share/dotfiles/releases/<date>-<commit>/`,
  et `~/.local/share/dotfiles/current` pointe vers la version active.
- Les fichiers de `~` sont des **liens** vers `current` : une mise à jour change
  tous les fichiers d'un coup.
- Avant d'installer un commit, la syntaxe de tous les fichiers bash est
  vérifiée : un commit contenant une erreur est refusé, rien n'est modifié.
- Un fichier retiré du dépôt est retiré de `~` à la mise à jour suivante.
- Les 5 dernières versions sont conservées pour `dotfiles rollback`.
- Un timer systemd utilisateur lance `dotfiles update` 2 minutes après
  l'ouverture de session, puis une fois par jour.

## Commandes

```
dotfiles update      récupérer et appliquer le dernier commit
dotfiles switch X    suivre la branche X (pour la tester) et l'installer
dotfiles status      dépôt, version installée, prochaine mise à jour
dotfiles rollback    revenir à la version précédente
```

`dotfiles update`, `switch` et `rollback` relancent le shell (`exec bash`)
quand la version installée change, sauf si des tâches tournent en arrière-plan.
Les autres shells ouverts, et ceux mis à jour par le timer, affichent un rappel
à leur prochain prompt : y taper `exec bash`.

## Modifier la configuration

Modifier dans ce dépôt (`~/repositories/dotfiles`), commiter et pousser, puis
`dotfiles update` pour appliquer tout de suite. Ne pas modifier les fichiers de
`~` : ce sont des liens vers une version extraite, remplacée à la mise à jour
suivante.

## Tester une branche

1. Pousser les modifications sur une branche, par exemple `essai`.
2. Sur la machine de test : `dotfiles switch essai`.
3. Corriger, pousser, puis `dotfiles update` (le timer suit aussi la branche).
4. Une fois la branche fusionnée dans master : `dotfiles switch master`. Si la
   branche a été supprimée du dépôt, la mise à jour suivante revient d'elle-même
   sur master.

`dotfiles status` affiche la branche suivie.

## À savoir

- **nvim** : `:W` enregistre avec sudo un fichier ouvert sans les droits
  d'écriture. Pour ouvrir un fichier système, préférer `sudoedit fichier` à
  `sudo nvim fichier` : la configuration est la même et nvim ne tourne pas en
  root.
- **Debian** : installer `git fzf less ripgrep bat bash-completion` ; `dotfiles update`
  signale ce qui manque. nvim et tmux sont facultatifs : sans nvim, l'éditeur est vim,
  sinon vi.
- **Nerd Font** : à installer sur le poste depuis lequel on se connecte, pas sur
  les serveurs.
- **fzf** : `**<Tab>` ouvre une liste filtrable (`Tab` pour cocher plusieurs
  fichiers), `Ctrl-R` cherche dans l'historique. Après `git add`, `git diff` et
  `git restore`, `**<Tab>` ne propose que les fichiers modifiés ou nouveaux,
  avec leur diff à droite.
- **Claude** : taper une demande en langage naturel sur la ligne de commande,
  puis `Alt-A` : Claude Code la remplace par une commande, à relire avant de la
  lancer (`Ctrl-_` revient à la demande). Sur une machine sans `claude`, `Alt-A`
  le signale ;
  `CLAUDE_SHELL_MODEL=haiku` pour un modèle plus rapide.
- **git** : l'identité (`user.name`, `user.email`) n'est pas dans le dépôt,
  elle est propre à chaque machine. La définir avec `git config --global`, qui
  écrit dans `~/.gitconfig`, un fichier local qui l'emporte sur
  `~/.config/git/config`. Tant qu'elle manque, git refuse de commiter. Les
  dépôts GitHub clonés en https sont poussés en ssh.
- **ssh** : les hôtes, utilisateurs et clés propres à la machine vont dans
  `~/.ssh/config.local`, hors du dépôt, lu avant `~/.ssh/config` (ssh garde la
  première valeur trouvée). Un `~/.ssh/config` déjà présent à l'installation du
  paquet devient `~/.ssh/config.local` (une copie reste dans `backup/`). Les connexions à un même hôte sont partagées et
  restent ouvertes 10 minutes : `ssh -O exit hôte` pour fermer, `ssh -S none
  hôte` pour une connexion séparée. Un hôte inconnu est accepté sans question ;
  une clé d'hôte qui a changé est toujours refusée. Un hôte injoignable
  échoue au bout de 10 s.
- **k9s** : en lecture seule sur tous les contextes. Pour pouvoir agir sur un
  contexte, mettre `readOnly: false` sous `k9s:` dans son fichier local
  `~/.local/share/k9s/clusters/<cluster>/<contexte>/config.yaml` ; pour une
  seule session, `k9s --write`.
- **tmux** : `prefix C-s` sauvegarde la session courante (onglets, agencement
  des panes, dossiers, texte visible) dans `~/.local/state/tmux/sessions/`,
  en remplaçant la sauvegarde précédente du même nom. `prefix C-r` ouvre la
  liste des sauvegardes : celle choisie est restaurée en nouveaux onglets
  dans la session courante (une session neuve, un seul shell, est
  réutilisée). Une session créée avec le nom d'une sauvegarde
  (`tmux new -s work`) la restaure aussitôt. `prefix C-d` supprime une
  sauvegarde (menu, puis confirmation). `less`, `nvim`, `ssh`… sont relancés
  (liste dans le script). La sauvegarde n'est jamais automatique.
- **Dépôt public** : ne jamais y mettre de secret.
