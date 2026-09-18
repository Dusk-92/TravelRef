# TravelRef FR

Adaptation française et maintenance de **TravelRef** pour **The Lord of the Rings Online (LOTRO)**.

- Version actuelle : **3.3.2-FR-r12**
- Addon original : **David Down (Vinny)**
- Adaptation / maintenance française : **Dusk-92**
- Interface et commandes : français
- Clés internes de routage : anglais, volontairement conservées pour préserver la compatibilité des données et sauvegardes

## Installation

Copier le dossier `Dusk` dans :

`Documents/The Lord of the Rings Online/Plugins/`

Puis, en jeu :

`/plugins refresh`

`/plugins load TravelRef`

L'entrée chargée est `Dusk.TravelRef.TR_Entry`.

## Commandes principales

- `/trw` : ouvrir TravelRef
- `/tr <zone>` : lister les écuries d'une zone
- `/tra <nom>` : chercher une sous-zone
- `/trf <nom>` : chercher un lieu
- `/trl ;loc` : trouver l'écurie la plus proche à partir de `;loc`
- `/trr ;loc` : trouver le recruteur de mission le plus proche
- `/trv` : gérer les lieux non visités
- `/trv ;loc` : trouver le coffre le plus proche
- `/tr?` : aide complète

Les coordonnées reconnaissent `W/w` et `O/o` pour l'ouest.

## Localisation française

TravelRef conserve les noms anglais comme clés internes et traduit uniquement l'affichage.

Les correspondances de lieux, zones, sous-zones et prérequis sont générées à partir des données EN/FR de LOTRO publiées par **LotroCompanion/lotro-data**, en reliant les deux langues avec la même clé de localisation du jeu.

Couverture contrôlée par la CI :

- 426 / 426 noms de lieux et destinations
- 47 / 47 zones
- 83 / 83 sous-zones
- 77 / 77 prérequis de voyage

Les correspondances ambiguës ne sont pas choisies arbitrairement. Quelques anciens noms absents des données actuelles utilisent des overrides historiques explicitement documentés.

## Sauvegardes

Depuis r11, TravelRef utilise son propre apartment Lua :

`<Configuration Apartment="TravelRef"/>`

Les wrappers PluginData restent locaux à TravelRef. Ils savent récupérer les anciennes sauvegardes simple ou double-encodées créées sur certains clients FR/DE, y compris après un changement de langue du client.

La CI teste :

- sauvegarde native
- sauvegarde localisée
- ancien double encodage
- chargement dans une autre langue
- callback de chargement
- protection contre l'écrasement après échec de lecture

## Validation automatique

Le workflow **Validate TravelRef** vérifie notamment :

- syntaxe Lua 5.1
- cohérence de `TR_Data.lua`
- règles de routage et réductions
- relations entre lieux et destinations
- recherches par coordonnées
- coordonnées françaises avec `O` pour Ouest
- sauvegardes PluginData
- syntaxe XML du plugin
- génération et couverture de la localisation FR
- garde-fous contre les régressions déjà corrigées

Le fichier `tools/release_audit.lua` constitue l'audit permanent des données de release.

## Structure utile

- `Dusk/TravelRef.plugin` : manifeste LOTRO
- `Dusk/TravelRef/TR_Main.lua` : commandes et logique principale
- `Dusk/TravelRef/TR_Window.lua` : interface et moteur de route historique
- `Dusk/TravelRef/TR_RouteRules.lua` : règles testables de prérequis/réductions
- `Dusk/TravelRef/TR_Robustness.lua` : protections runtime
- `Dusk/TravelRef/TR_OfficialFR.lua` : couche d'affichage FR
- `Dusk/TravelRef/TR_Data.lua` : base de déplacements
- `tools/` : génération, tests et audits

## Historique

L'historique complet du projet original et des versions FR se trouve dans :

`Dusk/TravelRef/Updates.txt`

Les détails techniques des corrections françaises sont dans :

`Dusk/TravelRef/TR_FR_NOTES.txt`

## Attribution

TravelRef a été créé et maintenu historiquement par **David Down / Vinny**.

Cette branche conserve cette attribution dans le manifeste et ajoute l'adaptation française, les données de localisation, les tests et les correctifs de robustesse maintenus par **Dusk-92**.

Le dépôt contient aussi des composants tiers historiques avec leurs propres notices intégrées dans les fichiers concernés. Aucune nouvelle licence globale n'est imposée ici au code original.
