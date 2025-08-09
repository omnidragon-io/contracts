import { HardhatUserConfig } from 'hardhat/config'
import '@layerzerolabs/toolbox-hardhat'
import '@nomiclabs/hardhat-ethers'
import '@nomicfoundation/hardhat-verify'
import 'hardhat-deploy'
import { EndpointId } from '@layerzerolabs/lz-definitions'

import dotenv from 'dotenv'
dotenv.config()

const config: HardhatUserConfig = {
    solidity: {
        version: '0.8.19',
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
        },
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
            url: process.env.RPC_URL_SONIC || '',
            accounts: [process.env.PRIVATE_KEY!],
        },
        arbitrum: {
            eid: EndpointId.ARBITRUM_V2_MAINNET,
            url: process.env.RPC_URL_ARBITRUM || '',
            accounts: [process.env.PRIVATE_KEY!],
        },
        avalanche: {
            eid: EndpointId.AVALANCHE_V2_MAINNET,
            url: process.env.RPC_URL_AVAX || '',
            accounts: [process.env.PRIVATE_KEY!],
        },
        base: {
            eid: EndpointId.BASE_V2_MAINNET,
            url: process.env.RPC_URL_BASE || '',
            accounts: [process.env.PRIVATE_KEY!],
        },
        ethereum: {
            eid: EndpointId.ETHEREUM_V2_MAINNET,
            url: process.env.RPC_URL_ETHEREUM || '',
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
        ],
    },
}

export default config