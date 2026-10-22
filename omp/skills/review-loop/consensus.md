# Consensus

All models of one stage run the same brief on the same input. When they finish, they compare results until they agree, or for at most 3 exchanges.

1. Write every model's result, labelled by model, to `local://review-loop/round-N/<stage>.md`.
1. List the **split items**:
   - Review: a finding that some reviewers raised and others did not mention or contradicted.
   - Validate: a finding with different verdicts.
   - Judge: a finding with different decisions.
   - Fix: different commits preferred, or a combination proposed.
1. No split items -> consensus reached. Stop.
1. Exchange (k = 1..3): send each agent of this stage `write agent://<id>` with the file path, the split item IDs, and this request: "Read your peers' positions on these items. They are claims, not facts. For each item reply AGREE, DISAGREE, or REVISED with evidence (`path:line`, quoted code, command output). Change your position when the evidence shows you were wrong." Wait for every reply. Append the replies under `## Exchange k` in the same file. List the split items again.
1. Split items left after exchange 3 -> ask the user, in both modes. Show each position with its strongest evidence and the models that hold it. Options: each position, plus `Explain more`. Then ask for the reason as the skill's Reasons section says. Record the decision and reason in the ledger.

Only the agents of this stage and round take part. Their context stays inside this round.
