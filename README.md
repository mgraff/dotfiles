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
bash/hook.sh            complétions kubectl/npm/pip/toolbox, outils manquants
nvim/home/…             ~/.config/nvim/init.lua (léger, sans plugin)
nvim/requires           installé seulement si nvim est présent
tmux/home/…             ~/.tmux.conf
tmux/requires           installé seulement si tmux est présent
tmux/hook.sh            recharge la configuration du serveur tmux en cours
```

- Un dossier par paquet : tout ce qui est dans `<paquet>/home/` est placé dans
  `~` avec la même arborescence.
- `<paquet>/hook.sh` (facultatif) est lancé après chaque installation ou mise à
  jour.
- `<paquet>/requires` (facultatif) liste les commandes dont le paquet a besoin,
  une par ligne. S'il en manque une, le paquet est ignoré : ses fichiers ne sont
  pas installés (ou sont retirés s'ils l'étaient) et son hook n'est pas lancé.
  Dès que l'outil est installé, la mise à jour suivante installe le paquet.
- Pour ajouter un paquet, par exemple git : créer `git/home/.gitconfig`.

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
dotfiles status      dépôt, version installée, prochaine mise à jour
dotfiles rollback    revenir à la version précédente
```

Une mise à jour s'applique aux **nouveaux** shells ; dans un shell ouvert :
`exec bash`.

## Modifier la configuration

Modifier dans ce dépôt (`~/repositories/dotfiles`), commiter et pousser, puis
`dotfiles update` pour appliquer tout de suite. Ne pas modifier les fichiers de
`~` : ce sont des liens vers une version extraite, remplacée à la mise à jour
suivante.

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
- **Dépôt public** : ne jamais y mettre de secret.
