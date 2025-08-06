import { HardhatUserConfig } from 'hardhat/config'
import '@layerzerolabs/toolbox-hardhat'
import '@nomiclabs/hardhat-ethers'
import 'hardhat-deploy'
import { EndpointId } from '@layerzerolabs/lz-definitions'

import dotenv from 'dotenv'
dotenv.config()

const config: HardhatUserConfig = {
    solidity: {
        version: '0.8.22',
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
            url: process.env.RPC_URL_AVALANCHE || '',
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
}

export default config