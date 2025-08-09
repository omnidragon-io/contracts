import { EndpointId } from '@layerzerolabs/lz-definitions'
import { TwoWayConfig, generateConnectionsConfig } from '@layerzerolabs/metadata-tools'
import { OAppEnforcedOption, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'
import { ExecutorOptionType } from '@layerzerolabs/lz-v2-utilities'

const primary: OmniPointHardhat = {
  eid: EndpointId.SONIC_V2_MAINNET,
  contractName: 'OmniDragonPrimaryOracle',
  address: '0x691882e3d485411ec5692b302f9d50f6c7f11777',
}

const secondaryArb: OmniPointHardhat = {
  eid: EndpointId.ARBITRUM_V2_MAINNET,
  contractName: 'OmniDragonSecondaryOracle',
  address: '0x6983e11b84076282e9195dd25f852a04bda92777',
}

const EVM_ENFORCED_OPTIONS: OAppEnforcedOption[] = []

const pathways: TwoWayConfig[] = [
  [
    primary,
    secondaryArb,
    [['LayerZero Labs'], []],
    [1, 1],
    [EVM_ENFORCED_OPTIONS, EVM_ENFORCED_OPTIONS],
  ],
]

export default async function () {
  const connections = await generateConnectionsConfig(pathways)
  return {
    contracts: [
      {
        contract: primary,
        config: {
          readChannelConfigs: [
            {
              channelId: 4294967295,
              active: true,
              readLibrary: '0x860E8D714944E7accE4F9e6247923ec5d30c0471',
              // Use default channel ULN config from metadata
              
            },
          ],
        },
      },
      {
        contract: secondaryArb,
        config: {
          readChannelConfigs: [
            {
              channelId: 4294967295,
              active: true,
              readLibrary: '0xbcd4CADCac3F767C57c4F402932C4705DF62BEFf',
              // Use default channel ULN config from metadata
              
            },
          ],
        },
      },
    ],
    connections,
  }
}


