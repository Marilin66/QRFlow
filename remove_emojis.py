#!/usr/bin/env python3
"""
Script pour remplacer tous les emojis par des symboles appropriés dans les fichiers markdown.
"""

import os
import re
from pathlib import Path

# Table de correspondance emoji -> symbole
EMOJI_MAP = {
    # Checkmarks et status
    '✅': '[OK]',
    '❌': '[X]',
    '⚠️': '[!]',
    '⚠': '[!]',
    '⚪': '[ ]',
    '🟢': '[OK]',
    '🔴': '[ERROR]',
    '🟡': '[WAIT]',
    '✓': '[OK]',
    '❓': '[?]',

    # Actions et navigation
    '🚀': '[=>]',
    '🔄': '[~]',
    '➡️': '->',
    '⬅️': '<-',
    '⬆️': '^',
    '⬇️': 'v',
    '→': '->',
    '←': '<-',
    '↓': 'v',
    '⏭': '[NEXT]',
    '🔗': '[link]',

    # Documentation et info
    '📋': '[LIST]',
    '📝': '[NOTE]',
    '📊': '[CHART]',
    '📈': '[UP]',
    '📉': '[DOWN]',
    '📚': '[DOCS]',
    '📖': '[BOOK]',
    '📄': '[FILE]',
    '📁': '[FOLDER]',
    '📂': '[FOLDER]',
    '📦': '[PACKAGE]',
    '📞': '[PHONE]',
    '📧': '[EMAIL]',
    '📥': '[INBOX]',
    '📅': '[CAL]',
    '🏷': '[TAG]',
    '🏷️': '[TAG]',
    '📍': '[LOCATION]',
    '💬': '[MSG]',
    '👤': '[USER]',
    '📶': '[SIGNAL]',

    # Dev et code
    '🔧': '[TOOL]',
    '🛠': '[TOOL]',
    '⚙️': '[CONFIG]',
    '🐛': '[BUG]',
    '🔍': '[SEARCH]',
    '🔒': '[LOCK]',
    '🔓': '[UNLOCK]',
    '🔑': '[KEY]',
    '🛡': '[SHIELD]',
    '🕵': '[PRIVACY]',
    '🕵️': '[PRIVACY]',
    '🤖': '[BOT]',

    # Succès et célébration
    '🎉': '[SUCCESS]',
    '🎯': '[TARGET]',
    '🎓': '[LEARN]',
    '🏆': '[WIN]',
    '💡': '[IDEA]',
    '⭐': '[*]',
    '🌟': '[**]',
    '❤': '[HEART]',

    # Devices et tech
    '📱': '[MOBILE]',
    '💻': '[PC]',
    '🖥️': '[DESKTOP]',
    '⌨️': '[KEYBOARD]',
    '🖱️': '[MOUSE]',
    '🌐': '[WEB]',
    '📡': '[WIFI]',

    # UI et interface
    '🏗️': '[BUILD]',
    '🏗': '[BUILD]',
    '🎨': '[UI]',
    '🔵': '[O]',
    '🟥': '[#]',
    '⬜': '[ ]',
    '🔲': '[_]',
    '▶️': '[>]',
    '⏸️': '[||]',
    '⏹️': '[#]',
    '⏳': '[WAIT]',
    '🤔': '[QUESTION]',
    '🚫': '[X]',

    # QR et scan
    '📷': '[CAMERA]',
    '📸': '[PHOTO]',
    '🔎': '[SCAN]',
    '🧪': '[TEST]',

    # Autres
    '🔕': '[SILENT]',
    '🔔': '[BELL]',
    '🆔': '[ID]',
}


def replace_emojis(text):
    """Remplace tous les emojis dans le texte par leurs équivalents."""
    # Les variantes avec sélecteur de variation (U+FE0F) d'abord.
    for emoji, replacement in sorted(EMOJI_MAP.items(), key=lambda kv: -len(kv[0])):
        text = text.replace(emoji, replacement)
    # Nettoyage final : sélecteurs de variation et joncteurs orphelins.
    text = text.replace('\uFE0F', '')
    text = text.replace('\u200D', '')
    return text


def process_file(filepath):
    """Traite un fichier markdown."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        original = content
        content = replace_emojis(content)

        if content != original:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        return False
    except Exception as e:
        print(f"Erreur lors du traitement de {filepath}: {e}")
        return False


def main():
    """Parcourt tous les fichiers markdown et remplace les emojis."""
    root_dir = Path(__file__).parent
    skip_dirs = {'node_modules', 'build', '.dart_tool', 'dist', '.git', '.gradle', '.idea'}

    md_files = []
    for dirpath, dirnames, filenames in os.walk(root_dir):
        dirnames[:] = [d for d in dirnames if d not in skip_dirs]
        for name in filenames:
            if name.endswith('.md'):
                md_files.append(Path(dirpath) / name)

    print(f"Traitement de {len(md_files)} fichiers markdown...")

    modified = 0
    for md_file in md_files:
        if process_file(md_file):
            print(f"Modifié: {md_file.relative_to(root_dir)}")
            modified += 1

    print(f"\n{modified} fichiers modifiés sur {len(md_files)} fichiers markdown.")


if __name__ == '__main__':
    main()
