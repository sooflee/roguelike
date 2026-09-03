# Steam AI Disclosure — current position

**Position: no AI disclosure required.**

## Policy as of 17 January 2026

Valve significantly rewrote Steam's AI disclosure rules. The rewrite narrowed the requirement to
**player-facing content that ships**, and split AI usage into two disclosure categories
(pre-generated assets, and live-generated content). It explicitly **exempts**:

- AI code assistants (GitHub Copilot and equivalents)
- AI used for concept-art ideation where the output does **not** ship
- AI-powered developer efficiency and debugging tooling

Games shipping *live* AI content additionally need guardrails and a player reporting path.

## How this project sits against it

| Usage | Ships to players? | Disclosure |
|---|---|---|
| AI for concept boards, silhouettes, colour studies | No — reference only | Not required |
| AI code assistance during development | No | Exempt |
| Hand-drawn pixel art (all shipped sprites) | Yes | Not AI |
| Licensed / CC0 music and SFX | Yes | Not AI |
| Live generative content at runtime | None | N/A |

See `docs/ART_BIBLE.md` §5 for the binding art policy.

## Maintenance

If the art or audio pipeline ever ships AI-generated content — including an AI-assisted pixel tool
such as PixelLab or Scenario, or AI-generated music — this file and the Steam store page
disclosure must be updated **in the same commit as the first such asset**.

Re-verify this policy before the store page goes live; Valve has revised it more than once.

Sources:
- https://www.videogameschronicle.com/news/valve-has-significantly-rewritten-steams-rules-for-how-developers-much-disclose-ai-use/
- https://www.strayspark.studio/blog/steam-ai-disclosure-rules-2026-indie-developer-guide
