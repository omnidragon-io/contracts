import { EndpointId } from "@layerzerolabs/lz-definitions";
import { ExecutorOptionType } from "@layerzerolabs/lz-v2-utilities";

const arbitrumContract = {
    eid: EndpointId.ARBITRUM_V2_MAINNET,
    contractName: "OmniDragonOracle",
    address: "0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777"
};

const sonicContract = {
    eid: EndpointId.SONIC_V2_MAINNET,
    contractName: "OmniDragonOracle", 
    address: "0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777"
};

const baseContract = {
    eid: EndpointId.BASE_V2_MAINNET,
    contractName: "OmniDragonOracle",
    address: "0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777"
};

const ethereumContract = {
    eid: EndpointId.ETHEREUM_V2_MAINNET,
    contractName: "OmniDragonOracle", 
    address: "0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777"
};

export default {
    contracts: [
        {
            contract: baseContract,
            config: {
                readChannelConfigs: [
                    {
                        channelId: 4294967295,
                        readLibrary: "0x1273141a3f7923AA2d9edDfA402440cE075ed8Ff",
                        active: true,
                        ulnConfig: {
                            executor: "0x2CCA08ae69E0C44b18a57Ab2A87644234dAebaE4",
                            requiredDVNs: [
                                "0xb1473ac9f58fb27597a21710da9d1071841e8163",
                                "0x658947bc7956aea0067a62cf87ab02ae199ef3f3"
                            ],
                            optionalDVNs: [],
                            optionalDVNThreshold: 0
                        },
                        enforcedOptions: [
                            {
                                msgType: 1,
                                optionType: ExecutorOptionType.LZ_READ,
                                gas: 1000000,
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
                                "0x3b0531eB02Ab4aD72e7a531180beeF9493a00dD2",
                                "0x78f607fc38e071cEB8630B7B12c358eE01C31E96"
                            ],
                            optionalDVNs: [],
                            optionalDVNThreshold: 0
                        },
                        enforcedOptions: [
                            {
                                msgType: 1,
                                optionType: ExecutorOptionType.LZ_READ,
                                gas: 1000000,
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
            from: baseContract,
            to: sonicContract,
            config: {
                sendLibrary: "0xB5320B0B3a13cC860893E2Bd79FCd7e13484Dda2",
                receiveLibraryConfig: {
                    receiveLibrary: "0xc70AB6f32772f59fBfc23889Caf4Ba3376C84bAf",
                    gracePeriod: 0
                },
                sendConfig: {
                    executorConfig: {
                        maxMessageSize: 10000,
                        executor: "0x2CCA08ae69E0C44b18a57Ab2A87644234dAebaE4"
                    },
                    ulnConfig: {
                        confirmations: 20,
                        requiredDVNs: [
                            "0xb1473ac9f58fb27597a21710da9d1071841e8163",
                            "0x658947bc7956aea0067a62cf87ab02ae199ef3f3"
                        ],
                        optionalDVNs: [],
                        optionalDVNThreshold: 0
                    }
                },
                receiveConfig: {
                    ulnConfig: {
                        confirmations: 20,
                        requiredDVNs: [
                            "0xb1473ac9f58fb27597a21710da9d1071841e8163",
                            "0x658947bc7956aea0067a62cf87ab02ae199ef3f3"
                        ],
                        optionalDVNs: [],
                        optionalDVNThreshold: 0
                    }
                }
            }
        },
        {
            from: sonicContract,
            to: baseContract,
            config: {
                sendLibrary: "0xC39161c743D0307EB9BCc9FEF03eeb9Dc4802de7",
                receiveLibraryConfig: {
                    receiveLibrary: "0xe1844c5D63a9543023008D332Bd3d2e6f1FE1043",
                    gracePeriod: 0
                },
                sendConfig: {
                    executorConfig: {
                        maxMessageSize: 10000,
                        executor: "0x31CAe3B7fB82d847621859fb1585353c5720660D"
                    },
                    ulnConfig: {
                        confirmations: 20,
                        requiredDVNs: [
                            "0x3b0531eB02Ab4aD72e7a531180beeF9493a00dD2",
                            "0x78f607fc38e071cEB8630B7B12c358eE01C31E96"
                        ],
                        optionalDVNs: [],
                        optionalDVNThreshold: 0
                    }
                },
                receiveConfig: {
                    ulnConfig: {
                        confirmations: 20,
                        requiredDVNs: [
                            "0x3b0531eB02Ab4aD72e7a531180beeF9493a00dD2",
                            "0x78f607fc38e071cEB8630B7B12c358eE01C31E96"
                        ],
                        optionalDVNs: [],
                        optionalDVNThreshold: 0
                    }
                }
            }
        },

    ]
};