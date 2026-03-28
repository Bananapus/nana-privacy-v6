// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {IStealthRegistry} from "../src/interfaces/IStealthRegistry.sol";
import {StealthRegistry} from "../src/StealthRegistry.sol";

contract StealthRegistryTest is Test {
    StealthRegistry registry;

    function setUp() public {
        registry = new StealthRegistry();
    }

    function test_register_storesMetaAddress() public {
        bytes memory metaAddress = abi.encodePacked(
            bytes32(uint256(1)), // spending pub key (compressed)
            bytes32(uint256(2)) // viewing pub key (compressed)
        );

        registry.register(1, metaAddress);

        bytes memory stored = registry.stealthMetaAddressOf(address(this), 1);
        assertEq(keccak256(stored), keccak256(metaAddress));
    }

    function test_register_emitsEvent() public {
        bytes memory metaAddress = hex"aabbccdd";

        vm.expectEmit(true, true, false, true);
        emit IStealthRegistry.StealthMetaAddressSet(address(this), 1, metaAddress);

        registry.register(1, metaAddress);
    }

    function test_stealthMetaAddressOf_returnsEmptyIfNotRegistered() public {
        bytes memory result = registry.stealthMetaAddressOf(makeAddr("unknown"), 1);
        assertEq(result.length, 0);
    }

    function test_register_overwritesPrevious() public {
        registry.register(1, hex"aabb");
        registry.register(1, hex"ccdd");

        bytes memory stored = registry.stealthMetaAddressOf(address(this), 1);
        assertEq(keccak256(stored), keccak256(hex"ccdd"));
    }

    function test_register_differentSchemes() public {
        registry.register(1, hex"aabb");
        registry.register(2, hex"ccdd");

        assertEq(keccak256(registry.stealthMetaAddressOf(address(this), 1)), keccak256(hex"aabb"));
        assertEq(keccak256(registry.stealthMetaAddressOf(address(this), 2)), keccak256(hex"ccdd"));
    }
}
