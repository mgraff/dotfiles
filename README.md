# dotfiles

Les mêmes fichiers de configuration sur toutes les machines (Fedora, Debian),
mis à jour automatiquement chaque jour depuis ce dépôt.

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
bash/home/…             ~/.bashrc, ~/.inputrc, ~/.bashrc.d/…
                        et la complétion de la commande dotfiles
bash/hook.sh            complétions kubectl/npm/pip/toolbox, outils manquants
nvim/home/…             ~/.config/nvim/init.lua (léger, sans plugin)
nvim/requires           installé seulement si nvim est présent
tmux/home/…             ~/.tmux.conf
                        et ~/.local/bin/tmux-now-playing (Spotify dans la barre)
                        et ~/.local/bin/tmux-host-alerts (badge : services en échec, redémarrage)
tmux/requires           installé seulement si tmux est présent
tmux/hook.sh            recharge la configuration du serveur tmux en cours
git/home/…              ~/.config/git/config (réglages communs)
                        et ~/.config/git/ignore (fichiers ignorés partout)
git/requires            installé seulement si git est présent
git/hook.sh             crée ~/.gitconfig, signale une identité manquante
ssh/home/…              ~/.ssh/config (réglages communs)
ssh/requires            installé seulement si ssh est présent
ssh/hook.sh             crée ~/.ssh/config.local et ~/.ssh/sockets, droits de ~/.ssh
```

- Un dossier par paquet : tout ce qui est dans `<paquet>/home/` est placé dans
  `~` avec la même arborescence.
- `<paquet>/hook.sh` (facultatif) est lancé après chaque installation ou mise à
  jour.
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
- **Debian** : installer `git fzf less bash-completion` ; le hook bash signale
  ce qui manque. nvim et tmux sont facultatifs : sans nvim, l'éditeur est vim,
  sinon vi.
- **Nerd Font** : à installer sur le poste depuis lequel on se connecte, pas sur
  les serveurs.
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
  une clé d'hôte qui a changé est toujours refusée.
- **Dépôt public** : ne jamais y mettre de secret.
