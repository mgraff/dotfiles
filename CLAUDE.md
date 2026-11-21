# Consignes pour Claude

Le fonctionnement du dépôt (paquets, installateur, commandes) est décrit dans
`README.md` : le lire avant toute modification. Ce fichier ne contient que ce
qui concerne la façon d'y travailler.

## Flux de travail

- Ne jamais modifier les fichiers de `~` : ce sont des liens vers une version
  installée (`~/.local/share/dotfiles/current/…`). Toute modification se fait
  dans ce dépôt.
- Un changement = une branche, poussée sur `origin`. L'utilisateur la teste
  sur ses machines avec `dotfiles switch <branche>`, puis demande la fusion.
- Fusionner seulement à sa demande : fast-forward dans `master` (historique
  linéaire), push, puis suppression de la branche en local et sur `origin`.
  Les machines restées sur la branche reviennent d'elles-mêmes sur `master`.
- Ne jamais commiter sur `master` directement, ni pousser sans accord.

## Conventions

- Commentaires et documentation en français ; messages affichés à
  l'utilisateur et messages de commit en anglais.
- Messages des scripts au format `dotfiles: …` (`dotfiles: reloading tmux`).
- Toujours une espace après une icône Nerd Font (la police non Mono les fait
  déborder sur le caractère suivant).
- Pas d'alias utilitaires : l'utilisateur n'en veut pas. Une fonction n'est
  justifiée que pour changer le comportement d'une commande qu'il utilise
  (exemple : `bc` dans `70-environment.sh`).
- Dépôt public : ni secret, ni nom d'hôte, adresse ou utilisateur interne. Ce
  qui est propre à une machine va dans un fichier local hors du dépôt
  (`~/.gitconfig`, `~/.ssh/config.local`), créé par le hook du paquet.
- Mêmes fichiers sur toutes les machines (Fedora et Debian), sans différence
  par machine. Rester compatible avec Debian 12 : bash 5.2, fzf 0.38, bat
  installé sous le nom `batcat`, git 2.39, OpenSSH 9.2. Vérifier qu'une option
  existe dans ces versions avant de l'utiliser.
- Un outil manquant se signale dans `<paquet>/check.sh` (avertissement), pas
  dans `hook.sh` : `check.sh` tourne à chaque `dotfiles update`.

## Installateur

- Une mise à jour est exécutée par l'installateur **déjà installé**, y compris
  après un `rollback`. Une modification de `install.sh` ne se voit donc qu'à
  la mise à jour suivante ; ce décalage est accepté, ne pas le contourner.
- Ordre de `activate` : liens, message (`installed …`), `check.sh`, hooks.
- Tout fichier `*.sh` du dépôt est vérifié avec `bash -n` avant installation :
  un commit avec une erreur de syntaxe est refusé sur toutes les machines.

## Tests

`tests/e2e.sh [branche]` installe `master` puis la branche dans un HOME
jetable, avec un serveur tmux de test, et vérifie qu'un bash interactif
s'ouvre sans erreur ; `--debian` refait le test dans un conteneur Debian 12.
Le lancer avant de proposer une branche qui touche à l'installateur, aux hooks
ou à `.bashrc.d`. Il teste les commits, pas les modifications non commitées.

Pour un comportement interactif (prompt, complétion, raccourcis, fzf), le
tester dans un vrai pseudo-terminal (module `pty` de Python) en envoyant les
touches. Pièges déjà rencontrés :

- fzf demande la position du curseur (`\e[6n`) et attend la réponse : la
  simuler (`\e[5;1R`), sinon l'affichage est dégénéré.
- Les sockets (tmux, `ControlPath` de ssh) sont limités à 108 caractères :
  utiliser un dossier court dans `/tmp`, pas un chemin long.
- ssh ignore `$HOME` et lit le vrai `~/.ssh` : tester sa configuration avec
  `ssh -F fichier -G hôte`.
- Dans un HOME jetable, `unset TMUX` : sinon le hook tmux recharge le serveur
  tmux réel. Ne jamais lancer `dotfiles install` : il active le timer systemd
  de la vraie session.
