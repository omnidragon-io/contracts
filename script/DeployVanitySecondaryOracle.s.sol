// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/oracles/OmniDragonSecondaryOracle.sol";

contract DeployVanitySecondaryOracle is Script {
    address constant OMNI_CREATE2_FACTORY = 0xAA28020DDA6b954D16208eccF873D79AC6533833;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        address registry = vm.envAddress("REGISTRY");
        address delegate = vm.envOr("DELEGATE", vm.addr(pk));
        address primary = vm.envAddress("PRIMARY_ORACLE");
        uint32 primaryEid = uint32(vm.envUint("PRIMARY_EID"));
        bytes32 salt = vm.envBytes32("SALT_SECONDARY");

        bytes memory initCode = abi.encodePacked(
            type(OmniDragonSecondaryOracle).creationCode,
            abi.encode(registry, delegate, primary, primaryEid)
        );

        address expected = vm.computeCreate2Address(
            salt,
            keccak256(initCode),
            OMNI_CREATE2_FACTORY
        );

        console.log("Deploying SecondaryOracle vanity...");
        console.log("  Registry:", registry);
        console.log("  Delegate:", delegate);
        console.log("  Primary:", primary);
        console.log("  PrimaryEID:", primaryEid);
        console.log("  Salt:", vm.toString(salt));
        console.log("  Expected:", expected);

        if (expected.code.length == 0) {
            (bool ok, ) = OMNI_CREATE2_FACTORY.call(
                abi.encodeWithSignature("deploy(bytes,bytes32,string)", initCode, salt, "OmniDragonSecondaryOracle")
            );
            require(ok, "SecondaryOracle deploy failed");
        } else {
            console.log("SecondaryOracle exists:", expected);
        }
        console.log("SecondaryOracle:", expected);

        vm.stopBroadcast();
    }
}


