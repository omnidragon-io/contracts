import { EndpointId } from '@layerzerolabs/lz-definitions'
import { ExecutorOptionType } from '@layerzerolabs/lz-v2-utilities'
import { TwoWayConfig, generateConnectionsConfig } from '@layerzerolabs/metadata-tools'
import { OAppEnforcedOption, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

// Updated VRF addresses with new registry integration
const VRF_INTEGRATOR_ADDRESS = '0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5'
const VRF_CONSUMER_ADDRESS = '0x697a9d438a5b61ea75aa823f98a85efb70fd23d5'

const sonicContract: OmniPointHardhat = {
    eid: EndpointId.SONIC_V2_MAINNET,
    contractName: 'ChainlinkVRFIntegratorV2_5',
    address: VRF_INTEGRATOR_ADDRESS, // Updated VRF Integrator
}

const arbitrumVRFConsumer: OmniPointHardhat = {
    eid: EndpointId.ARBITRUM_V2_MAINNET,
    contractName: 'OmniDragonVRFConsumerV2_5',
    address: VRF_CONSUMER_ADDRESS, // Updated VRF Consumer
}

// For this example's simplicity, we will use the same enforced options values for sending to all chains
// To learn more, read https://docs.layerzero.network/v2/concepts/applications/oapp-standard#execution-options-and-enforced-settings
const EVM_ENFORCED_OPTIONS: OAppEnforcedOption[] = [
    {
        msgType: 1,
        optionType: ExecutorOptionType.LZ_RECEIVE,
        gas: 2000000, // Increased to 2M gas for VRF operations
        value: 0,
    },
]

// Configure all pathways between chains
const pathways: TwoWayConfig[] = [
    [
        // Sonic VRF Integrator <-> Arbitrum VRF Consumer (bidirectional)
        sonicContract,
        arbitrumVRFConsumer,
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
            { contract: arbitrumVRFConsumer }
        ],
        connections,
    }
}
