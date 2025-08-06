import { EndpointId } from '@layerzerolabs/lz-definitions'
import { ExecutorOptionType } from '@layerzerolabs/lz-v2-utilities'
import { TwoWayConfig, generateConnectionsConfig } from '@layerzerolabs/metadata-tools'
import { OAppEnforcedOption, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

const sonicContract: OmniPointHardhat = {
    eid: EndpointId.SONIC_V2_MAINNET,
    contractName: 'ChainlinkVRFIntegratorV2_5',
    address: '0x4cc69C8FEd6d340742a347905ac99DdD5b2B0A90', // Deployed VRF Integrator
}

const arbitrumContract: OmniPointHardhat = {
    eid: EndpointId.ARBITRUM_V2_MAINNET,
    contractName: 'OmniDragonVRFConsumerV2_5',
    address: '0x4CC1b5e72b9a5A6D6cE2131b444bB483FA2815c8', // Deployed VRF Consumer
}

// For this example's simplicity, we will use the same enforced options values for sending to all chains
// To learn more, read https://docs.layerzero.network/v2/concepts/applications/oapp-standard#execution-options-and-enforced-settings
const EVM_ENFORCED_OPTIONS: OAppEnforcedOption[] = [
    {
        msgType: 1,
        optionType: ExecutorOptionType.LZ_RECEIVE,
        gas: 200000,
        value: 0,
    },
]

// Configure all pathways between chains
const pathways: TwoWayConfig[] = [
    [
        // Sonic <-> Arbitrum
        sonicContract,
        arbitrumContract,
        [['LayerZero Labs'], []],
        [1, 1],
        [EVM_ENFORCED_OPTIONS, EVM_ENFORCED_OPTIONS],
    ],
]

export default async function () {
    // Generate the connections config based on the pathways
    const connections = await generateConnectionsConfig(pathways)
    return {
        contracts: [
            { contract: sonicContract }, 
            { contract: arbitrumContract }
        ],
        connections,
    }
}
