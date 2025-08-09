// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/oracles/OmniDragonPriceOracle.sol";
import "../contracts/core/oracles/OmniDragonPrimaryOracle.sol";
import "../contracts/interfaces/config/IOmniDragonRegistry.sol";
import "../contracts/core/tokens/veDRAGON.sol";
import "../contracts/core/lottery/OmniDragonJackpotVault.sol";
// import "../contracts/core/tokens/redDRAGON.sol"; // not used in this script

contract DeployVanityCore is Script {
    // Omni create2 factory
    address constant OMNI_CREATE2_FACTORY = 0xAA28020DDA6b954D16208eccF873D79AC6533833;

    // Vanity pattern: 0x69 ... 777
    // NOTE: Replace these salts with those found by the vanity generator for each contract
    bytes32 constant SALT_PRICE_ORACLE = 0x000000000000000000000000000000000000000000000000000000017488e31c; // 0x69…27777
    bytes32 constant SALT_PRIMARY_ORACLE = 0x0000000000000000000000000000000000000000000000000000000ba43fb01f; // 0x69…e777
    // Updated salt for inlined veDRAGON vanity address 0x692f8bc5e1c0e90611d2807777bf079e2e401777
    bytes32 constant SALT_VEDRAGON = 0x000000000000000000000000000000000000000000000000000000017488bef4;
    // OmniDragonJackpotVault vanity: 0x69352f6940529e00ccc6669606721b07bc659777
    bytes32 constant SALT_VAULT = 0x0000000000000000000000000000000000000000000000000000000d4750ea28;
    bytes32 constant SALT_REDDRAGON = 0x0000000000000000000000000000000000000000000000000000000000006973;

    // Common constants
    address constant REGISTRY = 0x6949936442425f4137807Ac5d269e6Ef66d50777;
    address constant DRAGON = 0x69821FFA2312253209FdabB3D84f034B697E7777;
    address constant DELEGATE = 0xDDd0050d1E084dFc72d5d06447Cc10bcD3fEF60F;
    // Sonic redDRAGON (ERC-4626) vault address (used for veDRAGON initialization on Sonic)
    address constant REDDRAGON_SONIC = 0x15764db292E02BDAdba1EdFd55A3b19bbf4a0BD1;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        console.log("Factory:", OMNI_CREATE2_FACTORY);
        console.log("Deployer:", vm.addr(pk));

        // 1) OmniDragonPriceOracle (identical args across chains)
        {
            bytes memory initCode = abi.encodePacked(
                type(OmniDragonPriceOracle).creationCode,
                abi.encode("NATIVE", "USD", vm.addr(pk), REGISTRY, DRAGON)
            );
            address priceOracle = vm.computeCreate2Address(
                SALT_PRICE_ORACLE,
                keccak256(initCode),
                OMNI_CREATE2_FACTORY
            );
            if (priceOracle.code.length == 0) {
                (bool ok, ) = OMNI_CREATE2_FACTORY.call(
                    abi.encodeWithSignature("deploy(bytes,bytes32,string)", initCode, SALT_PRICE_ORACLE, "OmniDragonPriceOracle")
                );
                require(ok, "price oracle deploy failed");
            } else {
                console.log("OmniDragonPriceOracle exists:", priceOracle);
            }
            console.log("OmniDragonPriceOracle:", priceOracle);
        }

        // 2) OmniDragonPrimaryOracle (Sonic-only). For non-Sonic, this can be skipped.
        if (block.chainid == 146) {
            // Resolve endpoint from registry for current chain
            address sonicEndpoint = IOmniDragonRegistry(REGISTRY).getLayerZeroEndpoint(uint16(block.chainid));
            bytes memory initCode = abi.encodePacked(
                type(OmniDragonPrimaryOracle).creationCode,
                abi.encode("NATIVE", "USD", vm.addr(pk), REGISTRY, DRAGON, sonicEndpoint, DELEGATE)
            );
            address primaryOracle = vm.computeCreate2Address(
                SALT_PRIMARY_ORACLE,
                keccak256(initCode),
                OMNI_CREATE2_FACTORY
            );
            if (primaryOracle.code.length == 0) {
                (bool ok, ) = OMNI_CREATE2_FACTORY.call(
                    abi.encodeWithSignature("deploy(bytes,bytes32,string)", initCode, SALT_PRIMARY_ORACLE, "OmniDragonPrimaryOracle")
                );
                require(ok, "primary oracle deploy failed");
            } else {
                console.log("OmniDragonPrimaryOracle exists:", primaryOracle);
            }
            console.log("OmniDragonPrimaryOracle:", primaryOracle);
        }

        // 3) veDRAGON (identical constructor; initialize later with redDRAGON address)
        {
            bytes memory initCode = abi.encodePacked(
                type(veDRAGON).creationCode,
                abi.encode("Voting Escrow DRAGON", "veDRAGON")
            );
            address ve = vm.computeCreate2Address(
                SALT_VEDRAGON,
                keccak256(initCode),
                OMNI_CREATE2_FACTORY
            );
            if (ve.code.length == 0) {
                (bool ok, ) = OMNI_CREATE2_FACTORY.call(
                    abi.encodeWithSignature("deploy(bytes,bytes32,string)", initCode, SALT_VEDRAGON, "veDRAGON")
                );
                require(ok, "veDRAGON deploy failed");
            } else {
                console.log("veDRAGON exists:", ve);
            }
            console.log("veDRAGON:", ve);

            // Initialize veDRAGON on Sonic with redDRAGON vault (TokenType = LP_TOKEN = 1)
            if (block.chainid == 146) {
                // Only initialize if not already initialized
                try veDRAGON(ve).initialized() returns (bool inited) {
                    if (!inited) {
                        veDRAGON(ve).initialize(REDDRAGON_SONIC, veDRAGON.TokenType.LP_TOKEN);
                        console.log("veDRAGON initialized with redDRAGON on Sonic");
                    } else {
                        console.log("veDRAGON already initialized");
                    }
                } catch {
                    // Best-effort init
                }
            }
        }

        // 4) OmniDragonJackpotVault (placeholder wrapped native; set after)
        {
            bytes memory initCode = abi.encodePacked(
                type(OmniDragonJackpotVault).creationCode,
                abi.encode(address(0), vm.addr(pk))
            );
            address vault = vm.computeCreate2Address(
                SALT_VAULT,
                keccak256(initCode),
                OMNI_CREATE2_FACTORY
            );
            if (vault.code.length == 0) {
                (bool ok, ) = OMNI_CREATE2_FACTORY.call(
                    abi.encodeWithSignature("deploy(bytes,bytes32,string)", initCode, SALT_VAULT, "OmniDragonJackpotVault")
                );
                require(ok, "vault deploy failed");
            } else {
                console.log("OmniDragonJackpotVault exists:", vault);
            }
            console.log("OmniDragonJackpotVault:", vault);
        }

        // 5) redDRAGON (ERC-4626) – requires chain-specific asset; deploy without vanity unless asset is consistent
        // Example only (commented out):
        // {
        //     ERC20 asset = ERC20(0x...); // LP token
        //     bytes memory initCode = abi.encodePacked(
        //         type(redDRAGON).creationCode,
        //         abi.encode(asset, "redDRAGON", "rDRAGON")
        //     );
        //     (bool ok, bytes memory ret) = OMNI_CREATE2_FACTORY.call(
        //         abi.encodeWithSignature("safeCreate2(bytes32,bytes)", SALT_REDDRAGON, initCode)
        //     );
        //     require(ok, "redDRAGON deploy failed");
        //     address rdragon = address(uint160(uint256(bytes32(ret))));
        //     console.log("redDRAGON:", rdragon);
        // }

        vm.stopBroadcast();
    }
}


