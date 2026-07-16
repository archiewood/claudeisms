-- Step 3: word counts from pre-2021 Stack Overflow answers (BigQuery).
--
--   bq query --use_legacy_sql=false --format=csv --max_rows=2000000 \
--     < scripts/03_baseline_stackoverflow.sql > data/baselines/stackoverflow_freq.csv
--
-- Scans ~28.7 GB (~$0.18, inside the 1 TB/month free tier). Dry-run first.
--
-- Word counts from pre-2021 Stack Overflow answers: humans writing
-- explanatory technical prose. Domain-matched baseline for Claude Code.
--
-- Pre-2021 cutoff keeps the baseline free of LLM-generated text.
-- Tokenizer mirrors wordfreq.sql so the two corpora are comparable.
WITH src AS (
    SELECT body
    FROM `bigquery-public-data.stackoverflow.posts_answers`
    WHERE creation_date < '2021-01-01'
      AND body IS NOT NULL
),
cleaned AS (
    SELECT
        -- SO bodies are HTML: drop code blocks first, then inline code, then
        -- links and remaining tags, then decode the entities that matter.
        REGEXP_REPLACE(
          REGEXP_REPLACE(
            REGEXP_REPLACE(
              REGEXP_REPLACE(
                REGEXP_REPLACE(body, r'(?s)<pre>.*?</pre>', ' '),
              r'(?s)<code>.*?</code>', ' '),
            r'https?://[^\s<]+', ' '),
          r'<[^>]*>', ' '),
        r'&[a-z]+;|&#\d+;', ' ') AS txt
    FROM src
),
tok AS (
    SELECT word
    FROM cleaned,
         UNNEST(REGEXP_EXTRACT_ALL(LOWER(txt), r"[a-z][a-z0-9'\-]*")) AS word
),
trimmed AS (
    SELECT RTRIM(LTRIM(word, "-'"), "-'") AS word FROM tok
)
SELECT word, COUNT(*) AS n
FROM trimmed
WHERE LENGTH(word) >= 2
GROUP BY word
HAVING n >= 20          -- keeps the export small; rarer words are noise anyway

UNION ALL
-- Exact corpus size, so rates are not distorted by the n >= 20 cutoff.
SELECT '__TOTAL_TOKENS__', COUNT(*) FROM trimmed WHERE LENGTH(word) >= 2
