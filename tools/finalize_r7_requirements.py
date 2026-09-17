#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def replace(path, old, new, expected=1):
    p = ROOT / path
    text = p.read_text(encoding='utf-8')
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'{path}: expected {expected}, got {count} for {old!r}')
    p.write_text(text.replace(old, new), encoding='utf-8')

# Requirement generator: historical aliases that can be tied back to current
# official LOTRO faction/rank localization data.
gen = 'tools/generate_requirements_fr.py'
replace(gen,
'''    "Reclaimers of the Mtn-Hold": "Reclaimers of the Mountain-hold",
}''',
'''    "Reclaimers of the Mtn-Hold": "Reclaimers of the Mountain-hold",
    "Minas Tirith": "Defenders of Minas Tirith",
}

# TravelRef predates a terminology change for the Host of the West standing.
# The current client calls the same standing "Honoured".
RANK_ALIASES = {
    "esteemed": "Honoured",
}

# Historical epic quest titles no longer present verbatim in the current data
# files, but documented with their French LOTRO titles on the French LOTRO wiki.
LEGACY_QUEST_FR = {
    "Q1": "Le défi de la pierre",
    "Q4": "Au cœur du danger",
    "Q5": "La vingt et unième salle",
    "Q10": "La paix rétablie",
}''')

replace(gen,
'''    rank = match.group(1)
    rank = {"acq.": "Acquaintance"}.get(rank.lower(), rank)
    return rank, match.group(2).strip()''',
'''    rank = match.group(1)
    rank = {"acq.": "Acquaintance", **RANK_ALIASES}.get(rank.lower(), rank)
    return rank, match.group(2).strip()''')

replace(gen,
'''        unresolved[code] = old

    lines = [''',
'''        legacy = LEGACY_QUEST_FR.get(code)
        if legacy:
            source = "verified historical French LOTRO quest title"
            matches[code] = (legacy, source)
            details.append((code, old, legacy, source))
            continue

        unresolved[code] = old

    lines = [''')

# Runtime: apply generated requirement labels after TR_Data has created Reqs.
loc = 'Dusk/TravelRef/TR_OfficialFR.lua'
replace(loc,
'''    TR_OfficialSafeImport("Dusk.TravelRef.TR_OfficialFR_Auto", true)
''',
'''    TR_OfficialSafeImport("Dusk.TravelRef.TR_OfficialFR_Auto", true)
    TR_OfficialSafeImport("Dusk.TravelRef.TR_OfficialFR_Requirements", true)
''')

# Notes: document requirement coverage policy.
notes = 'Dusk/TravelRef/TR_FR_NOTES.txt'
replace(notes,
'''- Validation continue renforcée après l’audit r6.
''',
'''- Validation continue renforcée après l’audit r6.
- Prérequis de voyage traduits via les IDs officiels des quêtes/prouesses et les paliers/factions officiels de réputation.
- Les anciens titres dont aucune correspondance sûre n’est disponible restent en anglais plutôt que d’être traduits au hasard.
''')

print('final r7 requirement patch applied')
