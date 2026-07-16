-- Opus 4.8 vs pre-2021 Stack Overflow answers: domain-matched human baseline.
--
-- Method: log-odds ratio with an informative Dirichlet prior (Monroe, Colaresi
-- & Quinn 2008), the standard for "which words distinguish corpus A from B".
-- Raw rate ratios explode on rare words; this shrinks them toward the prior
-- and reports a z-score, so frequent-and-distinctive beats rare-and-lucky.
--
-- Run from repo root:  duckdb -f scripts/05_compare_stackoverflow.sql

CREATE OR REPLACE TEMP TABLE so_raw AS
SELECT * FROM read_csv('data/baselines/stackoverflow_freq.csv', header = true);

CREATE OR REPLACE TEMP VIEW so AS
SELECT word, n FROM so_raw WHERE word <> '__TOTAL_TOKENS__';

CREATE OR REPLACE TEMP TABLE freq AS
SELECT * FROM read_csv('data/interim/speaker_freq.csv', header = true);

CREATE OR REPLACE TEMP TABLE eng AS
SELECT * FROM read_csv('data/baselines/english_freq.csv', header = true);

CREATE OR REPLACE TEMP TABLE stop AS
SELECT unnest([
    'the','a','an','and','or','but','if','then','else','when','while','of','to',
    'in','on','at','by','for','with','from','into','over','after','before',
    'is','are','was','were','be','been','being','am','do','does','did','done',
    'have','has','had','having','can','could','will','would','shall','should',
    'may','might','must','it','its','this','that','these','those','there','here',
    'i','you','he','she','they','we','me','him','her','them','us','my','your',
    'his','their','our','not','no','nor','so','than','too','very','as','about',
    'all','any','both','each','few','more','most','other','some','such','which',
    'who','what','where','why','how','because','until','s','t','re','ve','ll','d'
]) AS word;

-- Corpus totals. Both sides count every token, stopwords included, so the
-- rates are comparable; stopwords are filtered only for display.
CREATE OR REPLACE TEMP TABLE consts AS
SELECT
    (SELECT sum(n) FROM freq WHERE speaker = 'claude-opus-4-8')   AS n_opus,
    (SELECT n FROM so_raw WHERE word = '__TOTAL_TOKENS__')        AS n_so,
    1000.0                                                        AS a0;

CREATE OR REPLACE TEMP TABLE joined AS
SELECT
    coalesce(o.word, s.word)  AS word,
    coalesce(o.n, 0)          AS y_opus,
    coalesce(o.sessions, 0)   AS sessions,
    coalesce(s.n, 0)          AS y_so
FROM (SELECT word, n, sessions FROM freq WHERE speaker = 'claude-opus-4-8') o
FULL JOIN so s USING (word);

CREATE OR REPLACE TEMP TABLE scored AS
SELECT j.word, j.y_opus, j.sessions, j.y_so,
       j.y_opus * 1e6 / c.n_opus AS opus_pm,
       j.y_so   * 1e6 / c.n_so   AS so_pm,
       -- Prior mass for this word, from the pooled background distribution.
       -- The +0.5 floor matters: Stack Overflow outweighs Opus ~9000:1, so a
       -- word absent from SO would otherwise get ~zero prior, exploding its
       -- variance and driving z toward 0 — penalising precisely the words no
       -- human ever writes, which are the ones we are looking for.
       c.a0 * (j.y_opus + j.y_so)::DOUBLE / (c.n_opus + c.n_so) + 0.5 AS alpha,
       c.n_opus, c.n_so, c.a0
FROM joined j CROSS JOIN consts c;

CREATE OR REPLACE TEMP TABLE logodds AS
SELECT *,
       ln((y_opus + alpha) / (n_opus + a0 - y_opus - alpha))
     - ln((y_so   + alpha) / (n_so   + a0 - y_so   - alpha))  AS delta,
       sqrt(1.0 / (y_opus + alpha) + 1.0 / (y_so + alpha))    AS sigma
FROM scored;

CREATE OR REPLACE TEMP TABLE final AS
SELECT word, y_opus, sessions, y_so,
       round(opus_pm, 1) AS opus_pm,
       round(so_pm, 2)   AS so_pm,
       round(delta / sigma, 1) AS z,
       CASE WHEN so_pm > 0 THEN round(opus_pm / so_pm, 1) END AS vs_so
FROM logodds;

COPY (SELECT * FROM final WHERE y_opus >= 10 ORDER BY z DESC)
  TO 'outputs/claudeisms_vs_stackoverflow.csv' (HEADER, DELIMITER ',');

-- Headline: content words Opus uses far more than humans writing technical
-- prose. Requires presence across sessions, so one ranty session cannot win.
SELECT word, y_opus AS n, sessions AS sess, opus_pm, so_pm, vs_so, z
FROM final
WHERE y_opus >= 20 AND sessions >= 5
  AND word NOT IN (SELECT word FROM stop)
ORDER BY z DESC LIMIT 30;
