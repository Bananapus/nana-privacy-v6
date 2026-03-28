// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IJBTerminal} from "@bananapus/core-v6/src/interfaces/IJBTerminal.sol";
import {IERC5564Announcer} from "./interfaces/IERC5564Announcer.sol";

/// @notice Parameters for a relayed payment with a stealth announcement.
/// @custom:member terminal The terminal to pay.
/// @custom:member projectId The project to pay.
/// @custom:member token The payment token (use NATIVE_TOKEN for ETH).
/// @custom:member amount The payment amount.
/// @custom:member beneficiary The stealth address that receives tokens/NFTs.
/// @custom:member minReturnedTokens Minimum tokens to receive.
/// @custom:member memo An optional memo.
/// @custom:member metadata Payment metadata (tier IDs, etc.).
/// @custom:member schemeId The stealth address scheme (1 = secp256k1 per EIP-5564).
/// @custom:member ephemeralPubKey The ephemeral public key for recipient scanning.
/// @custom:member announcementMetadata View tag and any additional announcement data.
struct RelayWithAnnouncementParams {
    address terminal;
    uint256 projectId;
    address token;
    uint256 amount;
    address beneficiary;
    uint256 minReturnedTokens;
    string memo;
    bytes metadata;
    uint256 schemeId;
    bytes ephemeralPubKey;
    bytes announcementMetadata;
}

/// @notice Forwards payments to any JBMultiTerminal, hiding the real payer's address.
/// @dev The terminal sees `msg.sender = PaymentRelayPool`, so the `Pay` event logs
/// `payer = PaymentRelayPool` for ALL users of the pool. The real payer is never revealed on-chain.
///
/// Also supports atomic announcement: emit EIP-5564 announcement + pay in one transaction.
/// This is the recommended entry point for revnets (which have no data hook extension point).
contract PaymentRelayPool {
    //************************************************************//
    // -------------------- custom errors ----------------------- //
    //************************************************************//

    /// @notice Thrown when msg.value doesn't match the payment amount for native token payments.
    error PaymentRelayPool_MsgValueMismatch();

    //************************************************************//
    // --------------- public stored properties ------------------ //
    //************************************************************//

    /// @notice The EIP-5564 announcer for stealth address announcements.
    IERC5564Announcer public immutable ANNOUNCER;

    //************************************************************//
    // ------------------------ constants ------------------------ //
    //************************************************************//

    address constant NATIVE_TOKEN = address(0x000000000000000000000000000000000000EEEe);

    //************************************************************//
    // ------------------------ constructor ---------------------- //
    //************************************************************//

    constructor(IERC5564Announcer announcer) {
        ANNOUNCER = announcer;
    }

    //************************************************************//
    // --------------------- external fns ----------------------- //
    //************************************************************//

    /// @notice Relay a payment to any terminal. Payer identity = this contract.
    /// @param terminal The terminal to pay.
    /// @param projectId The project to pay.
    /// @param token The payment token (use NATIVE_TOKEN for ETH).
    /// @param amount The payment amount.
    /// @param beneficiary The address that receives tokens/NFTs.
    /// @param minReturnedTokens Minimum tokens to receive.
    /// @param memo An optional memo.
    /// @param metadata Payment metadata (tier IDs, etc.).
    /// @return beneficiaryTokenCount The number of tokens minted to the beneficiary.
    function relayPayment(
        address terminal,
        uint256 projectId,
        address token,
        uint256 amount,
        address beneficiary,
        uint256 minReturnedTokens,
        string calldata memo,
        bytes calldata metadata
    )
        external
        payable
        returns (uint256 beneficiaryTokenCount)
    {
        if (token == NATIVE_TOKEN && msg.value != amount) revert PaymentRelayPool_MsgValueMismatch();

        return IJBTerminal(terminal).pay{value: msg.value}(
            projectId, token, amount, beneficiary, minReturnedTokens, memo, metadata
        );
    }

    /// @notice Relay a payment AND emit an EIP-5564 announcement in one transaction.
    /// @dev Use this for maximum privacy: payer hidden (relay pool) + recipient hidden (stealth) + announced.
    /// @param params The payment and announcement parameters.
    /// @return beneficiaryTokenCount The number of tokens minted to the beneficiary.
    function relayPaymentWithAnnouncement(RelayWithAnnouncementParams calldata params)
        external
        payable
        returns (uint256 beneficiaryTokenCount)
    {
        if (params.token == NATIVE_TOKEN && msg.value != params.amount) {
            revert PaymentRelayPool_MsgValueMismatch();
        }

        // Announce first (event only, no state change).
        ANNOUNCER.announce(params.schemeId, params.beneficiary, params.ephemeralPubKey, params.announcementMetadata);

        return IJBTerminal(params.terminal).pay{value: msg.value}(
            params.projectId,
            params.token,
            params.amount,
            params.beneficiary,
            params.minReturnedTokens,
            params.memo,
            params.metadata
        );
    }
}
