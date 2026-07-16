# A List of Claudeisms

> "load-bearing"
> > Claude Code - always

I've been using Claude code for several months now. I probably say more to Claude than any human (aside: this is bleak). This also means Claude says a lot back to me.

Claude really annoys me (and [many others](https://news.ycombinator.com/item?id=48905248)) with its word choices sometimes. It reuses a load of words at too high a frequency. I wanted to quantify this somehow as an exercise in catharsis.

## Data: My Claude Code Chats

Claude code saves session text locally so I already have the dataset of my experience. I decided to run pretty simple word frequency analysis to see what the biggest claudeisms were.

The transcripts are in `~/.claude/projects/**/*.jsonl` — 175 files, 140MB, about 5 weeks.

Some stuff I filtered out:
- Only Opus 4.7/4.8 sessions. Haiku etc has different word usage.
- Only agent response messages that get sent to me (not tool calls or subagents as I don't have to read those)

## Comparing Claude to humans

### vs me

First I just looked at the top words in the messages that I sent to Claude, I am a human after all so I thought this would be a good baseline.

Wrong - I paste a lot into Claude code, and that text is often logs / machine generated content.

My top words were things like `requestid`, `sessionid`, `organizationid` — ie the JSON keys from log dumps I'd pasted. 

### vs general internet

Next, I downloaded the `wordfreq` dataset, which is a blend of web content like Wikipedia, Reddit, books, subtitles, and news. The dataset is pre-2021, so it doesn't contain LLM outputs.

I started with a raw comparison on the multiple of word frequency per million, but that ended up being dominated by the terms related to coding and programming like `eslint` `yaml` `serializer` etc.

### vs stack overflow

So I found a comparison against humans writing about code. BigQuery has 1.72 billion words in a public dataset of Stack Overflow comments from 2008-2020.

I ranked by word frequency ratio, then removed an exclude list of words specific to my own work which mainly contains proper nouns for our names, products and tools we use

Full ranking, 144 words at 20x or above, is in [`outputs/claudeisms.csv`](outputs/claudeisms.csv). These are the top 12

| word | claude /M | Stack Overflow Comments /M | ratio |
|---|---|---|---|
| `load-bearing` | 87 | <0.012 | **>7,500x*** |
| `gating` | 123 | 0.16 | **762x** |
| `dedup` | 102 | 0.16 | **649x** |
| `decisive` | 108 | 0.17 | **639x** |
| `verdict` | 200 | 0.32 | **633x** |
| `scaffolds` | 118 | 0.21 | **572x** |
| `settles` | 143 | 0.33 | **435x** |
| `handoff` | 113 | 0.31 | **360x** |
| `prod` | 2,516 | 9.14 | **275x** |
| `pr` | 2,552 | 9.34 | **273x** |
| `gated` | 133 | 0.51 | **263x** |
| `genuinely` | 328 | 1.46 | **224x** |

\* Below Stack Overflow cutoff for words so this is a lower bound.

A lot of hits in there for claudeisms!



Some other interesting other ones I cherry picked. These are all above 20x frequency vs the Stack Overflow dataset.  

| word | claude /M | Stack Overflow Comments /M | ratio |
|---|---|---|---|
| `scaffolded` | 87 | 0.42 | 205x |
| `blocker` | 241 | 1.30 | 185x |
| `pre-existing` | 559 | 3.04 | 184x |
| `drift` | 323 | 1.76 | 184x |
| `surfaced` | 77 | 0.43 | 181x |
| `divergence` | 123 | 0.74 | 166x |
| `round-trip` | 307 | 1.89 | 162x |
| `flips` | 205 | 1.47 | 140x |
| `stale` | 892 | 6.57 | 136x |
| `wiring` | 384 | 2.86 | 134x |
| `mint` | 174 | 1.49 | 117x |
| `end-to-end` | 225 | 2.06 | 110x |
| `scaffold` | 282 | 2.75 | 102x |
| `landed` | 159 | 1.58 | 100x |
| `framing` | 108 | 1.27 | 84x |
| `surfaces` | 164 | 2.11 | 78x |
| `harness` | 133 | 1.78 | 75x |
| `parity` | 179 | 2.45 | 73x |
| `mirrors` | 138 | 2.12 | 65x |
| `seam` | 123 | 1.97 | 62x |
| `genuine` | 128 | 2.18 | 59x |
| `wired` | 236 | 4.02 | 59x |
| `authoritative` | 123 | 2.14 | 58x |
| `floor` | 369 | 7.18 | 51x |
| `probe` | 159 | 3.20 | 50x |
| `cleanly` | 354 | 7.21 | 49x |
| `kills` | 184 | 4.08 | 45x |
| `idempotent` | 128 | 3.11 | 41x |
| `bare` | 528 | 13 | 41x |
| `guard` | 553 | 14 | 40x |
| `gap` | 441 | 12 | 36x |
| `silently` | 415 | 12 | 36x |
| `proves` | 113 | 3.29 | 34x |
| `truth` | 313 | 9.21 | 34x |
| `verified` | 471 | 15 | 32x |
| `verbatim` | 128 | 4.11 | 31x |
| `mirror` | 231 | 7.92 | 29x |
| `canonical` | 292 | 11 | 27x |
| `wins` | 154 | 5.83 | 26x |
| `transient` | 174 | 6.70 | 26x |
| `clean` | 2,537 | 103 | 24x |
| `fallback` | 323 | 14 | 23x |
| `honest` | 225 | 10 | 22x |
| `surface` | 374 | 18 | 21x |

So there's my list! An _authoritative_ list of Claudeisms. 


### Caveats / Notes
- All of this analysis was done with Claude code. I did not check the code, just vibed it, and fixed it along the way until the results felt kind of right.
- Obviously this is all highly skewed to stuff I use and do with Claude code.
- I installed `caveman` at some point which will have influenced the word frequency.
- Apparently `load-bearing` is in the Claude code system prompt. It says: "give brief updates when you find something load-bearing"
- I didnt stem the words eg merge `scaffold` and `scaffolds` or `gating` and `gated`.