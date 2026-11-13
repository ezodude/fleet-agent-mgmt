# Fast but small: autonomy with guardrails

The framework shared/docs/ic-flow.md is built on, kept here so the reference
reads without leaving the repo. The text is as received; nothing added.

 Balancing high autonomy with high quality in a fast-paced startup is a classic engineering challenge. When rework is expensive, you cannot rely on "move fast and break things." Instead, you must shift your focus from controlling the work to controlling the context and creating guardrails.

Here is a framework designed to foster autonomy while ensuring high quality in a high-novelty environment.

## 1. Build "Guardrails, Not Gates"
Gates slow people down and require your constant approval. Guardrails allow engineers to run as fast as they want, safely.

- Define "One-Way" vs. "Two-Way" Decisions:
- Two-way decisions (reversible, low-cost rework) require zero manager approval. Let engineers experiment and fail here.
- One-way decisions (core architecture, database schemas, third-party vendor lock-in) require a collective review.

- Automate Quality Standards: Remove human bias from code quality. Implement strict, automated linting, comprehensive CI/CD pipelines, and robust automated testing (unit and integration) before code can even be reviewed. If the pipeline passes, a baseline of quality is guaranteed.
- Living Style Guides & Architecture RFCs: For new thinking, use a lightweight RFC (Request for Comments)process. Anyone can propose a solution, but the core engineering team must review it asynchronously. This aligns the team on technical direction without halting momentum.
## 2. Implement the "Definition of Done" (DoD)
Autonomy requires a shared definition of success. If engineers don't know what "good" looks like, they will default to their own interpretations.

Create a strict, team-wide Definition of Done that every feature must meet before it hits production. This shifts the responsibility of quality from you to the engineer. A strong DoD for a startup includes:

- Automated test coverage meets the agreed threshold.
- Peer review is completed by at least one senior/peer engineer.
- Observability (logging, alerting, metrics) is instrumented.
- Documentation (API contracts, system architecture) is updated.
## 3. Move from Code Reviews to Architecture Reviews
In a fast startup solving hard problems, waiting until the Pull Request (PR) to review code is too late—that is where expensive rework happens.

- Shift Left: Encourage engineers to sketch out their design, data models, and edge cases on a whiteboard or a 1-page document before writing a single line of code.
- The 10% Rule: Review their approach at the 10% mark of the project. Once the direction is validated, step back and let them execute autonomously.
- PRs as Context Sharing: Treat final code reviews as a tool for knowledge sharing and catching minor bugs, not for questioning fundamental architectural choices.
## 4. Align on the "Why" and "What," Delegate the "How"
Autonomy thrives when engineers have deep context. If you only give them tasks, they will build fragile solutions because they don't understand the bigger picture.

- Provide Extreme Business Context: Explain the customer pain point, the business goal, and why this hard problem needs solving right now.
- Define Clear Constraints: Instead of telling them how to build it, give them the boundaries. For example: "We need this service to handle 10k requests per minute, cost less than $X00/month, and be live in three weeks. How we achieve that is up to you."
## 5. Cultivate a Culture of Psychological Safety & High Accountability
If rework is costly, engineers might become paralysed by fear of making mistakes, slowing down your startup entirely.

- Blameless Post-Mortems: When things inevitably break, focus entirely on the system failure, not the human failure. Ask: "What guardrail was missing that allowed this to happen?"
- Peer Accountability: Foster an environment where the team holds each other to high standards. As a manager, you shouldn't be the only one rejecting poor code or sloppy architecture; the team should take pride in protecting the codebase themselves.
