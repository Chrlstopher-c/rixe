# STATE — Rixe
*Dernière mise à jour : 2026-10-08*

## Résumé de l'état actuel
Jeu de combat 2D stickman en Godot 4.7.2, sur la tour (`/mnt/projects/rixe`, lien `~/projects/rixe`). Dernière version publiée : **v3.3.0** (corps à corps, mode MAINS NUES). v3.1.2 testée en ligne par Chris avec un ami (deux Arch, « fluide ») ; 3.2.x et 3.3.0 pas encore jouées par Chris.
- Dépôt public : github.com/Chrlstopher-c/rixe. CI verte (63 tests headless + relais + partie en ligne à deux jeux).
- Releases sur GitHub pour Linux (testée), Windows (testée sous Proton-GE, pas sur un vrai PC Windows) et macOS universel (compilée, jamais lancée sur un vrai Mac).
- Modes : Arcade, Mains nues, Chrono, Objectif, Survie, parties perso. Écran partagé à deux, manette, en ligne jusqu'à 4 (code de 4 lettres).
- Intro cinématique au lancement (remplace le logo Godot).
- En ligne : relais Cloudflare Worker déployé (wrangler connecté sur la tour, compte de Chris), aller-retour ~11 ms ; adresse dans `online/relay.cfg` (hors dépôt, embarquée dans les builds).
- Perf 1080p sur la tour : 150 à 210 i/s en moyenne, 1 % bas entre 50 et 100 selon la carte et le nombre de combattants.
- Textures générées par Pigment (`/mnt/projects/pigment`, dépôt privé, MCP `pigment`).

## Ce qui a été fait — nuit du 07 au 08/10 (v3.3.0, demande de Chris, Chris présent en fin de nuit)
- Corps à corps poussé : combos (direct, crochet, coup de pied ; appuis mémorisés, fenêtre d'enchaînement 0,35 s,
  les poings étourdissent), coup de pied sauté en l'air, parade sur tous les coups (`fighters/melee.gd`) ; projection V / R3
  (`fighters/grapple.gd` : saisie, arc par-dessus la tête, jet derrière, étourdi ; distant = jet direct par le coup
  relayé) ; saltos au double saut et au saut mural (`moves.flip_t`, drapeau réseau F_FLIP, coup en cours synchronisé).
- Mode MAINS NUES (`Modes.apply` : arcade + armes « mains nues ») : arme `fists` (tirer = frapper, garde poings levés,
  ni grenades ni armes au sol), bots au contact (sauts, projections), classement à part ; option d'armes en partie perso.
- Tests : `tests/test_online_melee.gd` (exécution et projection en ligne, hérite des utilitaires de `test_online.gd`),
  scénario `tools/online_test.sh throw` ajouté à la CI ; prise relâchée si le lanceur quitte l'arbre.

## Ce qui a été fait — nuit du 07 au 08/10 (v3.2.1)
- Intro cinématique au lancement (demande de Chris) : logo Godot coupé (fond uni), combat chorégraphié de 4,5 s
  (`hud/intro_choreo.gd` : poses clés interpolées, caméra, coups ; `hud/intro_fighter.gd` : visages expressifs),
  sang et dents, salto, ralenti et décapitation, puis titre qui s'abat et saigne ; musique `tools/gen_intro_music.py`
  calée dessus (150 BPM). 7,5 s, une touche la passe ; jamais en tests, démos ni captures.
- Toutes les idées d'`IDEES.md` sont faites : normal maps sur les tuiles (relief sous les éclairs), flaques qui reflètent
  sous la pluie (shader d'écran), voie et wagonnet dans la mine, décors animés en planches de sprites
  (`tools/gen_sprites.py` : ventilateurs, torches, drapeaux).
- Démos, captures et mesures (`--demo`, `--shot`, `--perf`) n'écrivent plus le profil ni les réglages.
- Plantage en release corrigé : un modulo par zéro (SIGFPE) tue le binaire exporté là où l'éditeur ne fait qu'une erreur.

## Ce qui a été fait — nuit du 07 au 08/10 (v3.2.0, en autonomie)
- En ligne : exécution par l'invité, jusqu'à 4 joueurs (relais à places, diffusion), pseudos, arrivée en cours de partie.
- Parties personnalisées (local et en ligne) : mode, durée, carte, équipes et choix d'équipe, bots, niveau, armes.
- Classement mondial sur le Worker (Durable Object SQLite `Scores`), onglet MONDIAL.
- Mouvements (roulade, glissade, saut mural, parade), chiffres de dégâts, flèches de tir hors champ, ralenti à la demande,
  boss toutes les 5 manches, progression (niveaux, tenues, succès, défi du jour, stats), annonces vocales en plus.
- Visuel : ombres d'explosions (option, coupée par défaut : coût des occulteurs), impacts persistants, fumée au sol,
  néons, premier plan en parallaxe. Cartes Usine (tapis, presses, vitres) et Forêt de nuit ; verre et béton (Pigment).
- Audio : une ambiance musicale par thème, écho selon la carte. Rediffusion 15 s, mode photo, éditeur de cartes.

## Décisions prises
| Décision | Raison | Date |
|----------|--------|------|
| Rendu HD par défaut, pixel en option (F1) | Chris veut des personnages nets | 07/10 |
| Saut : touche maintenue = rebond auto, buffer 0,2 s, 2 sauts en l'air | Chris veut « spammer » le saut | 07/10 |
| Ralenti seulement sur une mort par la tête | Consigne de Chris | 07/10 |
| Tout se fait et se teste sur la tour, rien sur le portable | Consigne de Chris | 07/10 |
| Physique à 120 Hz conservée | À 60 Hz le gain était nul : le coût venait des dessins, pas de la physique | 07/10 |
| Arènes sous `arena/`, survie sous `survival/` | Découpage par domaine | 07/10 |
| Mac : signature ad hoc, sans notarisation | Pas de compte développeur Apple | 07/10 |
| En ligne : relais WebSocket (Durable Object), pas WebRTC | Marche derrière toutes les box sans port ni binaire natif ; +10-30 ms | 07/10 |
| En ligne : hôte autoritaire, chacun maître de son combattant, « qui provoque l'effet calcule ses dégâts » | Pas de double dégât, pas de prédiction à écrire | 07/10 |
| Ombres coupées par défaut | Les occulteurs coûtent ~20 % d'i/s même sans lumière à ombre ; 1 % bas < 50 sur mine/toits | 08/10 |
| En ligne à 4 : diffusion à tous avec l'octet de l'expéditeur, messages adressés par « to » | Pas de serveur de jeu ; chaque invité voit les autres directement | 08/10 |
| Projection sur V (et R3), pas C | C = « manger » en survie, les deux se déclencheraient | 08/10 |
| Mains nues = arme `fists` (tirer = frapper) + mode variante de l'arcade (`Modes.apply`) | L'IA vise et « tire » à sa distance idéale : elle va au contact sans logique dédiée ; aucune règle d'arcade dupliquée | 08/10 |
| Intro : combat chorégraphié par poses clés + musique synthétisée calée dessus, sans sous-titre | Retour de Chris : « bien fluide, gore, expressions, cinématique », le sous-titre « c'est trop » | 08/10 |
| Tests longs (binaires, Proton, en ligne) en tâche de fond | Consigne de Chris : ne jamais bloquer dessus | 08/10 |
| Adresse du relais hors dépôt (`online/relay.cfg`, embarquée à l'export) | Règle : aucun identifiant d'infrastructure dans un dépôt public | 07/10 |

## Contexte non-évident
- **Captures** : `tools/capture.sh` filme en temps réel (Xvfb + x11grab). Le movie maker de Godot enregistre la taille logique 640×360 en HD, donc inutilisable ici.
- **Perf** : `tools/perf.sh` tourne sur un sway headless rendu par le GPU, avec un XDG_RUNTIME_DIR privé. Ne jamais mesurer sur Xvfb (~8 i/s en 1080p).
- **Profilage** : `core/prof.gd` avec RIXE_PROF=1 (Prof.begin/end). Les gros postes ont été le dessin des bonhommes et les particules.
  - Correctifs appliqués : tracés regroupés (draw_multiline), fantômes allégés, rien de dessiné hors écran.
- **Tests** : `--tests=…` dans le jeu même, avec `--fixed-fps 120`. Les noms en `showcase*` sont des démos filmables, exclues de `all`.
- **Réglages** : jamais écrits pendant les tests, démos, captures et mesures (`Settings.persist = false`).
- **Pièges GDScript** :
  - `is_instance_valid` peut mentir sur une variable typée : utiliser `weakref`.
  - Un objet libéré passé à un paramètre typé provoque une erreur : passer par `Variant`.
  - `class_name Tree` est interdit (classe native), d'où `WildTree`.
  - Modulo ou division entière par zéro : simple erreur dans l'éditeur, **plantage SIGFPE** du binaire exporté.
    Tester les binaires plusieurs fois (`build/linux/rixe.x86_64 --headless --fixed-fps 120 -- --tests=all`).
- **Écran partagé** : deux SubViewport partagent le World2D. La vue principale est éteinte (caméra désactivée, transformation hors champ). Les caméras actives sont dans `Juice.cameras`.
- **Export macOS** : nécessite `textures/vram_compression/import_etc2_astc=true`.

## Prochaines étapes
1. Chris veut « ajouter des choses en plus » après la 3.3.0 : lui proposer la suite (clés et contres dédiés au corps à
   corps, survie en ligne, clavier pour le J2, éditeur d'objets…) et recueillir ses retours de jeu sur 3.2.x / 3.3.0.
2. Test Mac/Windows sur de vraies machines.

## Points en suspens
- Le sous-domaine workers.dev du compte a été créé au premier déploiement (nom = celui du Worker) : il vaut pour tout le compte ; le changer change l'adresse du relais (à re-embarquer dans une release).
- Builds Windows et macOS jamais lancées sur une vraie machine.

## Historique
- 07→08/10 nuit (Chris réveillé en fin de nuit) : v3.2.0 (en ligne à 4, parties perso, progression, classement mondial),
  v3.2.1 (intro, flaques, wagonnet, décors animés, normal maps), v3.3.0 (corps à corps, mains nues). Branche
  nuit/2026-10-08 fusionnée dans main.
- 07/10 suite : v3.1.0 (marqueurs de touche, kill cam, exécutions, musique en couches, annonceur Qwen3-TTS, en ligne par
  relais Cloudflare), v3.1.1 (version en ligne, recalage du décor, tests Linux ↔ Windows Proton), v3.1.2 (viseur, focus).
  Bug du temps réel corrigé (`Juice.real_delta` à l'horloge).
- 07/10 : v1.0.0 arcade (validée par Chris) → v1.1 décor destructible → v1.2 armurerie → v1.3 butin et cartes → v2.0
  survie → v3.0 manette et écran partagé → v3.0.1 macOS ; `IDEES.md` créé.
- 07/10 nuit : V1 arcade (E1–E10), branche nuit/2026-10-07 fusionnée dans main.
- 07/10 : prototype montré, retours appliqués (HD, persos plus grands, bots moins forts, sauts), brief validé.
