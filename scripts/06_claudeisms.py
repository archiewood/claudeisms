"""Rank Claude-isms, minus words specific to this work.

Selection is by exclusion, not by a cleverness filter: everything Opus said
often enough is a claude-ism until data/exclude.txt rules it out. Iterate by
adding words to that file and re-running.

Emits outputs/claudeisms.csv, sorted by overuse vs pre-2021 Stack Overflow.

Run from repo root:  python3 scripts/06_claudeisms.py
"""
import collections
import csv

MIN_USES = 20      # below this, rates are too noisy to rank
MIN_SESSIONS = 5   # spread, so one ranty session cannot manufacture a tell
MIN_RATIO = 20     # x more often than humans writing technical prose


def load_exclude(path="data/exclude.txt"):
    """Words to drop before ranking: vendors, product names, local jargon.

    Not published — the list is specific to one person's work and reads as a
    map of their stack. Write your own; the ranking is meaningless without one,
    since anything your corpus discusses and Stack Overflow does not will
    otherwise dominate the top.
    """
    try:
        f = open(path)
    except FileNotFoundError:
        raise SystemExit(
            f"{path} not found.\n\n"
            "Create it: one word per line, '#' for comments. It should hold the\n"
            "product names, vendors and in-house jargon specific to your work --\n"
            "otherwise they take every top slot, because pre-2021 Stack Overflow\n"
            "has never heard of them and the ratio explodes."
        )
    with f:
        words = set()
        for line in f:
            line = line.split("#")[0].strip()
            if line:
                words.add(line.lower())
    return words


def main():
    exclude = load_exclude()

    speakers = collections.defaultdict(dict)
    with open("data/interim/speaker_freq.csv") as f:
        for r in csv.DictReader(f):
            speakers[r["speaker"]][r["word"]] = (int(r["n"]), int(r["sessions"]))

    so = {}
    with open("data/baselines/stackoverflow_freq.csv") as f:
        for r in csv.DictReader(f):
            so[r["word"]] = int(r["n"])
    n_so = so.pop("__TOTAL_TOKENS__")

    english = {}
    with open("data/baselines/english_freq.csv") as f:
        for r in csv.DictReader(f):
            english[r["word"]] = float(r["per_million"])

    opus = speakers["claude-opus-4-8"]
    human = speakers["human"]
    n_opus = sum(v[0] for v in opus.values())
    n_human = sum(v[0] for v in human.values())

    # Words under Stack Overflow's n>=20 export cutoff are rarer than this, so
    # their ratio is a lower bound rather than a point estimate.
    so_floor = 20e6 / n_so

    rows = []
    for word, (n, sessions) in opus.items():
        if n < MIN_USES or sessions < MIN_SESSIONS or word in exclude:
            continue
        opus_pm = n * 1e6 / n_opus
        so_pm = so.get(word, 0) * 1e6 / n_so
        ratio = opus_pm / so_pm if so_pm else opus_pm / so_floor
        if ratio < MIN_RATIO:
            continue
        rows.append({
            "word": word,
            "n": n,
            "sessions": sessions,
            "claude_pm": round(opus_pm),
            "you_pm": round(human.get(word, (0, 0))[0] * 1e6 / n_human),
            "so_pm": round(so_pm, 3),
            "eng_pm": round(english.get(word, 0.0), 2),
            "vs_so": round(ratio, 1),
            "so_is_floor": "yes" if not so_pm else "",
        })

    rows.sort(key=lambda r: -r["vs_so"])
    with open("outputs/claudeisms.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    print(f"{len(rows)} claude-isms at >={MIN_RATIO}x "
          f"({len(exclude)} words excluded) -> outputs/claudeisms.csv")


if __name__ == "__main__":
    main()
