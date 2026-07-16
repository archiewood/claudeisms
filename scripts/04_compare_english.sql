-- Compare Opus 4.8's word rates against general English, carrying the human's
-- rates from the same conversations as a domain control.
--
-- Run from repo root:  duckdb -f scripts/04_compare_english.sql     (after steps 01 and 02)

CREATE OR REPLACE TEMP TABLE freq AS
SELECT * FROM read_csv('data/interim/speaker_freq.csv', header = true);

CREATE OR REPLACE TEMP TABLE english AS
SELECT * FROM read_csv('data/baselines/english_freq.csv', header = true);

CREATE OR REPLACE TEMP TABLE totals AS
SELECT speaker, sum(n) AS total FROM freq GROUP BY speaker;

-- Rates per million words, one row per word per speaker.
CREATE OR REPLACE TEMP TABLE rates AS
SELECT f.speaker, f.word, f.n, f.sessions,
       f.n * 1000000.0 / t.total AS per_million
FROM freq f JOIN totals t USING (speaker);

CREATE OR REPLACE TEMP TABLE wide AS
SELECT
    coalesce(o.word, h.word) AS word,
    coalesce(o.n, 0)                       AS opus_n,
    coalesce(o.sessions, 0)                AS opus_sessions,
    coalesce(o.per_million, 0)             AS opus_pm,
    coalesce(h.per_million, 0)             AS human_pm,
    coalesce(fa.per_million, 0)            AS fable_pm,
    coalesce(so.per_million, 0)            AS sonnet_pm,
    coalesce(e.per_million, 0)             AS english_pm
FROM (SELECT * FROM rates WHERE speaker = 'claude-opus-4-8') o
FULL JOIN (SELECT * FROM rates WHERE speaker = 'human')             h  USING (word)
LEFT JOIN (SELECT * FROM rates WHERE speaker = 'claude-fable-5')    fa USING (word)
LEFT JOIN (SELECT * FROM rates WHERE speaker = 'claude-sonnet-4-6') so USING (word)
LEFT JOIN english e USING (word);

-- Overuse vs general English. Words absent from the baseline are jargon with
-- no meaningful ratio, so they are split out rather than divided by zero.
COPY (
    SELECT word, opus_n, opus_sessions,
           round(opus_pm, 1)    AS opus_pm,
           round(english_pm, 2) AS english_pm,
           round(opus_pm / english_pm, 1) AS vs_english,
           round(human_pm, 1)   AS human_pm,
           -- >1 means Claude says it more than the human in the same chats,
           -- which is what separates voice from topic.
           CASE WHEN human_pm > 0 THEN round(opus_pm / human_pm, 1) END AS vs_human
    FROM wide
    WHERE opus_n >= 20 AND english_pm > 0
    ORDER BY opus_pm / english_pm DESC
) TO 'outputs/claudeisms_vs_english.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT word, opus_n, opus_sessions, round(opus_pm, 1) AS opus_pm,
           round(human_pm, 1) AS human_pm
    FROM wide
    WHERE opus_n >= 20 AND english_pm = 0
    ORDER BY opus_pm DESC
) TO 'outputs/claude_jargon_not_in_english.csv' (HEADER, DELIMITER ',');

-- Headline: strongest overuse vs English that is NOT just topic, i.e. Claude
-- also outpaces the human in the same conversations.
SELECT word, opus_n AS n, opus_sessions AS sess,
       round(opus_pm, 1)  AS opus_pm,
       round(english_pm, 2) AS eng_pm,
       round(opus_pm / english_pm, 1) AS vs_eng,
       round(human_pm, 1) AS human_pm,
       CASE WHEN human_pm > 0
            THEN round(opus_pm / human_pm, 1) END AS vs_human
FROM wide
WHERE opus_n >= 30 AND english_pm > 0
ORDER BY opus_pm / english_pm DESC
LIMIT 30;
