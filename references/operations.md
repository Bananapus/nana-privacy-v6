# Privacy Operations

## Change Checklist

- If you edit the hook, verify the corresponding metadata expectations still line up with announcer and registry behavior.
- If a user expects full payment privacy, clarify that payer privacy is out of scope unless a separate shielded path is used.
- If you edit denomination assumptions, verify the privacy model still makes sense in the downstream collection or payment flow.

## Common Failure Modes

- This repo is credited with guarantees it does not provide.
- A privacy-mode integration forgets that announcement metadata remains observable.
