# STATE — Rixe
*Dernière mise à jour : 2026-10-07*

## Résumé de l'état actuel
Jeu de combat 2D stickman en Godot 4.7.2, sur la tour (`/mnt/projects/rixe`, lien `~/projects/rixe`). Dernière version publiée : **v3.1.0**.
- Dépôt public : github.com/Chrlstopher-c/rixe. CI verte (40 tests headless).
- Releases sur GitHub pour Linux (testée), Windows et macOS universel (compilées, jamais lancées sur une vraie machine).
- Modes : Arcade, Chrono, Objectif, Survie. Écran partagé à deux, manette, et partie à deux en ligne (code de 4 lettres).
- En ligne : relais Cloudflare Worker déployé (wrangler connecté sur la tour, compte de Chris), aller-retour ~11 ms ; adresse dans `online/relay.cfg` (hors dépôt, embarquée dans les builds).
- Perf 1080p sur la tour : 150 à 210 i/s en moyenne, 1 % bas entre 50 et 100 selon la carte et le nombre de combattants.
- Textures générées par Pigment (`/mnt/projects/pigment`, dépôt privé, MCP `pigment`).

## Ce qui a été fait — session du 07/10 (suite, après compaction)
- Marqueurs de touche (blanc, rouge à la tête, cerclé sur élimination), sons hit/headshot, kill cam sur la dernière élimination (ralenti, zoom, bandes noires).
- Bug corrigé : le temps réel se calculait par delta/time_scale, faux l'image où l'échelle change → une image lente vidait tout un ralenti. Désormais mesuré à l'horloge une fois par image (`Juice.real_delta`), pas fixe en tests headless.
- Exécutions : bot sous 25 PV vacillant (chevron), corps à corps = exécution en deux temps (membre puis décapitation / coupé en deux / tête en l'air).
- Musique en trois couches synchrones (calme, combat selon l'action, tension en fin de manche), passe-bas au ralenti.
- Annonceur vocal (Qwen3-TTS VoiceDesign en local), relais déployé, v3.1.0 publiée.
- v3.1.1 : contrôle de version en ligne (présentation « hi », refus clair), empreinte du décor à chaque manche + recalage depuis l'hôte, délai max de connexion (sous Windows un refus ne remonte jamais). Testé Linux ↔ Windows (Proton-GE, `tools/win_run.sh`) dans les deux sens, en local et via le vrai relais ; ARM (Mac Apple Silicon) non testé, couvert par le recalage du décor.
- En ligne (E26.S1-S4) : relais Cloudflare Worker + Durable Object (`relay/`), lien et session Godot (`online/`), salon EN LIGNE, test à deux jeux en CI.
- Règles de manche sorties de `main.gd` dans `game/round_rules.gd`.

## Ce qui a été fait — session du 07/10
- **v1.0.0** : arcade. Démembrement, gore, ralenti sur mort par la tête, sons et musique synthétisés, modes Chrono et Objectif, classements. Release validée par Chris.
- **v1.1.0** : décor destructible en cellules de 8 px, ricochets, IA à 5 personnalités.
- **v1.2.0** : munitions, visée précise, remontée du canon, 5 armes de plus, grenades, accessoires, armurerie.
- **v1.3.0** : butin, inventaire (2 armes, sac, soins), 3 cartes (plateformes, toits, mine), météo, barils et lampes, effondrement du décor.
- **v2.0.0** : mode Survie (carte de 6000 px, jour/nuit, récolte, construction, faim, fabrication, pillards).
- **v3.0.0** : manette et écran partagé à deux. **v3.0.1** : export macOS universel.
- `IDEES.md` : feuille de route et idées classées, demandé par Chris.

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
| Adresse du relais hors dépôt (`online/relay.cfg`, embarquée à l'export) | Règle : aucun identifiant d'infrastructure dans un dépôt public | 07/10 |

## Contexte non-évident
- **Captures** : `tools/capture.sh` filme en temps réel (Xvfb + x11grab). Le movie maker de Godot enregistre la taille logique 640×360 en HD, donc inutilisable ici.
- **Perf** : `tools/perf.sh` tourne sur un sway headless rendu par le GPU, avec un XDG_RUNTIME_DIR privé. Ne jamais mesurer sur Xvfb (~8 i/s en 1080p).
- **Profilage** : `core/prof.gd` avec RIXE_PROF=1 (Prof.begin/end). Les gros postes ont été le dessin des bonhommes et les particules.
  - Correctifs appliqués : tracés regroupés (draw_multiline), fantômes allégés, rien de dessiné hors écran.
- **Tests** : `--tests=…` dans le jeu même, avec `--fixed-fps 120`. Les noms en `showcase*` sont des démos filmables, exclues de `all`.
- **Réglages** : jamais écrits pendant les tests (`Settings.persist = false`).
- **Pièges GDScript** :
  - `is_instance_valid` peut mentir sur une variable typée : utiliser `weakref`.
  - Un objet libéré passé à un paramètre typé provoque une erreur : passer par `Variant`.
  - `class_name Tree` est interdit (classe native), d'où `WildTree`.
- **Écran partagé** : deux SubViewport partagent le World2D. La vue principale est éteinte (caméra désactivée, transformation hors champ). Les caméras actives sont dans `Juice.cameras`.
- **Export macOS** : nécessite `textures/vram_compression/import_etc2_astc=true`.

## Prochaines étapes
1. Retours de Chris (jeu en ligne entre deux machines, exécutions, musique) et test Mac/Windows réels.
2. Suite de `IDEES.md` (tenues, éclairage, éditeur de cartes…).

## Points en suspens
- Le sous-domaine workers.dev du compte a été créé au premier déploiement (nom = celui du Worker) : il vaut pour tout le compte ; le changer change l'adresse du relais (à re-embarquer dans une release).
- Builds Windows et macOS jamais lancées sur une vraie machine.

## Historique
- 07/10 nuit : V1 arcade (E1–E10), branche nuit/2026-10-07 fusionnée dans main.
- 07/10 : prototype montré, retours appliqués (HD, persos plus grands, bots moins forts, sauts), brief validé.
