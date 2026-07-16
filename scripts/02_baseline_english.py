"""Look up each corpus word in a general-English frequency baseline.

wordfreq's 'large' English list blends web text, books, subtitles, news and
Wikipedia, so it stands in for "how often people write this word in general".
Emits english_freq.csv: word, freq (probability), per_million.

Run from repo root:  python3 scripts/02_baseline_english.py
"""
import csv

from wordfreq import word_frequency

with open("data/interim/vocab.csv") as f:
    vocab = [row["word"] for row in csv.DictReader(f)]

with open("data/baselines/english_freq.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["word", "per_million"])
    hits = 0
    for word in vocab:
        # wordfreq indexes hyphenated and apostrophe forms directly.
        freq = word_frequency(word, "en", wordlist="large")
        if freq > 0:
            hits += 1
        w.writerow([word, f"{freq * 1e6:.6f}"])

print(f"{len(vocab)} words looked up, {hits} found in general English "
      f"({hits / len(vocab):.1%})")
