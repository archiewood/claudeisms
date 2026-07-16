-- Step 1: extract prose from local Claude Code transcripts.
--
-- Reads ~/.claude/projects/**/*.jsonl and emits per-speaker word counts plus
-- reusable intermediates. Run from the repo root:
--
--   duckdb -f scripts/01_extract_sessions.sql

SET VARIABLE session_glob = '/Users/archie/.claude/projects/**/*.jsonl';

-- Raw lines as JSON. read_ndjson_objects avoids schema inference across the
-- heterogeneous record types (assistant, user, system, hook, snapshot, ...).
CREATE OR REPLACE TEMP TABLE raw AS
SELECT json
FROM read_ndjson_objects(getvariable('session_glob'), ignore_errors = true);

-- Conversation records only. Sidechain records are subagent traffic: their
-- "user" turns were authored by Claude, not by a human, so they are excluded
-- from both datasets. isMeta records are harness bookkeeping.
CREATE OR REPLACE TEMP TABLE msgs AS
SELECT
    json ->> '$.type'                    AS role,
    json -> '$.message' ->> '$.model'    AS model,
    json ->> '$.sessionId'               AS session_id,
    json ->> '$.cwd'                     AS cwd,
    regexp_extract(
        regexp_replace(json ->> '$.cwd', '^/Users/archie/(Projects/)?', ''),
        '^[^/.]+')                       AS repo,
    (json ->> '$.timestamp')::TIMESTAMP  AS ts,
    json -> '$.message' -> '$.content'   AS content
FROM raw
WHERE json ->> '$.type' IN ('user', 'assistant')
  AND coalesce(json ->> '$.isSidechain', 'false') = 'false'
  AND coalesce(json ->> '$.isMeta', 'false') <> 'true'
  -- This project's own sessions are meta-discussion about word frequency and
  -- run under a caveman-mode hook that distorts the assistant's prose.
  AND (json ->> '$.cwd') NOT LIKE '%/llm-wordfreq%';

-- Content is either a bare string (typed prompts) or an array of blocks.
-- Only text blocks count: tool_use, tool_result and thinking are not prose
-- either party wrote to the other.
CREATE OR REPLACE TEMP TABLE messages AS
WITH blocks AS (
    SELECT role, model, session_id, cwd, repo, ts,
           unnest(json_extract(content, '$[*]')) AS block
    FROM msgs
    WHERE json_type(content) = 'ARRAY'
),
extracted AS (
    SELECT role, model, session_id, cwd, repo, ts, block ->> '$.text' AS text
    FROM blocks
    WHERE block ->> '$.type' = 'text'

    UNION ALL

    SELECT role, model, session_id, cwd, repo, ts, content ->> '$' AS text
    FROM msgs
    WHERE json_type(content) = 'VARCHAR'
),
cleaned AS (
    SELECT role, model, session_id, cwd, repo, ts, text,
           -- Order matters: fenced code, then tags and their payloads, then
           -- bare tags, then URLs/paths, then leftover markup.
           regexp_replace(
             regexp_replace(
               regexp_replace(
                 regexp_replace(
                   regexp_replace(
                     regexp_replace(text,
                       '```.*?```', ' ', 'gs'),                    -- fenced code
                     '<system-reminder>.*?</system-reminder>|<command-name>.*?</command-name>|<command-message>.*?</command-message>|<command-args>.*?</command-args>|<local-command-stdout>.*?</local-command-stdout>|<local-command-stderr>.*?</local-command-stderr>|<task-notification>.*?</task-notification>', ' ', 'gs'),
                   '`[^`]*`', ' ', 'gs'),                          -- inline code
                 'https?://\S+|[~/][\w./-]{4,}', ' ', 'g'),        -- urls, paths
               '<[^>]{1,80}>', ' ', 'g'),                          -- stray tags
             '(?m)^\s*(UserPromptSubmit|SessionStart|PreToolUse|PostToolUse|Stop)[^\n]*hook[^\n]*$', ' ', 'g')
           AS clean
    FROM extracted
    WHERE text IS NOT NULL AND trim(text) <> ''
)
SELECT * FROM cleaned
WHERE trim(clean) <> '';

-- Prose filter. A handful of pasted log dumps (max message: 247K chars vs a
-- 42-char median) otherwise dominate the counts with JSON keys. Filtering per
-- line, not per message, keeps the prose someone wrote around a paste.
CREATE OR REPLACE TEMP TABLE prose AS
WITH split AS (
    SELECT role, model, session_id, cwd, repo, ts,
           trim(unnest(string_split_regex(clean, '\n'))) AS line
    FROM messages
)
SELECT * FROM split
WHERE length(line) BETWEEN 1 AND 400          -- log lines run long
  AND NOT regexp_matches(line, '^[\[\{\}\]]') -- json / array payloads
  AND NOT regexp_matches(line, '^\d{4}-\d{2}-\d{2}') -- timestamped log lines
  AND NOT regexp_matches(line, '"[A-Za-z_]+"\s*:')   -- json key:value
  AND NOT regexp_matches(line, '^(at |\s*File ")')   -- stack frames
  -- Prose is mostly letters and spaces; markup and data are not.
  AND length(regexp_replace(line, '[^A-Za-z '']', '', 'g'))::DOUBLE
      / length(line) > 0.75;

-- Tokenizer keeps internal hyphens and apostrophes, so "load-bearing" and
-- "it's" survive as single tokens and can be matched against wordfreq, which
-- indexes them the same way.
CREATE OR REPLACE TEMP TABLE tokens AS
SELECT * FROM (
    SELECT role, model, session_id, repo, ts,
           trim(unnest(regexp_split_to_array(lower(line), '[^a-z0-9''\-]+')),
                '-''') AS word
    FROM prose
)
WHERE length(word) >= 2
  AND regexp_matches(word, '^[a-z]');      -- must start with a letter
-- NOTE: stopwords are deliberately NOT removed here. Rates must be computed
-- over the same denominator as the baselines (wordfreq probabilities and the
-- Stack Overflow corpus both include stopwords). Filter them at display time.

-- Speaker groups: Opus 4.8, each other Claude model, and the human.
CREATE OR REPLACE TEMP TABLE speaker_tokens AS
SELECT CASE WHEN role = 'user' THEN 'human' ELSE model END AS speaker,
       word, session_id
FROM tokens
WHERE role = 'user' OR model LIKE 'claude-%';

COPY (
    SELECT speaker, word, count(*) AS n,
           count(DISTINCT session_id) AS sessions
    FROM speaker_tokens
    GROUP BY speaker, word ORDER BY speaker, n DESC
) TO 'data/interim/speaker_freq.csv' (HEADER, DELIMITER ',');

-- Vocabulary to look up in the general-English baseline.
COPY (
    SELECT DISTINCT word FROM speaker_tokens
) TO 'data/interim/vocab.csv' (HEADER, DELIMITER ',');

COPY (SELECT * FROM messages) TO 'data/interim/messages.parquet' (FORMAT PARQUET);
COPY (SELECT * FROM tokens)   TO 'data/interim/tokens.parquet'   (FORMAT PARQUET);

-- Corpus sizes per speaker. Small corpora make unstable rate estimates, so
-- these numbers gate how much any comparison can be trusted.
SELECT speaker,
       count(DISTINCT session_id) AS sessions,
       count(*)                   AS total_words,
       count(DISTINCT word)       AS vocab
FROM speaker_tokens GROUP BY speaker ORDER BY total_words DESC;
