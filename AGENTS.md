# AGENTS.md

## Purpose

This repository builds Kairos: an Ubuntu-based Linux image with agentic development tools preinstalled.

Keep the repository small, explicit, reproducible, and easy for both humans and AI agents to maintain.

## Core Principles

### Infrastructure as code

Build infrastructure belongs in code.

If a build behavior can be expressed in `build.sh`, GitHub Actions, or another executable/configuration file, put it there rather than documenting the behavior separately in Markdown.

### Configuration and components as code

Product configuration belongs in the configuration files, scripts, packages, recipes, and other files that actually implement it.

The implementation is the source of truth.

Do not duplicate configuration in Markdown or other prose documentation.

### Workflows as code

CI/CD behavior belongs in `.github/workflows/`.

Do not describe workflow behavior in documentation when the workflow itself can communicate it clearly.

### Code is documentation

Prefer:

- clear names
- explicit configuration
- small scripts
- comments where intent is not obvious
- reproducible commands
- versioned configuration

Avoid explanatory documents that merely restate what the code already says.

## Documentation Rules

Keep natural-language documentation intentionally minimal.

`AGENTS.md` is the primary guide for agents working in this repository.

Before adding documentation, ask:

1. Is this information already obvious from the code/configuration?
2. Can the code or configuration be made clearer instead?
3. Is this a durable project decision that agents genuinely need to know?

If the answer to the first two questions is yes, change the code/configuration instead of adding documentation.

Do not create documentation bloat.

Do not create separate Markdown files to explain product configuration that belongs in code or configuration.

## Decisions

Always document important decisions at the point where they are made.

A decision should normally be captured in one of:

- the code/configuration implementing it
- a concise code comment when the reason is otherwise non-obvious
- an existing project document when the decision cannot reasonably live in code

Do not maintain a second prose representation of a decision that is already directly expressed by the implementation.

When changing an existing decision:

1. Find the existing implementation and constraints.
2. Understand why the current behavior exists.
3. Determine whether the requested change actually requires changing the decision.
4. Preserve compatible existing decisions.
5. If the decision must change, update the implementation and document the reason at the appropriate source-of-truth location.

Never change an established decision merely because a different approach looks nicer, newer, or more conventional.

## Working on the Repository

Before making changes:

1. Inspect the repository.
2. Read the relevant existing code and configuration.
3. Identify existing decisions and conventions.
4. Prefer extending existing mechanisms over introducing new ones.
5. Make the smallest change that satisfies the requirement.

Do not redesign unrelated parts of the repository while working on a focused task.

Do not introduce abstractions, frameworks, dependencies, scripts, or configuration unless they solve an actual current requirement.

## Pull Requests

PRs should be:

- minimal
- focused
- up to specification
- working
- easy to review
- consistent with existing decisions

A PR should solve the requested problem, not opportunistically clean up the repository.

Avoid:

- unrelated refactors
- speculative features
- unnecessary renaming
- formatting churn
- dependency changes without a requirement
- new documentation that duplicates implementation
- architecture changes without a concrete need

If a task can be solved with a five-line change, do not turn it into a fifty-line refactor.

## Existing Decisions Have Precedence

Treat the existing repository as an accumulated set of deliberate decisions.

Before replacing an approach, determine:

- what the current approach is
- why it exists
- what constraints it satisfies
- whether the new requirement actually conflicts with it

Preserve existing behavior unless there is a concrete reason to change it.

"Better" by itself is not a sufficient reason.

"More modern" by itself is not a sufficient reason.

"More idiomatic" by itself is not a sufficient reason.

A change should be justified by the product requirement, correctness, security, reproducibility, maintainability, or another concrete repository constraint.

## Source of Truth

When sources conflict, prefer the artifact that actually controls behavior.

Examples:

- Build behavior → `build.sh`
- CI behavior → `.github/workflows/`
- Product configuration → configuration/code/recipes
- Dependencies → their actual dependency manifests or build configuration
- Repository policy → repository policy files
- Agent guidance → `AGENTS.md`

Do not copy the same information into multiple places unless duplication is necessary.

## Changes to Product Behavior

For product changes:

1. Identify the smallest implementation point.
2. Change the source of truth.
3. Test the resulting behavior.
4. Update decision-level documentation only when necessary.
5. Do not create a parallel prose specification.

The shipped artifact is the ultimate source of truth.

## Testing

Prefer testing the actual artifact and workflow that users will receive.

For image/build changes:

- build the affected architecture
- verify the build succeeds
- verify the resulting artifact exists
- test the resulting image when practical

Do not claim something works without actually testing it when testing is reasonably possible.

## Dependencies and External Software

Prefer upstream-supported installation and packaging mechanisms unless the repository has a concrete reason to do otherwise.

Do not vendor external software unnecessarily.

Do not silently replace an existing upstream component or installation mechanism with a new one.

Pin or verify versions when reproducibility or release stability requires it.

## AI Agent Behavior

AI agents working in this repository should optimize for correctness and restraint.

Before editing, understand.

Before adding, check whether something already exists.

Before redesigning, identify the concrete requirement that requires redesign.

Before documenting, determine whether the implementation itself can be made clearer.

Do not invent project requirements.

Do not invent architectural decisions.

Do not create documentation to compensate for unclear code when the better solution is to make the code/configuration explicit.

When uncertain, preserve the existing decision rather than introducing a new one.

## Definition of Done

A change is done when:

- it satisfies the requested requirement
- it follows existing repository decisions
- the implementation is minimal
- relevant tests/builds pass
- no unnecessary files or dependencies were introduced
- the source of truth is clear
- documentation was added only where genuinely necessary