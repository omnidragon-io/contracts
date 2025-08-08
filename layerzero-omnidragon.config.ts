import { EndpointId } from '@layerzerolabs/lz-definitions'
import { ExecutorOptionType } from '@layerzerolabs/lz-v2-utilities'
import { TwoWayConfig, generateConnectionsConfig } from '@layerzerolabs/metadata-tools'
import { OAppEnforcedOption, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

// omniDRAGON token address (same on all chains with vanity address)
const OMNI_DRAGON_ADDRESS = '0x69821FFA2312253209FdabB3D84f034B697E7777'

// Define omniDRAGON contracts on each chain
const sonicDragon: OmniPointHardhat = {
    eid: EndpointId.SONIC_V2_MAINNET,
    contractName: 'omniDRAGON',
    address: OMNI_DRAGON_ADDRESS,
}

const arbitrumDragon: OmniPointHardhat = {
    eid: EndpointId.ARBITRUM_V2_MAINNET,
    contractName: 'omniDRAGON',
    address: OMNI_DRAGON_ADDRESS,
}

const ethereumDragon: OmniPointHardhat = {
    eid: EndpointId.ETHEREUM_V2_MAINNET,
    contractName: 'omniDRAGON',
    address: OMNI_DRAGON_ADDRESS,
}

const baseDragon: OmniPointHardhat = {
    eid: EndpointId.BASE_V2_MAINNET,
    contractName: 'omniDRAGON',
    address: OMNI_DRAGON_ADDRESS,
}

const avalancheDragon: OmniPointHardhat = {
    eid: EndpointId.AVALANCHE_V2_MAINNET,
    contractName: 'omniDRAGON',
    address: OMNI_DRAGON_ADDRESS,
}

// Enforced options for omniDRAGON transfers
// Do not enforce any LZ receive gas; rely on defaults and per-call options
const EVM_ENFORCED_OPTIONS: OAppEnforcedOption[] = []

// Configure all cross-chain pathways (full mesh network)
const pathways: TwoWayConfig[] = [
    // Sonic <-> All other chains
    [
        sonicDragon,
        arbitrumDragon,
        [['LayerZero Labs'], []],
        [1, 1],
        [EVM_ENFORCED_OPTIONS, EVM_ENFORCED_OPTIONS],
    ],
    [
        sonicDragon,
        ethereumDragon,
        [['LayerZero Labs'], []],
        [1, 1],
        [EVM_ENFORCED_OPTIONS, EVM_ENFORCED_OPTIONS],
    ],
    [
        sonicDragon,
        baseDragon,
        [['LayerZero Labs'], []],
        [1, 1],
        [EVM_ENFORCED_OPTIONS, EVM_ENFORCED_OPTIONS],
    ],
    [
        sonicDragon,
        avalancheDragon,
        [['LayerZero Labs'], []],
        [1, 1],
        [EVM_ENFORCED_OPTIONS, EVM_ENFORCED_OPTIONS],
    ],
    
    // Arbitrum <-> Other chains (excluding Sonic, already covered)
    [
        arbitrumDragon,
        ethereumDragon,
        [['LayerZero Labs'], []],
        [1, 1],
        [EVM_ENFORCED_OPTIONS, EVM_ENFORCED_OPTIONS],
    ],
    [
        arbitrumDragon,
        baseDragon,
        [['LayerZero Labs'], []],
        [1, 1],
        [EVM_ENFORCED_OPTIONS, EVM_ENFORCED_OPTIONS],
    ],
    [
        arbitrumDragon,
        avalancheDragon,
        [['LayerZero Labs'], []],
        [1, 1],
        [EVM_ENFORCED_OPTIONS, EVM_ENFORCED_OPTIONS],
    ],
    
    // Ethereum <-> Remaining chains
    [
        ethereumDragon,
        baseDragon,
        [['LayerZero Labs'], []],
        [1, 1],
        [EVM_ENFORCED_OPTIONS, EVM_ENFORCED_OPTIONS],
    ],
    [
        ethereumDragon,
        avalancheDragon,
        [['LayerZero Labs'], []],
        [1, 1],
        [EVM_ENFORCED_OPTIONS, EVM_ENFORCED_OPTIONS],
    ],
    
    // Base <-> Avalanche
    [
        baseDragon,
        avalancheDragon,
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
            { contract: sonicDragon },
            { contract: arbitrumDragon },
            { contract: ethereumDragon },
            { contract: baseDragon },
            { contract: avalancheDragon },
        ],
        connections,
    }
}
