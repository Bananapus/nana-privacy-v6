# User Journeys

## Who This Repo Serves

- recipients who want stealth-address discovery and announcement support
- projects adding privacy-oriented helper patterns without modifying core protocol contracts
- integrators reasoning about anonymity-set, metadata, and offchain relay tradeoffs

## Journey 1: Publish A Stealth Meta-Address

**Starting state:** a recipient wants others to be able to derive stealth payment addresses for them.

**Success:** payers can look up the recipient's stealth meta-address and compute a one-off stealth destination offchain.

**Flow**
1. The recipient chooses the stealth scheme they want to use.
2. They register their meta-address in `StealthRegistry`.
3. Payers or relays read that meta-address and derive a stealth recipient address offchain before payment.

## Journey 2: Emit A Stealth Announcement During A Normal Payment

**Starting state:** the target project uses `StealthAnnouncementHook`, and the payer metadata includes the expected stealth payload.

**Success:** the underlying Juicebox payment works normally, and an EIP-5564-style announcement is emitted for the beneficiary.

**Flow**
1. The payer or relay computes a stealth address for the recipient offchain.
2. The payment is sent through the normal Juicebox payment path with stealth metadata attached.
3. After the payment is recorded, `StealthAnnouncementHook` checks the metadata.
4. If stealth metadata is present, it calls `ERC5564Announcer.announce(...)`.
5. Wallets or scanners watching for announcements can detect that stealth-address payment.

**Important limitation:** this hook announces recipient privacy data after a payment. It does not itself hide the fact that a payment happened, and it does not provide payer privacy.

## Journey 3: Add Amount Privacy As A Product Pattern

**Starting state:** you are designing a project and want better amount ambiguity without inventing a new protocol.

**Success:** the project uses fixed-denomination 721 tiers or similar bounded-value buckets to reduce amount distinguishability.

**Flow**
1. Define fixed-price participation tiers in the product layer.
2. Pair those tiers with stealth-address flows when recipient privacy also matters.
3. If payer privacy matters, route the call through separate shielded infrastructure because this repo does not provide that layer.

**Hard truth:** this repo is a privacy helper package. It improves specific parts of the privacy story, but it is not a complete private payments or private cash-out system by itself.
