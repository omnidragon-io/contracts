// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/oracles/OmniDragonPrimaryOracle.sol";
import "../contracts/interfaces/config/IOmniDragonRegistry.sol";

contract DeployVanityPrimaryOracle is Script {
    address constant OMNI_CREATE2_FACTORY = 0xAA28020DDA6b954D16208eccF873D79AC6533833;

    // Registry and DRAGON token on Sonic
    address constant REGISTRY = 0x6949936442425f4137807Ac5d269e6Ef66d50777;
    address constant DRAGON = 0x69821FFA2312253209FdabB3D84f034B697E7777;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        bytes32 salt = vm.envBytes32("SALT_PRIMARY");
        address owner = vm.envOr("OWNER", vm.addr(pk));
        address delegate = vm.envOr("DELEGATE", owner);

        require(block.chainid == 146, "Deploy on Sonic only");
        bytes memory initCode = abi.encodePacked(
            type(OmniDragonPrimaryOracle).creationCode,
            abi.encode("NATIVE", "USD", owner, REGISTRY, DRAGON, delegate)
        );

        address expected = vm.computeCreate2Address(
            salt,
            keccak256(initCode),
            OMNI_CREATE2_FACTORY
        );

        console.log("Deploying PrimaryOracle vanity...");
        console.log("  Owner:", owner);
        console.log("  Delegate:", delegate);
        console.log("  Salt:", vm.toString(salt));
        console.log("  Expected:", expected);

        if (expected.code.length == 0) {
            (bool ok, ) = OMNI_CREATE2_FACTORY.call(
                abi.encodeWithSignature("deploy(bytes,bytes32,string)", initCode, salt, "OmniDragonPrimaryOracle")
            );
            require(ok, "PrimaryOracle deploy failed");
        } else {
            console.log("PrimaryOracle exists:", expected);
        }
        console.log("PrimaryOracle:", expected);

        vm.stopBroadcast();
    }
}


