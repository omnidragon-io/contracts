import { EndpointId } from "@layerzerolabs/lz-definitions";
import { ExecutorOptionType } from "@layerzerolabs/lz-v2-utilities";

const ethereumContract = {
    eid: EndpointId.ETHEREUM_V2_MAINNET,
    contractName: "OmniDragonOracle", 
    address: "0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777"
};

const sonicContract = {
    eid: EndpointId.SONIC_V2_MAINNET,
    contractName: "OmniDragonOracle", 
    address: "0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777"
};

export default {
    contracts: [
        {
            contract: ethereumContract,
            config: {
                readChannelConfigs: [
                    {
                        channelId: 4294967295,
                        readLibrary: "0x74F55Bc2a79A27A0bF1D1A35dB5d0Fc36b9FDB9D",
                        active: true,
                        ulnConfig: {
                            executor: "0x173272739Bd7Aa6e4e214714048a9fE699453059",
                            requiredDVNs: [
                                "0xdb979d0a36af0525afa60fc265b1525505c55d79",
                                "0xf4064220871e3b94ca6ab3b0cee8e29178bf47de"
                            ],
                            optionalDVNs: [],
                            optionalDVNThreshold: 0
                        },
                        enforcedOptions: [
                            {
                                msgType: 1,
                                optionType: ExecutorOptionType.LZ_READ,
                                gas: 2000000,
                                value: 0,
                                size: 96
                            }
                        ]
                    }
                ]
            }
        },

        {
            contract: sonicContract,
            config: {
                readChannelConfigs: [
                    {
                        channelId: 4294967295,
                        readLibrary: "0x860E8D714944E7accE4F9e6247923ec5d30c0471",
                        active: true,
                        ulnConfig: {
                            executor: "0x4208D6E27538189bB48E603D6123A94b8Abe0A0b",
                            requiredDVNs: [
                                "0x78f607fc38e071ceb8630b7b12c358ee01c31e96",
                                "0x3b0531eb02ab4ad72e7a531180beef9493a00dd2"
                            ],
                            optionalDVNs: [],
                            optionalDVNThreshold: 0
                        },
                        enforcedOptions: [
                            {
                                msgType: 1,
                                optionType: ExecutorOptionType.LZ_READ,
                                gas: 2000000,
                                value: 0,
                                size: 96
                            }
                        ]
                    }
                ]
            }
        }
    ],
    connections: [
        {
            from: ethereumContract,
            to: sonicContract,
            config: {
                sendLibrary: "0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1",
                receiveLibraryConfig: {
                    receiveLibrary: "0xc02Ab410f0734EFa3F14628780e6e695156024C2",
                    gracePeriod: 0
                },
                sendConfig: {
                    executorConfig: {
                        maxMessageSize: 10000,
                        executor: "0x173272739Bd7Aa6e4e214714048a9fE699453059"
                    },
                    ulnConfig: {
                        confirmations: 20,
                        requiredDVNs: [
                            "0xdb979d0a36af0525afa60fc265b1525505c55d79",
                            "0xf4064220871e3b94ca6ab3b0cee8e29178bf47de"
                        ],
                        optionalDVNs: [],
                        optionalDVNThreshold: 0
                    }
                },
                receiveConfig: {
                    ulnConfig: {
                        confirmations: 20,
                        requiredDVNs: [
                            "0xdb979d0a36af0525afa60fc265b1525505c55d79",
                            "0xf4064220871e3b94ca6ab3b0cee8e29178bf47de"
                        ],
                        optionalDVNs: [],
                        optionalDVNThreshold: 0
                    }
                }
            }
        },
        {
            from: sonicContract,
            to: ethereumContract,
            config: {
                sendLibrary: "0xC39161c743D0307EB9BCc9FEF03eeb9Dc4802de7",
                receiveLibraryConfig: {
                    receiveLibrary: "0xe1844c5D63a9543023008D332Bd3d2e6f1FE1043",
                    gracePeriod: 0
                },
                sendConfig: {
                    executorConfig: {
                        maxMessageSize: 10000,
                        executor: "0x4208D6E27538189bB48E603D6123A94b8Abe0A0b"
                    },
                    ulnConfig: {
                        confirmations: 20,
                        requiredDVNs: [
                            "0x78f607fc38e071ceb8630b7b12c358ee01c31e96",
                            "0x3b0531eb02ab4ad72e7a531180beef9493a00dd2"
                        ],
                        optionalDVNs: [],
                        optionalDVNThreshold: 0
                    }
                },
                receiveConfig: {
                    ulnConfig: {
                        confirmations: 20,
                        requiredDVNs: [
                            "0x78f607fc38e071ceb8630b7b12c358ee01c31e96",
                            "0x3b0531eb02ab4ad72e7a531180beef9493a00dd2"
                        ],
                        optionalDVNs: [],
                        optionalDVNThreshold: 0
                    }
                }
            }
        }
    ]
};