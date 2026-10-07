# Architecture — Rixe

Organisation par domaine de jeu. Chaque dossier a un sens unique :

| Dossier | Rôle (et seulement ça) |
|---|---|
| `core/` | services transverses : `juice.gd` (autoload : temps, tremblement, ondes de choc, références de scène), contrôles, caméra |
| `game/` | point d'entrée, règles de partie (modes, état de partie, classements, score, déblocages), apparitions (`spawner.gd`) |
| `arena/` | cartes (`maps.gd`), décor destructible (cellules, tronçons, effondrement), objets d'arène (`props/`), ambiances, fond |
| `fighters/` | combattants : déplacement, squelette procédural, ragdoll, dégâts localisés, cerveau du joueur |
| `fighters/ai/` | intelligence des bots : personnalité (chiffres), navigation (où aller), visée (comment viser), cerveau (quoi faire) |
| `weapons/` | catalogue d'armes et d'accessoires (`arsenal.gd`), tir/lame/projectile (`gun.gd`), grenades, objets au sol |
| `fx/` | effets visuels : particules, recettes d'effets, taches, météo, post-traitement |
| `audio/` | bruitages (lecteur 2D), musique en couches, annonceur vocal (`announcer.gd`) |
| `survival/` | mode Survie : ressources/faim/jour-nuit (`survival.gd`), orchestration (`director.gd`), construction, recettes |
| `game/` (ajouts) | `game_config.gd` (parties perso), `profile.gd` (progression), `replay.gd`, `photo_mode.gd`, `map_store.gd` (cartes de l'éditeur), `round_rules.gd` |
| `fighters/` (ajouts) | `moves.gd` (roulade, glissade, saut mural, parade), `boss.gd`, `outfit.gd` (tenues), `remains.gd` (butin et dépouille) |
| `online/` | partie en ligne côté jeu : lien au relais (`net_link.gd`), session (`net_session.gd` : manches, fin de partie), combattants (`net_fighters.gd` : instantanés, marionnettes, touches, morts), monde (`net_world.gd` : tirs, décor, barils, objets), salon (`lobby.gd`) |
| `relay/` | relais en ligne (Cloudflare Worker + Durable Object, TypeScript) : salons à code de 4 lettres, ne lit jamais le jeu ; ignoré par Godot (`.gdignore`) |
| `hud/` | interface : jeu, menus (titre, pause, armurerie, classement, viseur), viseur (`crosshair.gd`), fin de partie, inventaire |
| `tests/` | banc de tests headless et scénarios |
| `tools/` | scripts hors jeu (vérification, capture, génération d'assets) |
| `assets/` | fichiers générés (textures Pigment, sons synthétisés) — jamais édités à la main |

Règles de frontière :
- Les domaines se parlent par méthodes publiques (`take_hit`, `spawn_points`, `Effects.*`, `Sfx.play`) ; pas d'accès aux variables `_privées` d'un autre dossier.
- `Juice` porte les références partagées (arène, fx, monde, caméra) : pas de chemins de nœuds codés en dur.
- Tout ce qui est aléatoire et structurant (arène) passe par une graine (`--seed`) : en ligne, l'invité regénère la carte de l'hôte avec la même graine.
- En ligne, le reste du jeu ne connaît que `Juice.net` (null hors ligne) et ses méthodes publiques (`drive`, `puppet_hit`, `shot_fired`, `terrain_hit`, `item_born`…) ; l'hôte arbitre, chacun calcule les dégâts qu'il provoque.
- `game/round_rules.gd` : fil des morts, fin de manche et de partie, kill cam (sorti de `main.gd`).
