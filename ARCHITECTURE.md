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
| `audio/` | bruitages : lecteur 2D et banque de sons |
| `survival/` | mode Survie : ressources/faim/jour-nuit (`survival.gd`), orchestration (`director.gd`), construction, recettes |
| `hud/` | interface : jeu, menus (titre, pause, armurerie, classement), fin de partie, inventaire |
| `tests/` | banc de tests headless et scénarios |
| `tools/` | scripts hors jeu (vérification, capture, génération d'assets) |
| `assets/` | fichiers générés (textures Pigment, sons synthétisés) — jamais édités à la main |

Règles de frontière :
- Les domaines se parlent par méthodes publiques (`take_hit`, `spawn_points`, `Effects.*`, `Sfx.play`) ; pas d'accès aux variables `_privées` d'un autre dossier.
- `Juice` porte les références partagées (arène, fx, monde, caméra) : pas de chemins de nœuds codés en dur.
- Tout ce qui est aléatoire et structurant (arène) passe par une graine (`--seed`).
