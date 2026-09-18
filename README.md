# 🧭 TravelRef

Référence de voyage en français pour **The Lord of the Rings Online**, avec recherche de destinations, écuries, prérequis et outils basés sur les coordonnées.

**🌍 Langue :** 🇫🇷 Français

---

## 🇫🇷 Français

### 📖 Présentation

**TravelRef** est une adaptation française et une maintenance du plugin historique de **David Down / Vinny**. Il centralise les destinations de voyage et permet de rechercher rapidement des lieux, zones, sous-zones et services liés au déplacement.

### ✨ Fonctionnalités

- Référence des destinations et compétences de voyage.
- Recherche par zone, sous-zone ou lieu.
- Liste des écuries d’une zone.
- Recherche de l’écurie la plus proche depuis `;loc`.
- Recherche du recruteur de mission le plus proche.
- Gestion des lieux non visités.
- Recherche du coffre le plus proche à partir des coordonnées.
- Prérequis et règles de voyage conservés dans la base.
- Affichage français avec clés internes anglaises préservées pour la compatibilité.
- Coordonnées françaises avec prise en charge de `O` pour Ouest.
- Sauvegardes renforcées et compatibles avec les anciennes données.

### 📦 Installation

Copie le dossier **Dusk** dans :

```text
Documents\The Lord of the Rings Online\Plugins\
```

Puis en jeu :

```text
/plugins refresh
/plugins load TravelRef
```

### 🎮 Utilisation

Ouvre TravelRef avec `/trw`, puis utilise la fenêtre ou les commandes pour rechercher une destination. Les commandes basées sur `;loc` permettent de trouver les services connus les plus proches de tes coordonnées.

### ⌨️ Commandes

- `/trw` — ouvrir TravelRef.
- `/tr <zone>` — lister les écuries d’une zone.
- `/tra <nom>` — chercher une sous-zone.
- `/trf <nom>` — chercher un lieu.
- `/trl ;loc` — trouver l’écurie la plus proche.
- `/trr ;loc` — trouver le recruteur de mission le plus proche.
- `/trv` — gérer les lieux non visités.
- `/trv ;loc` — trouver le coffre le plus proche.
- `/tr?` — afficher l’aide complète.

### ⚙️ Sauvegardes & réglages

TravelRef utilise son propre espace Lua `TravelRef`. Les routines de chargement prennent en charge plusieurs anciens formats de sauvegarde, notamment après un changement de langue du client.

Les clés internes de routage restent en anglais afin de préserver la compatibilité des données historiques.

### 🌍 Langues

Cette branche est maintenue avec une **interface et des commandes en français**. Les données de localisation affichées sont reliées aux données EN/FR du jeu lorsque cela est possible.

### ⚠️ Limites / notes

La recherche par coordonnées dépend de la base de lieux connue par TravelRef. Les données officielles pouvant évoluer, certains noms ou prérequis peuvent nécessiter une mise à jour après une modification de LOTRO.

### 🐛 Bugs & suggestions

Utilise les [Issues GitHub](https://github.com/Dusk-92/TravelRef/issues).

### 🙏 Crédits

Plugin original et maintenance historique : **David Down / Vinny**.  
Adaptation française, localisation, tests et maintenance du fork : **Dusk-92**.
