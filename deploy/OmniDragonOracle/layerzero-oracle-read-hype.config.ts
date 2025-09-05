import { EndpointId } from "@layerzerolabs/lz-definitions";
import { ExecutorOptionType } from "@layerzerolabs/lz-v2-utilities";

const hypeContract = {
    eid: EndpointId.HYPERLIQUID_V2_MAINNET,
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
            contract: hypeContract,
            config: {
                readChannelConfigs: [
                    {
                        channelId: 4294967295,
                        readLibrary: "0xefF88eC9555b33A39081231131f0ed001FA9F96C",
                        active: true,
                        ulnConfig: {
                            executor: "0x41Bdb4aa4A63a5b2Efc531858d3118392B1A1C3d",
                            requiredDVNs: [
                                "0x7ffd4989882a006ac51f324b4889b3087d71b716",
                                "0xffe7244216f46401f541125bc8349bbbeb666027"
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
            from: hypeContract,
            to: sonicContract,
            config: {
                sendLibrary: "0xfd76d9CB0Bac839725aB79127E7411fe71b1e3CA",
                receiveLibraryConfig: {
                    receiveLibrary: "0x7cacBe439EaD55fa1c22790330b12835c6884a91",
                    gracePeriod: 0
                },
                sendConfig: {
                    executorConfig: {
                        maxMessageSize: 10000,
                        executor: "0x41Bdb4aa4A63a5b2Efc531858d3118392B1A1C3d"
                    },
                    ulnConfig: {
                        confirmations: 20,
                        requiredDVNs: [
                            "0x7ffd4989882a006ac51f324b4889b3087d71b716",
                            "0xffe7244216f46401f541125bc8349bbbeb666027"
                        ],
                        optionalDVNs: [],
                        optionalDVNThreshold: 0
                    }
                },
                receiveConfig: {
                    ulnConfig: {
                        confirmations: 20,
                        requiredDVNs: [
                            "0x7ffd4989882a006ac51f324b4889b3087d71b716",
                            "0xffe7244216f46401f541125bc8349bbbeb666027"
                        ],
                        optionalDVNs: [],
                        optionalDVNThreshold: 0
                    }
                }
            }
        },
        {
            from: sonicContract,
            to: hypeContract,
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