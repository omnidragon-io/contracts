import { HardhatUserConfig } from 'hardhat/config'
import '@layerzerolabs/toolbox-hardhat'
import '@layerzerolabs/ua-devtools-evm-hardhat'
import '@nomiclabs/hardhat-ethers'
import '@nomicfoundation/hardhat-verify'
import 'hardhat-deploy'
import { EndpointId } from '@layerzerolabs/lz-definitions'

import dotenv from 'dotenv'
dotenv.config()

const config: HardhatUserConfig = {
    solidity: {
        version: '0.8.20',
        settings: { 
            optimizer: { enabled: true, runs: 75 },
            viaIR: true,
            metadata: {
                bytecodeHash: 'ipfs'
            },
            outputSelection: {
                "*": {
                    "*": ["abi", "evm.bytecode"]
                }
            }
        },
        compilers: [
            { version: '0.8.20', settings: { 
                optimizer: { enabled: true, runs: 75 },
                viaIR: true,
                metadata: { bytecodeHash: 'ipfs' }
            }},
            { version: '0.8.19', settings: { optimizer: { enabled: true, runs: 75 }, viaIR: true } },
            { version: '0.8.22', settings: { optimizer: { enabled: true, runs: 75 }, viaIR: true } },
        ],
    },
    networks: {
        hardhat: {
            // account that will deploy the contracts and antyhing else
            accounts: [
                {
                    privateKey: process.env.PRIVATE_KEY!,
                    balance: '10000000000000000000000', // 10,000 ETH
                },
            ],
        },
        sonic: {
            eid: EndpointId.SONIC_V2_MAINNET,
            url: process.env.SONIC_RPC_URL || process.env.RPC_URL_SONIC || 'https://rpc.soniclabs.com/',
            accounts: [process.env.PRIVATE_KEY!],
        },
        arbitrum: {
            eid: EndpointId.ARBITRUM_V2_MAINNET,
            url: process.env.ARBITRUM_RPC_URL || process.env.RPC_URL_ARBITRUM || 'https://arb1.arbitrum.io/rpc',
            accounts: [process.env.PRIVATE_KEY!],
        },
        avalanche: {
            eid: EndpointId.AVALANCHE_V2_MAINNET,
            url: process.env.AVAX_RPC_URL || process.env.RPC_URL_AVAX || 'https://api.avax.network/ext/bc/C/rpc',
            accounts: [process.env.PRIVATE_KEY!],
        },
        base: {
            eid: EndpointId.BASE_V2_MAINNET,
            url: process.env.BASE_RPC_URL || process.env.RPC_URL_BASE || 'https://mainnet.base.org',
            accounts: [process.env.PRIVATE_KEY!],
        },
        ethereum: {
            eid: EndpointId.ETHEREUM_V2_MAINNET,
            url: process.env.ETHEREUM_RPC_URL || process.env.RPC_URL_ETHEREUM || 'https://ethereum.publicnode.com',
            accounts: [process.env.PRIVATE_KEY!],
        },
        hype: {
            eid: EndpointId.HYPERLIQUID_V2_MAINNET,
            url: process.env.HYPE_RPC_URL || process.env.RPC_URL_HYPE || 'https://rpc.hyperevm.org',
            accounts: [process.env.PRIVATE_KEY!],
        },
    },
    etherscan: {
        apiKey: {
            sonic: process.env.SONIC_API_KEY || process.env.SONICSCAN_API_KEY || process.env.ETHERSCAN_API_KEY || '',
            arbitrumOne: process.env.ARBISCAN_API_KEY || process.env.ETHERSCAN_API_KEY || '',
            avalanche: process.env.SNOWTRACE_API_KEY || process.env.ETHERSCAN_API_KEY || '',
            // omit base to avoid unsupported warning from legacy plugin
            mainnet: process.env.ETHERSCAN_API_KEY || '',
            hype: process.env.HYPERSCAN_API_KEY || process.env.ETHERSCAN_API_KEY || 'key',
        },
        customChains: [
            {
                network: 'sonic',
                chainId: 146,
                urls: {
                    apiURL: 'https://api.sonicscan.org/api',
                    browserURL: 'https://sonicscan.org',
                },
            },
            {
                network: 'hype',
                chainId: 999,
                urls: {
                    apiURL: process.env.HYPE_API_URL || 'https://api.hyperevmscan.io/api',
                    browserURL: 'https://hyperevmscan.io',
                },
            },
        ],
    },
    sourcify: { enabled: false },
}

export default config