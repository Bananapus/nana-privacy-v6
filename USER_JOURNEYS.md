# User Journeys

## Who This Repo Serves

- recipients who want stealth-address discovery for Juicebox payments
- projects adding privacy-oriented hooks without forking the core protocol
- teams combining recipient privacy here with payer privacy from external relayers or shielded systems

## Journey 1: Publish A Stealth Meta-Address

**Starting state:** a recipient wants others to pay them privately without first revealing the final destination address.

**Success:** the recipient has a discoverable stealth meta-address in `StealthRegistry`.

**Flow**
1. Register the stealth meta-address in `StealthRegistry`.
2. Share only the metadata needed for senders or relayers to derive destination stealth addresses.
3. Keep the registry entry updated if the recipient rotates stealth keys or metadata format.

## Journey 2: Emit A Stealth Announcement During A Normal Payment

**Starting state:** a project payment is happening and the payer includes the privacy metadata needed for stealth discovery.

**Success:** the payment still follows ordinary Juicebox accounting while also emitting a discoverable stealth announcement.

**Flow**
1. Route the payment through a project that has `StealthAnnouncementHook` installed.
2. Provide the privacy metadata expected by the hook.
3. The hook emits the announcement through `ERC5564Announcer` while the underlying Juicebox payment proceeds as normal.

## Journey 3: Add Amount Privacy As A Product Pattern

**Starting state:** the product wants some amount obfuscation on top of recipient privacy.

**Success:** amount bands become less revealing because the project uses fixed-denomination 721 tiers or similar bucketed payment patterns.

**Flow**
1. Pair this repo's stealth announcement flow with a fixed-price tiering scheme in a 721 hook project.
2. Encourage users into denomination buckets rather than arbitrary payment amounts.
3. Treat this as a product pattern built from multiple repos, not as a feature fully implemented by this package alone.

## Journey 4: Compose With External Payer-Privacy Infrastructure

**Starting state:** the team wants sender privacy in addition to recipient privacy.

**Success:** this repo handles the recipient side while an external relay or shielded execution layer handles the payer side.

**Flow**
1. Keep payer privacy infrastructure outside this repo.
2. Use this repo for stealth metadata publication and announcement emission only.
3. Audit the seam between the external relay and the Juicebox payment metadata carefully.

## Hand-Offs

- Use [nana-721-hook-v6](../nana-721-hook-v6/USER_JOURNEYS.md) when the amount-privacy design depends on fixed-denomination NFT tiers.
- Use [nana-core-v6](../nana-core-v6/USER_JOURNEYS.md) for the underlying payment path once privacy metadata is no longer the question.
