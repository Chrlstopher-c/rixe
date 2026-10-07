"""Annonces vocales du jeu, générées en local par Qwen3-TTS VoiceDesign (voix décrite par un texte, aucun clonage).

Lancer avec le venv vocal de la tour (qwen_tts) :
  HF_HOME=<cache contenant Qwen3-TTS-12Hz-1.7B-VoiceDesign> <venv>/bin/python tools/gen_voice.py [--try N]
Sortie : assets/voice/<id>.wav (mono 44,1 kHz, normalisé, silence rogné). --try N : N variantes dans ~/Downloads/rixe-voice.
"""
import sys
from pathlib import Path

import numpy as np
from loguru import logger
from scipy.io import wavfile
from scipy.signal import resample_poly

OUT = Path(__file__).resolve().parent.parent / "assets" / "voice"
TRY_DIR = Path.home() / "Downloads" / "rixe-voice"
MODEL = "Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign"


def model_path() -> str:
    """Dossier local du modèle (un chemin évite l'appel réseau de transformers, même hors ligne)."""
    import os

    hub = Path(os.environ.get("HF_HOME", Path.home() / ".cache" / "huggingface")) / "hub"
    snaps = sorted((hub / ("models--" + MODEL.replace("/", "--")) / "snapshots").glob("*"))
    return str(snaps[-1]) if snaps else MODEL
VOICE = (
    "Une voix d'annonceur de tournoi de combat, masculine, très grave et rauque, puissante, qui détache chaque "
    "syllabe avec emphase et un brin de menace, comme dans une arène, en français."
)
LINES: dict[str, str] = {
    "decap": "Décapitation !",
    "execution": "Exécution !",
    "headshot": "En pleine tête !",
    "double": "Doublé !",
    "triple": "Triplé !",
    "rampage": "Carnage !",
    "last": "Dernier debout !",
    "round_won": "Manche gagnée !",
    "fight": "Combattez !",
    "flawless": "Intouchable !",
    "boss": "Le boss arrive !",
    "boss_down": "Boss vaincu !",
    "focus": "Ralenti !",
}


def trim(x: np.ndarray, sr: int) -> np.ndarray:
    """Rogne le silence au début et à la fin, puis normalise."""
    env = np.abs(x) > 0.02 * np.abs(x).max()
    idx = np.flatnonzero(env)
    if idx.size == 0:
        return x
    a = max(idx[0] - int(0.01 * sr), 0)
    b = min(idx[-1] + int(0.08 * sr), len(x))
    y = x[a:b]
    return y / max(np.abs(y).max(), 1e-9) * 0.9


def main() -> None:
    import torch
    from qwen_tts import Qwen3TTSModel

    tries = int(sys.argv[sys.argv.index("--try") + 1]) if "--try" in sys.argv else 0
    try:
        model = Qwen3TTSModel.from_pretrained(model_path(), device_map="cuda:0", dtype=torch.bfloat16)
    except Exception as err:
        logger.error(f"chargement du modèle impossible : {err}")
        raise
    out = TRY_DIR if tries else OUT
    out.mkdir(parents=True, exist_ok=True)
    only = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else list(LINES)
    for key, text in {k: v for k, v in LINES.items() if k in only}.items():
        for n in range(max(tries, 1)):
            wavs, sr = model.generate_voice_design(text=text, instruct=VOICE, language="French")
            x = trim(np.asarray(wavs[0], dtype=np.float32), sr)
            x = resample_poly(x, 44100, sr).astype(np.float32)
            name = f"{key}_{n}.wav" if tries else f"{key}.wav"
            wavfile.write(out / name, 44100, (np.clip(x, -1, 1) * 32767).astype(np.int16))
            logger.info(f"{name} ({len(x) / 44100:.2f} s)")


if __name__ == "__main__":
    main()
