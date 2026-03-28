#!/usr/bin/env python3
"""
extract_quran_vocab.py
======================
Extrait le vocabulaire coranique depuis le Quranic Arabic Corpus
(https://corpus.quran.com/lemmas.jsp) et génère un words.json
compatible avec l'application iOS CoranLexique.

Usage :
    pip install requests beautifulsoup4
    python3 extract_quran_vocab.py                  # scrape en ligne
    python3 extract_quran_vocab.py --offline         # dictionnaire embarqué uniquement
    python3 extract_quran_vocab.py --merge existing_words.json

Source des données : https://corpus.quran.com  (GNU License)
Format morphologie : https://corpus.quran.com/download/
"""

import sys
import json
import re
import time
import uuid
import unicodedata
import argparse
from pathlib import Path

# ── Dépendances optionnelles ────────────────────────────────────────────────
try:
    import requests
    from bs4 import BeautifulSoup
    SCRAPING_AVAILABLE = True
except ImportError:
    SCRAPING_AVAILABLE = False
    print("⚠  requests/beautifulsoup4 non disponibles — mode offline activé.")
    print("   Pour activer le scraping : pip install requests beautifulsoup4\n")

# ============================================================================
# SECTION 1 — TABLES DE CONVERSION BUCKWALTER
# Format : Buckwalter Transliteration System v2 (utilisé par corpus.quran.com)
# ============================================================================

# Buckwalter → script arabe (avec diacritiques)
BW_TO_AR: dict[str, str] = {
    "'": "ء",  "|": "آ",  ">": "أ",  "&": "إ",  "<": "إ",
    "{": "ا",  "b": "ب",  "t": "ت",  "v": "ث",  "j": "ج",
    "H": "ح",  "x": "خ",  "d": "د",  "*": "ذ",  "r": "ر",
    "z": "ز",  "s": "س",  "$": "ش",  "S": "ص",  "D": "ض",
    "T": "ط",  "Z": "ظ",  "E": "ع",  "g": "غ",  "f": "ف",
    "q": "ق",  "k": "ك",  "l": "ل",  "m": "م",  "n": "ن",
    "h": "ه",  "w": "و",  "y": "ي",  "Y": "ى",  "p": "ة",
    "A": "ا",  "~": "ّ",
    "a": "َ",  "i": "ِ",  "u": "ُ",
    "F": "ً",  "K": "ٍ",  "N": "ٌ",  "o": "ْ",  "`": "ٰ",
}

# Buckwalter → translittération ALA-LC (version lisible pour l'app)
BW_TO_LATIN: dict[str, str] = {
    "'": "ʾ",  "|": "ā",  ">": "ʾ",  "&": "ʾ",  "<": "ʾ",
    "{": "",   "b": "b",  "t": "t",  "v": "th", "j": "j",
    "H": "ḥ",  "x": "kh", "d": "d",  "*": "dh", "r": "r",
    "z": "z",  "s": "s",  "$": "sh", "S": "ṣ",  "D": "ḍ",
    "T": "ṭ",  "Z": "ẓ",  "E": "ʿ",  "g": "gh", "f": "f",
    "q": "q",  "k": "k",  "l": "l",  "m": "m",  "n": "n",
    "h": "h",  "w": "w",  "y": "y",  "Y": "ā",  "p": "h",
    "A": "ā",  "~": "",
    "a": "a",  "i": "i",  "u": "u",
    "F": "an", "K": "in", "N": "un", "o": "",   "`": "",
}

def bw_to_arabic(bw: str) -> str:
    """Convertit le Buckwalter en script arabe (avec diacritiques complets)."""
    out = ""
    for c in bw:
        out += BW_TO_AR.get(c, c)
    return out

def bw_to_arabic_bare(bw: str) -> str:
    """Arabe sans diacritiques courts (plus lisible pour les entrées lexicales)."""
    ar = bw_to_arabic(bw)
    # Supprime harakat (voyelles brèves) sauf shadda (ّ)
    harakat = "ًٌٍَُِْٰ"
    return "".join(c for c in ar if c not in harakat)

def bw_to_translit(bw: str) -> str:
    """Convertit Buckwalter → translittération académique (ALA-LC simplifié)."""
    out = ""
    i = 0
    while i < len(bw):
        c = bw[i]
        # Shadda = double la lettre précédente
        if c == "~" and out and out[-1].isalpha():
            out += out[-1]
        # Voyelles longues contextuelles
        elif c == "A" and i > 0:
            out += "ā"
        elif c == "w" and i > 0 and bw[i-1] == "u":
            out += ""   # /uw/ → ū déjà traité
        elif c == "y" and i > 0 and bw[i-1] == "i":
            out += ""   # /iy/ → ī déjà traité
        else:
            out += BW_TO_LATIN.get(c, c)
        i += 1
    # Nettoyage
    out = re.sub(r"([aiu])\1+", r"\1", out)  # dédoublonner les voyelles
    out = out.strip("-").strip()
    return out

def strip_arabic_diacritics(text: str) -> str:
    """Supprime tous les diacritiques arabes pour la comparaison."""
    diacritics = "ًٌٍَُِّْٰٓٔٗ٘"
    tatweel = "ـ"
    return "".join(c for c in text if c not in diacritics + tatweel)

# ============================================================================
# SECTION 2 — MAPPING DES POS TAGS → CATÉGORIES DE L'APP
# Tags source : Quranic Arabic Corpus v0.4
# ============================================================================

# Tous les tags POS du corpus → 5 catégories iOS
POS_MAP: dict[str, str] = {
    # Noms
    "N": "Nom",   "PN": "Nom",
    # Verbes
    "V": "Verbe",
    # Adjectifs
    "ADJ": "Adjectif",
    # Pronoms
    "PRON": "Pronom", "REL": "Pronom", "DEM": "Pronom",
    # Particules (toutes les autres catégories)
    "P": "Particule", "CONJ": "Particule", "NEG": "Particule",
    "INTG": "Particule", "EMPH": "Particule", "CERT": "Particule",
    "COND": "Particule", "FUT": "Particule",  "IMPV": "Particule",
    "VOC": "Particule",  "EQ": "Particule",   "PREV": "Particule",
    "RES": "Particule",  "RSLT": "Particule", "SUP": "Particule",
    "AMD": "Particule",  "ANS": "Particule",  "AVR": "Particule",
    "CAUS": "Particule", "COM": "Particule",  "LOC": "Particule",
    "T": "Particule",    "SUB": "Particule",  "REM": "Particule",
    "EXH": "Particule",  "RET": "Particule",  "EXLM": "Particule",
    "CIRC": "Particule", "SUR": "Particule",
}

def map_pos(pos_str: str) -> str:
    """Convertit un tag POS du corpus en catégorie de l'app."""
    s = pos_str.strip().upper()
    if s in POS_MAP:
        return POS_MAP[s]
    # Correspondance préfixe
    for key, val in POS_MAP.items():
        if s.startswith(key):
            return val
    # Descriptions anglaises (utilisées dans la table HTML)
    lower = pos_str.lower()
    if "verb" in lower:                    return "Verbe"
    if "noun" in lower or "name" in lower: return "Nom"
    if "adj" in lower:                     return "Adjectif"
    if "pron" in lower:                    return "Pronom"
    return "Particule"

# ============================================================================
# SECTION 3 — DICTIONNAIRE EMBARQUÉ (top 400 mots coraniques)
# Clé   : forme arabe sans diacritiques (pour la correspondance)
# Valeur: (sens_fr, root_bw, pos_tag, fréquence, translittération, arabe_avec_diacritiques)
# ============================================================================

# Format : "arabe_bare": ("signification", "racine BW", "POS", freq, "translit", "arabe_diacritique")
EMBEDDED: dict[str, tuple[str, str, str, int, str, str]] = {
    # ── PARTICULES ─────────────────────────────────────────────────────────
    # (meaning, root_bw, pos, freq, transliteration, arabic_with_diacritics)
    "من":    ("De / Parmi / Depuis",           "",    "P",    3226, "min",       "مِنْ"),
    "في":    ("Dans / En",                      "",    "P",    1706, "fī",        "فِي"),
    "لا":    ("Non / Pas / Ne",                 "",    "NEG",  1710, "lā",        "لَا"),
    "على":   ("Sur / Contre / À propos de",     "",    "P",    1461, "ʿalā",      "عَلَى"),
    "إلى":   ("Vers / À / Jusqu'à",             "",    "P",    1488, "ilā",       "إِلَى"),
    "ان":    ("Certes / Vraiment",              "",    "CERT", 1448, "inna",      "إِنَّ"),
    "إن":    ("Certes / Vraiment",              "",    "CERT", 1448, "inna",      "إِنَّ"),
    "و":     ("Et",                             "",    "CONJ", 9999, "wa",        "وَ"),
    "ف":     ("Alors / Et / Donc",              "",    "CONJ", 3394, "fa",        "فَ"),
    "ب":     ("Avec / Par / En",                "",    "P",    2234, "bi",        "بِ"),
    "ل":     ("Pour / À / Certes",              "",    "P",    2134, "li",        "لِ"),
    "عن":    ("De / À propos de / Loin de",     "",    "P",     820, "ʿan",       "عَن"),
    "ما":    ("Ce qui / Pas / Rien",            "",    "NEG",  1437, "mā",        "مَا"),
    "لم":    ("Ne...pas (passé)",               "",    "NEG",   940, "lam",       "لَمْ"),
    "إذا":   ("Quand / Lorsque / Si",           "",    "COND",  406, "idhā",      "إِذَا"),
    "إذ":    ("Quand / Lorsque (passé)",        "",    "COND",  260, "idh",       "إِذْ"),
    "حتى":   ("Jusqu'à / Au point que",         "",    "P",     358, "ḥattā",     "حَتَّى"),
    "أو":    ("Ou / Soit",                      "",    "CONJ",  326, "aw",        "أَوْ"),
    "ثم":    ("Puis / Ensuite / De plus",       "",    "CONJ",  338, "thumma",    "ثُمَّ"),
    "بل":    ("Au contraire / Plutôt",          "",    "RET",   127, "bal",       "بَل"),
    "لكن":   ("Mais / Cependant",              "",    "CONJ",   24, "lākin",     "لَكِن"),
    "لكنّ":  ("Mais / Cependant (emphase)",    "",    "CONJ",   49, "lākinna",   "لَكِنَّ"),
    "إلا":   ("Sauf / Excepté / Uniquement",    "",    "RES",   663, "illā",      "إِلَّا"),
    "لن":    ("Ne...jamais (futur)",            "",    "NEG",   132, "lan",       "لَن"),
    "سوف":   ("Bientôt / Va (futur)",           "",    "FUT",    14, "sawfa",     "سَوْفَ"),
    "هل":    ("Est-ce que ? (interrogatif)",    "",    "INTG",  367, "hal",       "هَل"),
    "لعل":   ("Peut-être / Afin que",           "",    "EQ",    129, "laʿalla",   "لَعَلَّ"),
    "مع":    ("Avec / En compagnie de",         "",    "P",     182, "maʿa",      "مَعَ"),
    "بين":   ("Entre / Parmi",                  "",    "P",     176, "bayna",     "بَيْن"),
    "دون":   ("En dessous / Sans",              "",    "P",      68, "dūna",      "دُون"),
    "غير":   ("Autre que / Sans / Non",         "",    "P",     157, "ghayra",    "غَيْر"),
    "عند":   ("Auprès de / Chez",              "",    "P",     249, "ʿinda",     "عِنْد"),
    "فوق":   ("Au-dessus de / Plus que",        "",    "P",      32, "fawqa",     "فَوْق"),
    "تحت":   ("En dessous de / Sous",           "",    "P",      16, "taḥta",     "تَحْت"),
    "قبل":   ("Avant / Auparavant",             "",    "P",     145, "qabla",     "قَبْل"),
    "بعد":   ("Après / Ensuite",               "",    "P",     196, "baʿda",     "بَعْد"),
    "خلف":   ("Derrière / Après",               "",    "P",      17, "khalfa",    "خَلْف"),
    "كلا":   ("Non certes ! (réfutation)",      "",    "RET",    33, "kallā",     "كَلَّا"),
    "يا":    ("Ô ! (vocatif)",                  "",    "VOC",   329, "yā",        "يَا"),
    "أن":    ("Que (conjonction)",              "",    "SUB",   874, "an",        "أَن"),
    "كي":    ("Afin que / Pour que",            "",    "SUB",    55, "kay",       "كَيْ"),
    "لو":    ("Si / Si seulement",              "",    "COND",  115, "law",       "لَو"),
    "لما":   ("Quand / Lorsque / Pas encore",   "",    "COND",  105, "lammā",     "لَمَّا"),
    # ── NOMS ────────────────────────────────────────────────────────────────
    "الله":  ("Dieu (Allah)",                  "Alh",  "N",   2699, "Allāh",       "اللَّه"),
    "رب":    ("Seigneur / Maître",             "rbb",  "N",    970, "rabb",        "رَبّ"),
    "يوم":   ("Jour",                          "ywm",  "N",    405, "yawm",        "يَوْم"),
    "ارض":   ("Terre / Sol",                   ">rD",  "N",    461, "arḍ",         "أَرْض"),
    "سماء":  ("Ciel",                          "smw",  "N",    310, "samāʾ",       "سَمَاء"),
    "ناس":   ("Les gens / L'humanité",         "nws",  "N",    241, "nās",         "نَاس"),
    "نبي":   ("Prophète",                      "nb>",  "N",     75, "nabī",        "نَبِيّ"),
    "رسول":  ("Messager / Envoyé",             "rsl",  "N",    332, "rasūl",       "رَسُول"),
    "قوم":   ("Peuple / Nation / Communauté",  "qwm",  "N",    383, "qawm",        "قَوْم"),
    "كتاب":  ("Livre / Écriture",              "ktb",  "N",    255, "kitāb",       "كِتَاب"),
    "اية":   ("Signe / Verset",                ">yy",  "N",    382, "āya",         "آيَة"),
    "امر":   ("Ordre / Affaire / Commandement","<mr",  "N",    247, "amr",         "أَمْر"),
    "حق":    ("Vérité / Droit / Réalité",      "Hqq",  "N",    287, "ḥaqq",        "حَقّ"),
    "عذاب":  ("Châtiment / Supplice",          "Edb",  "N",    322, "ʿadhāb",      "عَذَاب"),
    "جنة":   ("Paradis / Jardin",              "jnn",  "N",    147, "janna",       "جَنَّة"),
    "نار":   ("Feu / Enfer",                   "nwr",  "N",    145, "nār",         "نَار"),
    "ملك":   ("Roi / Souverain",               "mlk",  "N",     87, "malik",       "مَلِك"),
    "ملائكة":("Anges",                         "l>k",  "N",      4, "malāʾika",    "مَلَائِكَة"),
    "شيطان": ("Diable / Démon / Satan",        "$yTn", "N",     88, "shayṭān",     "شَيْطَان"),
    "قلب":   ("Cœur",                          "qlb",  "N",    132, "qalb",        "قَلْب"),
    "نفس":   ("Âme / Soi / Personne",         "nfs",  "N",    295, "nafs",        "نَفْس"),
    "دين":   ("Religion / Jugement / Foi",     "dyn",  "N",     92, "dīn",         "دِين"),
    "عمل":   ("Action / Œuvre",               "Eml",  "N",    127, "ʿamal",       "عَمَل"),
    "سبيل":  ("Chemin / Voie / Sentier",       "sbl",  "N",    176, "sabīl",       "سَبِيل"),
    "حياة":  ("Vie",                           "Hyy",  "N",     71, "ḥayāt",       "حَيَاة"),
    "موت":   ("Mort",                          "mwt",  "N",     65, "mawt",        "مَوْت"),
    "رحمة":  ("Miséricorde / Grâce",           "rHm",  "N",    114, "raḥma",       "رَحْمَة"),
    "نعمة":  ("Bienfait / Grâce / Faveur",     "nEm",  "N",     28, "niʿma",       "نِعْمَة"),
    "قيامة": ("Résurrection / Jour Dernier",   "qwm",  "N",     70, "qiyāma",      "قِيَامَة"),
    "اخرة":  ("Au-delà / Vie future",          "<xr",  "N",    117, "ākhira",      "آخِرَة"),
    "دنيا":  ("Monde présent / Ici-bas",       "dny",  "N",    115, "dunyā",       "دُنْيَا"),
    "اهل":   ("Famille / Gens / Peuple de",    "Ahl",  "N",    127, "ahl",         "أَهْل"),
    "ابن":   ("Fils",                          "bny",  "N",    163, "ibn",         "اِبْن"),
    "رجل":   ("Homme",                         "rjl",  "N",     55, "rajul",       "رَجُل"),
    "امراة": ("Femme / Épouse",               ">mr",  "N",     26, "imraʾa",      "اِمْرَأَة"),
    "علم":   ("Savoir / Connaissance",         "Elm",  "N",    105, "ʿilm",        "عِلْم"),
    "هدى":   ("Guidance / Bonne voie",        "hdy",  "N",     79, "hudā",        "هُدَى"),
    "نور":   ("Lumière",                       "nwr",  "N",     43, "nūr",         "نُور"),
    "ظلمة":  ("Ténèbres",                      "Zlm",  "N",      6, "ẓulma",       "ظُلْمَة"),
    "ماء":   ("Eau",                           "mw>",  "N",     63, "māʾ",         "مَاء"),
    "ايمان": ("Foi / Croyance",               ">mn",  "N",     45, "īmān",        "إِيمَان"),
    "اسلام": ("Soumission à Dieu / Islam",     "slm",  "N",      8, "islām",       "إِسْلَام"),
    "كفر":   ("Mécréance / Ingratitude",       "kfr",  "N",     37, "kufr",        "كُفْر"),
    "شرك":   ("Polythéisme / Association",     "$rk",  "N",      5, "shirk",       "شِرْك"),
    "توبة":  ("Repentir",                      "twb",  "N",     10, "tawba",       "تَوْبَة"),
    "اجر":   ("Récompense / Salaire",          ">jr",  "N",    107, "ajr",         "أَجْر"),
    "ذنب":   ("Péché / Faute",                 "*nb",  "N",     37, "dhanb",       "ذَنْب"),
    "صبر":   ("Patience / Endurance",          "Sbr",  "N",     12, "ṣabr",        "صَبْر"),
    "شكر":   ("Gratitude / Action de grâce",   "$kr",  "N",      7, "shukr",       "شُكْر"),
    "تقوى":  ("Piété / Crainte révérencielle", "wqy",  "N",     15, "taqwā",       "تَقْوَى"),
    "حكمة":  ("Sagesse",                       "Hkm",  "N",     20, "ḥikma",       "حِكْمَة"),
    "سلام":  ("Paix / Salut",                  "slm",  "N",     42, "salām",       "سَلَام"),
    "حرب":   ("Guerre",                        "Hrb",  "N",      6, "ḥarb",        "حَرْب"),
    "ظلم":   ("Injustice / Oppression",        "Zlm",  "N",     29, "ẓulm",        "ظُلْم"),
    "عدل":   ("Justice / Équité",              "Edl",  "N",     14, "ʿadl",        "عَدْل"),
    "صدق":   ("Vérité / Sincérité",            "Sdq",  "N",     57, "ṣidq",        "صِدْق"),
    "كذب":   ("Mensonge / Fausseté",           "k*b",  "N",     28, "kadhib",      "كَذِب"),
    "غيب":   ("Invisible / Mystère / Absent",  "gyb",  "N",     49, "ghayb",       "غَيْب"),
    "حكم":   ("Jugement / Décision",           "Hkm",  "N",     45, "ḥukm",        "حُكْم"),
    "رزق":   ("Subsistance / Provision",       "rzq",  "N",     56, "rizq",        "رِزْق"),
    "خلق":   ("Création / Caractère",          "xlq",  "N",     66, "khalq",       "خَلْق"),
    "روح":   ("Esprit / Souffle de vie",       "rwH",  "N",     21, "rūḥ",         "رُوح"),
    "صلاة":  ("Prière / Salat",               "Slw",  "N",     99, "ṣalāt",       "صَلَاة"),
    "زكاة":  ("Aumône légale / Zakat",        "zky",  "N",     32, "zakāt",       "زَكَاة"),
    "صيام":  ("Jeûne",                         "Swm",  "N",      6, "ṣiyām",       "صِيَام"),
    "حج":    ("Pèlerinage / Hajj",             "Hjj",  "N",      9, "ḥajj",        "حَجّ"),
    "فتح":   ("Victoire / Ouverture",          "ftH",  "N",      9, "fatḥ",        "فَتْح"),
    "فساد":  ("Corruption / Désordre",         "fsd",  "N",     23, "fasād",       "فَسَاد"),
    "بحر":   ("Mer / Océan",                   "bHr",  "N",     41, "baḥr",        "بَحْر"),
    "جبل":   ("Montagne",                      "jbl",  "N",     39, "jabal",       "جَبَل"),
    "شجر":   ("Arbre",                         "$jr",  "N",      6, "shajara",     "شَجَرَة"),
    "ثمر":   ("Fruit",                         "vmr",  "N",     27, "thamar",      "ثَمَر"),
    "خير":   ("Bien / Bienfait / Meilleur",    "xyr",  "N",    173, "khayr",       "خَيْر"),
    "شر":    ("Mal / Mauvais",                 "$rr",  "N",     30, "sharr",       "شَرّ"),
    "بشر":   ("Être humain / Mortel",          "b$r",  "N",     36, "bashar",      "بَشَر"),
    "انسان": ("Être humain / Homme",           "Uns",  "N",     65, "insān",       "إِنْسَان"),
    "ولد":   ("Enfant / Garçon",              "wld",  "N",     44, "walad",       "وَلَد"),
    "اخ":    ("Frère",                         "<xw",  "N",     52, "akh",         "أَخ"),
    "اخت":   ("Sœur",                          "<xw",  "N",      8, "ukht",        "أُخْت"),
    "زوج":   ("Époux / Épouse / Couple",       "zwj",  "N",     81, "zawj",        "زَوْج"),
    "عدو":   ("Ennemi",                        "Edw",  "N",     74, "ʿaduww",      "عَدُوّ"),
    "صاحب":  ("Compagnon / Ami",              "SHb",  "N",     96, "ṣāḥib",       "صَاحِب"),
    "ليل":   ("Nuit",                          "lyl",  "N",     92, "layl",        "لَيْل"),
    "نهار":  ("Jour (diurne) / Journée",       "nhr",  "N",     57, "nahār",       "نَهَار"),
    "شهر":   ("Mois",                          "$hr",  "N",     13, "shahr",       "شَهْر"),
    "نصر":   ("Secours / Victoire / Aide",     "nSr",  "N",     22, "naṣr",        "نَصْر"),
    "قدر":   ("Puissance / Destin / Décret",   "qdr",  "N",     13, "qadar",       "قَدَر"),
    "امة":   ("Nation / Communauté",           ">mm",  "N",     64, "umma",        "أُمَّة"),
    "شهادة": ("Témoignage / Martyre",          "$hd",  "N",     11, "shahāda",     "شَهَادَة"),
    "نبأ":   ("Nouvelle / Information",        "nb>",  "N",     29, "nabaʾ",       "نَبَأ"),
    "ذكر":   ("Rappel / Mention / Dhikr",      "*kr",  "N",     73, "dhikr",       "ذِكْر"),
    "كلمة":  ("Parole / Mot",                  "klm",  "N",     23, "kalima",      "كَلِمَة"),
    "حمد":   ("Louange",                       "Hmd",  "N",     22, "ḥamd",        "حَمْد"),
    "فرقان": ("Critère / Discernement",        "frq",  "N",      7, "furqān",      "فُرْقَان"),
    "قرآن":  ("Le Coran / La récitation",      "qr>",  "N",     70, "Qurʾān",      "قُرْآن"),
    "توراة": ("La Torah",                      "wry",  "N",     18, "Tawrāt",      "تَوْرَاة"),
    "إنجيل": ("L'Évangile",                    "njl",  "N",     12, "Injīl",       "إِنْجِيل"),
    "صراط":  ("Chemin / Voie droite",          "SrT",  "N",     45, "ṣirāṭ",       "صِرَاط"),
    "جهنم":  ("Géhenne / Enfer",               "jhm",  "N",     77, "jahannam",    "جَهَنَّم"),
    "عرش":   ("Trône",                         "Er$",  "N",     26, "ʿarsh",       "عَرْش"),
    "كرسي":  ("Siège / Trône",                 "krs",  "N",      2, "kursī",       "كُرْسِي"),
    "قلم":   ("Plume / Calame",                "qlm",  "N",      4, "qalam",       "قَلَم"),
    "امام":  ("Chef / Guide / Imam",           ">mm",  "N",     12, "imām",        "إِمَام"),
    "مسجد":  ("Mosquée / Lieu de prosternation","sjd", "N",     28, "masjid",      "مَسْجِد"),
    # ── VERBES ─────────────────────────────────────────────────────────────
    "قال":   ("Il a dit / Dire",               "qwl",  "V",   1722, "qāla",        "قَالَ"),
    "كان":   ("Il était / Être",               "kwn",  "V",   1360, "kāna",        "كَانَ"),
    "امن":   ("Croire / Avoir foi",            ">mn",  "V",    537, "āmana",       "آمَنَ"),
    "عمل":   ("Agir / Travailler / Faire",     "Eml",  "V",    360, "ʿamila",      "عَمِلَ"),
    "جعل":   ("Faire / Créer / Établir",       "jEl",  "V",    346, "jaʿala",      "جَعَلَ"),
    "ارسل":  ("Envoyer / Dépêcher",            "rsl",  "V",    230, "arsala",      "أَرْسَلَ"),
    "نزل":   ("Descendre / Révéler",           "nzl",  "V",    293, "nazala",      "نَزَلَ"),
    "ذكر":   ("Mentionner / Se rappeler",      "*kr",  "V",    292, "dhakara",     "ذَكَرَ"),
    "علم":   ("Savoir / Connaître",            "Elm",  "V",    382, "ʿalima",      "عَلِمَ"),
    "راى":   ("Voir / Observer",               "r>y",  "V",    328, "raʾā",        "رَأَى"),
    "سمع":   ("Entendre / Écouter",            "smE",  "V",    174, "samiʿa",      "سَمِعَ"),
    "عبد":   ("Adorer / Servir",               "Ebd",  "V",    275, "ʿabada",      "عَبَدَ"),
    "اتقى":  ("Craindre Dieu / Être pieux",    "wqy",  "V",    258, "ittaqā",      "اِتَّقَى"),
    "هدى":   ("Guider / Diriger",              "hdy",  "V",     79, "hadā",        "هَدَى"),
    "ضل":    ("S'égarer / Se perdre",          "Dll",  "V",     90, "ḍalla",       "ضَلَّ"),
    "كفر":   ("Nier / Être ingrat / Mécroître","kfr",  "V",    289, "kafara",      "كَفَرَ"),
    "ظلم":   ("Opprimer / Être injuste",       "Zlm",  "V",    158, "ẓalama",      "ظَلَمَ"),
    "خلق":   ("Créer",                         "xlq",  "V",    168, "khalaqa",     "خَلَقَ"),
    "دعا":   ("Invoquer / Appeler / Prier",    "dEw",  "V",    206, "daʿā",        "دَعَا"),
    "قتل":   ("Tuer / Combattre",              "qtl",  "V",    170, "qatala",      "قَتَلَ"),
    "فعل":   ("Faire / Accomplir",             "fEl",  "V",     63, "faʿala",      "فَعَلَ"),
    "اخذ":   ("Prendre / Saisir",              "<x*",  "V",    185, "akhadha",     "أَخَذَ"),
    "جاء":   ("Venir / Arriver",               "jy>",  "V",    278, "jāʾa",        "جَاءَ"),
    "رجع":   ("Revenir / Retourner",           "rjE",  "V",    104, "rajaʿa",      "رَجَعَ"),
    "دخل":   ("Entrer",                        "dxl",  "V",     97, "dakhala",     "دَخَلَ"),
    "خرج":   ("Sortir",                        "xrj",  "V",    114, "kharaja",     "خَرَجَ"),
    "امر":   ("Ordonner / Commander",          "<mr",  "V",    247, "amara",       "أَمَرَ"),
    "نهى":   ("Interdire / Prohiber",          "nhy",  "V",     53, "nahā",        "نَهَى"),
    "شاء":   ("Vouloir / Décider",             "$y>",  "V",    147, "shāʾa",       "شَاءَ"),
    "اراد":  ("Vouloir / Désirer",             "rwd",  "V",    138, "arāda",       "أَرَادَ"),
    "وجد":   ("Trouver / Rencontrer",          "wjd",  "V",     74, "wajada",      "وَجَدَ"),
    "كذب":   ("Nier / Démentir / Mentir",      "k*b",  "V",    280, "kadhdhaba",   "كَذَّبَ"),
    "اتبع":  ("Suivre / Obéir",                "tbE",  "V",    165, "ittabaʿa",    "اِتَّبَعَ"),
    "رحم":   ("Avoir pitié / Être miséricordieux","rHm","V",   75,  "raḥima",      "رَحِمَ"),
    "غفر":   ("Pardonner / Absoudre",          "gfr",  "V",     95, "ghafara",     "غَفَرَ"),
    "حكم":   ("Juger / Décider",               "Hkm",  "V",     79, "ḥakama",      "حَكَمَ"),
    "شهد":   ("Témoigner / Attester",          "$hd",  "V",     75, "shahida",     "شَهِدَ"),
    "كتب":   ("Écrire / Prescrire",            "ktb",  "V",     98, "kataba",      "كَتَبَ"),
    "شكر":   ("Être reconnaissant / Remercier","$kr",  "V",     66, "shakara",     "شَكَرَ"),
    "بشر":   ("Annoncer une bonne nouvelle",   "b$r",  "V",     51, "bashshara",   "بَشَّرَ"),
    "انذر":  ("Avertir / Mettre en garde",     "n*r",  "V",     50, "andhara",     "أَنْذَرَ"),
    "سال":   ("Demander / Interroger",         "s>l",  "V",     72, "saʾala",      "سَأَلَ"),
    "رزق":   ("Pourvoir / Accorder des biens", "rzq",  "V",     61, "razaqa",      "رَزَقَ"),
    "بعث":   ("Ressusciter / Envoyer",         "bEv",  "V",     67, "baʿatha",     "بَعَثَ"),
    "صلى":   ("Prier / Bénir",                 "Slw",  "V",     98, "ṣallā",       "صَلَّى"),
    "فتح":   ("Ouvrir / Accorder la victoire", "ftH",  "V",     47, "fataḥa",      "فَتَحَ"),
    "صبر":   ("Être patient / Endurer",        "Sbr",  "V",     90, "ṣabara",      "صَبَرَ"),
    "ظن":    ("Penser / Croire / Supposer",    "Znn",  "V",    107, "ẓanna",       "ظَنَّ"),
    "قرأ":   ("Lire / Réciter",                "qr>",  "V",     17, "qaraʾa",      "قَرَأَ"),
    "نصر":   ("Secourir / Aider / Soutenir",   "nSr",  "V",     72, "naṣara",      "نَصَرَ"),
    "خاف":   ("Craindre / Avoir peur",         "xwf",  "V",    118, "khāfa",       "خَافَ"),
    "رجا":   ("Espérer / Avoir l'espoir",      "rjw",  "V",     30, "rajā",        "رَجَا"),
    "صدق":   ("Dire vrai / Croire",            "Sdq",  "V",     90, "ṣaddaqa",     "صَدَّقَ"),
    "كذب":   ("Nier / Traiter de menteur",     "k*b",  "V",    280, "kadhdhaba",   "كَذَّبَ"),
    "افلح":  ("Réussir / Prospérer",           "flH",  "V",     24, "aflaḥa",      "أَفْلَحَ"),
    # ── ADJECTIFS ──────────────────────────────────────────────────────────
    "عظيم":  ("Grand / Immense / Sublime",     "EZm",  "ADJ",  159, "ʿaẓīm",       "عَظِيم"),
    "رحيم":  ("Très Miséricordieux",           "rHm",  "ADJ",   95, "raḥīm",       "رَحِيم"),
    "كبير":  ("Grand / Important / Majeur",    "kbr",  "ADJ",   97, "kabīr",       "كَبِير"),
    "كريم":  ("Noble / Généreux",             "krm",  "ADJ",   27, "karīm",       "كَرِيم"),
    "عزيز":  ("Puissant / Honoré",            "Ezz",  "ADJ",   92, "ʿazīz",       "عَزِيز"),
    "حكيم":  ("Sage / Avisé",                 "Hkm",  "ADJ",   97, "ḥakīm",       "حَكِيم"),
    "قدير":  ("Omnipotent / Tout-Puissant",   "qdr",  "ADJ",   45, "qadīr",       "قَدِير"),
    "سميع":  ("Celui qui entend tout",         "smE",  "ADJ",   47, "samīʿ",       "سَمِيع"),
    "بصير":  ("Celui qui voit tout",           "bSr",  "ADJ",   47, "baṣīr",       "بَصِير"),
    "خبير":  ("Bien informé / Expert",         "xbr",  "ADJ",   45, "khabīr",      "خَبِير"),
    "غفور":  ("Très Pardonneur",               "gfr",  "ADJ",   91, "ghafūr",      "غَفُور"),
    "رؤوف":  ("Compatissant / Clément",        "r>f",  "ADJ",   11, "raʾūf",       "رَؤُوف"),
    "ودود":  ("Aimant / Affectueux",           "wdd",  "ADJ",    2, "wadūd",       "وَدُود"),
    "حميد":  ("Digne de louange",              "Hmd",  "ADJ",   17, "ḥamīd",       "حَمِيد"),
    "مجيد":  ("Glorieux / Magnifique",         "mjd",  "ADJ",    2, "majīd",       "مَجِيد"),
    "عليم":  ("Omniscient / Savant",           "Elm",  "ADJ",  158, "ʿalīm",       "عَلِيم"),
    "قريب":  ("Proche",                        "qrb",  "ADJ",   25, "qarīb",       "قَرِيب"),
    "بعيد":  ("Lointain / Éloigné",            "bEd",  "ADJ",   25, "baʿīd",       "بَعِيد"),
    "كثير":  ("Nombreux / Beaucoup",           "kvr",  "ADJ",   98, "kathīr",      "كَثِير"),
    "قليل":  ("Peu / Rare",                    "qll",  "ADJ",   52, "qalīl",       "قَلِيل"),
    "صالح":  ("Vertueux / Bon",                "SlH",  "ADJ",  114, "ṣāliḥ",       "صَالِح"),
    "فاسق":  ("Pervers / Corrompu",            "fsq",  "ADJ",   54, "fāsiq",       "فَاسِق"),
    "ظالم":  ("Injuste / Oppresseur",          "Zlm",  "ADJ",  105, "ẓālim",       "ظَالِم"),
    "مؤمن":  ("Croyant / Fidèle",             ">mn",  "ADJ",  226, "muʾmin",      "مُؤْمِن"),
    "كافر":  ("Incroyant / Mécréant",          "kfr",  "ADJ",  154, "kāfir",       "كَافِر"),
    "منافق": ("Hypocrite",                     "nfq",  "ADJ",   37, "munāfiq",     "مُنَافِق"),
    "مشرك":  ("Polythéiste / Associateur",     "$rk",  "ADJ",   44, "mushrik",     "مُشْرِك"),
    "طيب":   ("Bon / Pur / Agréable",          "Tyb",  "ADJ",   19, "ṭayyib",      "طَيِّب"),
    "خبيث":  ("Mauvais / Impur / Abject",      "xbv",  "ADJ",    5, "khabīth",     "خَبِيث"),
    "حسن":   ("Beau / Bon",                    "Hsn",  "ADJ",   76, "ḥasan",       "حَسَن"),
    "قوي":   ("Fort / Puissant",               "qwy",  "ADJ",   16, "qawī",        "قَوِيّ"),
    "ضعيف":  ("Faible",                        "DEf",  "ADJ",   13, "ḍaʿīf",       "ضَعِيف"),
    "غني":   ("Riche / Exempt de besoin",      "gny",  "ADJ",   65, "ghanī",       "غَنِيّ"),
    "فقير":  ("Pauvre / Besogneux",            "fqr",  "ADJ",    2, "faqīr",       "فَقِير"),
    "واسع":  ("Vaste / Ample",                 "wsE",  "ADJ",   11, "wāsiʿ",       "وَاسِع"),
    "شديد":  ("Fort / Intense / Sévère",       "$dd",  "ADJ",   51, "shadīd",      "شَدِيد"),
    "ظاهر":  ("Apparent / Manifeste",          "Zhr",  "ADJ",   28, "ẓāhir",       "ظَاهِر"),
    "باطن":  ("Caché / Intérieur",             "bTn",  "ADJ",    1, "bāṭin",       "بَاطِن"),
    "اول":   ("Premier",                       "Awl",  "ADJ",   31, "awwal",       "أَوَّل"),
    "رحمن":  ("Le Tout-Miséricordieux",        "rHm",  "ADJ",   57, "raḥmān",      "رَحْمَان"),
    "عادل":  ("Juste / Équitable",             "Edl",  "ADJ",    1, "ʿādil",       "عَادِل"),
    "امين":  ("Digne de confiance / Fidèle",   ">mn",  "ADJ",   11, "amīn",        "أَمِين"),
    "خالص":  ("Pur / Sincère / Exclusif",      "xlS",  "ADJ",    5, "khāliṣ",      "خَالِص"),
    # ── PRONOMS ─────────────────────────────────────────────────────────────
    "هو":    ("Il / Lui",                      "",     "PRON",  714, "huwa",       "هُوَ"),
    "هم":    ("Eux / Ils",                     "",     "PRON",  354, "hum",        "هُم"),
    "انت":   ("Tu / Toi",                      "",     "PRON",  195, "anta",       "أَنْتَ"),
    "نحن":   ("Nous",                          "",     "PRON",  110, "naḥnu",      "نَحْنُ"),
    "انا":   ("Je / Moi",                      "",     "PRON",   85, "anā",        "أَنَا"),
    "هي":    ("Elle / Lui (fém.)",             "",     "PRON",  103, "hiya",       "هِيَ"),
    "هن":    ("Elles",                         "",     "PRON",   17, "hunna",      "هُنَّ"),
    "انتم":  ("Vous (masc. pl.)",              "",     "PRON",  171, "antum",      "أَنْتُم"),
    "انتن":  ("Vous (fém. pl.)",               "",     "PRON",    1, "antunna",    "أَنْتُنَّ"),
    "هما":   ("Eux deux / Elles deux",         "",     "PRON",   41, "humā",       "هُمَا"),
    "ذلك":   ("Cela / Celui-là",              "",     "DEM",   480, "dhālika",    "ذَلِك"),
    "هذا":   ("Ceci / Celui-ci",              "",     "DEM",   296, "hādhā",      "هَذَا"),
    "هؤلاء": ("Ceux-ci / Ces gens",           "",     "DEM",   117, "hāʾulāʾi",   "هَؤُلَاء"),
    "اولئك": ("Ceux-là",                       "",     "DEM",   145, "ulāʾika",    "أُولَئِك"),
    "هذه":   ("Celle-ci / Ceci (fém.)",       "",     "DEM",    88, "hādhihi",    "هَذِه"),
    "تلك":   ("Celle-là / Cela (fém.)",       "",     "DEM",    36, "tilka",      "تِلْك"),
    "الذي":  ("Qui / Celui qui (masc.)",      "",     "REL",   913, "alladhī",    "الَّذِي"),
    "التي":  ("Qui / Celle qui (fém.)",       "",     "REL",   191, "allatī",     "الَّتِي"),
    "الذين": ("Ceux qui / Qui (pl.)",         "",     "REL",  1431, "alladhīna",  "الَّذِين"),
    "اللاتي":("Celles qui (fém. pl.)",        "",     "REL",    13, "allātī",     "اللَّاتِي"),
}

# ============================================================================
# SECTION 4 — SCRAPING DU SITE CORPUS.QURAN.COM
# ============================================================================

BASE_URL   = "https://corpus.quran.com"
LEMMAS_URL = f"{BASE_URL}/lemmas.jsp"
HEADERS    = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "fr,en;q=0.9",
}

def fetch_page(session, page: int) -> "BeautifulSoup | None":
    """Télécharge et parse une page de lemmas.jsp."""
    params = {"page": page} if page > 1 else {}
    try:
        r = session.get(LEMMAS_URL, params=params, headers=HEADERS, timeout=20)
        r.raise_for_status()
        r.encoding = "utf-8"
        return BeautifulSoup(r.text, "html.parser")
    except Exception as exc:
        print(f"  ✗  Page {page} : {exc}")
        return None

def detect_total_pages(soup: "BeautifulSoup") -> int:
    """Déduit le nombre de pages depuis le texte de pagination."""
    text = soup.get_text(" ", strip=True)
    # Ex : "Lemmas 1 to 50 of 3680"
    m = re.search(r"(\d+)\s+to\s+(\d+)\s+of\s+(\d+)", text, re.I)
    if m:
        per_page = int(m.group(2)) - int(m.group(1)) + 1
        total    = int(m.group(3))
        pages    = (total + per_page - 1) // per_page
        print(f"  ℹ  {total} lemmes · {per_page}/page · {pages} pages")
        return pages
    return 80  # valeur par défaut conservatrice

def parse_lemmas_from_page(soup: "BeautifulSoup") -> list[dict]:
    """
    Extrait les enregistrements de la table HTML de lemmas.jsp.
    La structure exacte varie selon la version du site ; on essaie
    plusieurs sélecteurs pour être robuste.
    """
    records = []
    # Cherche toutes les tables candidates
    for table in soup.find_all("table"):
        rows = table.find_all("tr")
        if len(rows) < 3:
            continue
        for row in rows[1:]:
            cells = row.find_all(["td", "th"])
            if len(cells) < 2:
                continue

            # ── Extraction de l'arabe ──────────────────────────────────
            arabic = ""
            bw_text = ""
            pos_raw = ""
            freq_raw = "0"

            for i, cell in enumerate(cells):
                text = cell.get_text(" ", strip=True)
                # Cellule arabe : contient des caractères Unicode arabes
                if any("\u0600" <= c <= "\u06FF" for c in text) and not arabic:
                    arabic = text
                # Fréquence : nombre entier seul
                elif re.match(r"^\d+$", text):
                    freq_raw = text
                # Buckwalter : ASCII pur sans chiffres
                elif re.match(r"^[a-zA-Z'<>&{|*~$]+$", text) and len(text) > 1 and not bw_text:
                    bw_text = text
                # POS description (anglais)
                elif re.match(r"^[A-Za-z ]+$", text) and not pos_raw and text.lower() not in ("count",):
                    pos_raw = text.strip()

            if arabic or bw_text:
                records.append({
                    "arabic":    arabic,
                    "buckwalter": bw_text,
                    "pos_raw":   pos_raw,
                    "frequency": int(freq_raw),
                })

    return records

def scrape_all_lemmas(max_pages: int = 100) -> list[dict]:
    """Scrape l'intégralité de lemmas.jsp et renvoie les enregistrements bruts."""
    session    = requests.Session()
    all_records = []
    print(f"\n🔎  Connexion à {LEMMAS_URL} …")
    soup1 = fetch_page(session, 1)
    if soup1 is None:
        print("  ✗  Impossible de charger la page 1.")
        return []

    total_pages = min(detect_total_pages(soup1), max_pages)
    all_records.extend(parse_lemmas_from_page(soup1))
    print(f"  ✓  Page 1/{total_pages} — {len(all_records)} enregistrements")

    for page in range(2, total_pages + 1):
        time.sleep(0.4)  # respecter le serveur
        soup = fetch_page(session, page)
        if soup is None:
            continue
        recs = parse_lemmas_from_page(soup)
        all_records.extend(recs)
        print(f"  ✓  Page {page}/{total_pages} — {len(all_records)} enregistrements cumulés")

    return all_records

# ============================================================================
# SECTION 5 — CONSTRUCTION DU JSON FINAL
# ============================================================================

def lookup_meaning(arabic: str, bw: str) -> tuple[str, str, str, str, str]:
    """
    Cherche la signification dans le dictionnaire embarqué.
    Retourne (meaning, root_bw, pos_override, translit, arabic_diacritics).
    """
    key = strip_arabic_diacritics(arabic).strip()
    if key in EMBEDDED:
        entry = EMBEDDED[key]
        meaning, root, pos, _, translit, ar_diac = entry
        return meaning, root, pos, translit, ar_diac
    # Essai avec la forme Buckwalter convertie
    ar_from_bw = strip_arabic_diacritics(bw_to_arabic_bare(bw))
    if ar_from_bw in EMBEDDED:
        entry = EMBEDDED[ar_from_bw]
        meaning, root, pos, _, translit, ar_diac = entry
        return meaning, root, pos, translit, ar_diac
    return "", "", "", "", ""

def build_entry(arabic: str, bw: str, pos_raw: str, frequency: int,
                existing_mastery: int = 0) -> dict:
    """Construit un enregistrement words.json à partir des données brutes."""
    meaning, root_bw, pos_override, translit_dict, ar_diac = lookup_meaning(arabic, bw)
    pos_final  = pos_override or pos_raw
    category   = map_pos(pos_final)

    # Translittération : dict embarqué > conversion BW > vide
    translit = translit_dict or (bw_to_translit(bw) if bw else "")

    # Arabe : forme avec diacritiques du dict > forme scrappée > BW converti
    ar_final = ar_diac or arabic or bw_to_arabic_bare(bw)

    # Racine : depuis le dict embarqué
    root_ar = bw_to_arabic_bare(root_bw) if root_bw else ""

    return {
        "id":              str(uuid.uuid4()),
        "arabic":          ar_final,
        "transliteration": translit,
        "meaning":         meaning,
        "root":            root_ar,
        "category":        category,
        "frequency":       frequency,
        "masteryLevel":    existing_mastery,
    }

def load_existing(path: Path) -> dict[str, dict]:
    """Charge un words.json existant. Clé = arabe sans diacritiques."""
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return {strip_arabic_diacritics(w["arabic"]): w for w in data}
    except Exception as e:
        print(f"  ⚠  Impossible de lire {path} : {e}")
        return {}

def merge_and_export(scraped: list[dict], existing: dict[str, dict],
                     output_path: Path) -> None:
    """Fusionne les données scrappées avec l'existant et écrit le JSON."""
    result: list[dict] = []
    seen: set[str] = set()

    for rec in scraped:
        ar     = rec["arabic"]
        bw     = rec["buckwalter"]
        key    = strip_arabic_diacritics(ar or bw_to_arabic_bare(bw))
        if key in seen:
            continue
        seen.add(key)

        # Préserver le masteryLevel si le mot était déjà dans la base
        mastery = existing.get(key, {}).get("masteryLevel", 0)
        entry   = build_entry(ar, bw, rec["pos_raw"], rec["frequency"], mastery)

        # Ne pas inclure les mots sans arabe ni sens si trop peu de données
        if not entry["arabic"]:
            continue
        result.append(entry)

    # Trier par fréquence décroissante
    result.sort(key=lambda w: w["frequency"], reverse=True)

    output_path.write_text(
        json.dumps(result, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )
    print(f"\n✅  {len(result)} mots exportés → {output_path}")

def export_embedded_only(existing: dict[str, dict], output_path: Path) -> None:
    """Export uniquement depuis le dictionnaire embarqué (mode --offline)."""
    result = []
    seen: set[str] = set()
    for ar_bare, entry in EMBEDDED.items():
        meaning, root_bw, pos, freq, translit, ar_diac = entry
        if ar_bare in seen:
            continue
        seen.add(ar_bare)

        mastery     = existing.get(ar_bare, {}).get("masteryLevel", 0)
        root_ar     = bw_to_arabic_bare(root_bw) if root_bw else ""
        existing_id = existing.get(ar_bare, {}).get("id", str(uuid.uuid4()))
        # Préfère la forme avec diacritiques du dict embarqué
        ar_final    = ar_diac or ar_bare

        result.append({
            "id":              existing_id,
            "arabic":          ar_final,
            "transliteration": translit,
            "meaning":         meaning,
            "root":            root_ar,
            "category":        map_pos(pos),
            "frequency":       freq,
            "masteryLevel":    mastery,
        })

    result.sort(key=lambda w: w["frequency"], reverse=True)
    output_path.write_text(
        json.dumps(result, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )
    print(f"\n✅  {len(result)} mots exportés (mode offline) → {output_path}")

# ============================================================================
# SECTION 6 — POINT D'ENTRÉE
# ============================================================================

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Extrait le vocabulaire coranique et génère words.json"
    )
    parser.add_argument(
        "--offline", action="store_true",
        help="Utilise uniquement le dictionnaire embarqué (pas de réseau)"
    )
    parser.add_argument(
        "--merge", metavar="FILE", default="words.json",
        help="Fichier words.json existant à fusionner (défaut: words.json)"
    )
    parser.add_argument(
        "--output", metavar="FILE", default="words_updated.json",
        help="Fichier de sortie (défaut: words_updated.json)"
    )
    parser.add_argument(
        "--max-pages", type=int, default=80,
        help="Nombre max de pages à scraper (défaut: 80 = ~4000 lemmes)"
    )
    args = parser.parse_args()

    output_path   = Path(args.output)
    existing_path = Path(args.merge)
    existing      = load_existing(existing_path)

    print("=" * 60)
    print("  CoranLexique — Extraction vocabulaire coranique")
    print("  Source : https://corpus.quran.com/lemmas.jsp")
    print("=" * 60)

    if args.offline or not SCRAPING_AVAILABLE:
        print("\n📦  Mode offline — dictionnaire embarqué uniquement")
        print(f"   {len(EMBEDDED)} entrées disponibles")
        export_embedded_only(existing, output_path)
        return

    # ── Mode en ligne ──────────────────────────────────────────────────────
    scraped = scrape_all_lemmas(max_pages=args.max_pages)

    if not scraped:
        print("\n⚠  Scraping échoué — bascule en mode offline")
        export_embedded_only(existing, output_path)
        return

    # Compléter les enregistrements scrappés avec les données du dict embarqué
    print(f"\n📖  {len(scraped)} lemmes scrappés — enrichissement avec le dictionnaire …")
    merge_and_export(scraped, existing, output_path)

    # Stats
    with open(output_path, encoding="utf-8") as f:
        data = json.load(f)
    cats = {}
    for w in data:
        cats[w["category"]] = cats.get(w["category"], 0) + 1
    print("\n📊  Répartition par catégorie :")
    for cat, count in sorted(cats.items(), key=lambda x: -x[1]):
        print(f"   {cat:<12} {count:>5} mots")
    no_meaning = sum(1 for w in data if not w["meaning"])
    print(f"\n   ⚠  {no_meaning} mots sans signification (à compléter manuellement)")

if __name__ == "__main__":
    main()
