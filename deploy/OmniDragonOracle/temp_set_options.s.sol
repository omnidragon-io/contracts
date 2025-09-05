pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../contracts/core/oracles/OmniDragonOracle.sol";

contract SetOptions is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        address oracleAddress = 0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777;
        OmniDragonOracle oracle = OmniDragonOracle(oracleAddress);
        
        // Set enforced options for Sonic (EID 30332)
        OmniDragonOracle.EnforcedOptionParam[] memory enforcedOptions = new OmniDragonOracle.EnforcedOptionParam[](1);
        enforcedOptions[0] = OmniDragonOracle.EnforcedOptionParam({
            eid: 30332,
            msgType: 1,
            options: hex"000301001505000000000000000000000000000f424000000060"
        });
        
        oracle.setEnforcedOptions(enforcedOptions);
        
        vm.stopBroadcast();
    }
}
