"""Transcrit les prises vocales (CrisperWhisper, local) pour choisir celles qui disent bien le texte.

Usage : <venv vocal>/bin/python tools/check_voice.py [dossier]  (défaut ~/Downloads/rixe-voice)
"""
import glob
import os
import sys

from loguru import logger


def main() -> None:
    from crisperwhisper import CrisperWhisperModel

    folder = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Downloads/rixe-voice")
    try:
        model = CrisperWhisperModel("nyralabs/CrisperWhisper2.0_turbo", cache_dir="/mnt/projects/mentor/.cache/stt")
    except (OSError, RuntimeError) as err:
        logger.error(f"modèle de transcription indisponible : {err}")
        raise
    for path in sorted(glob.glob(os.path.join(folder, "*.wav"))):
        text = model.transcribe(path, language="fr", mode="verbatim").text.strip()
        print(f"{os.path.basename(path)} | {text}")


if __name__ == "__main__":
    main()
