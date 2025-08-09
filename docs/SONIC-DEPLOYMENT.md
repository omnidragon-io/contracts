## OmniDRAGON — Sonic Deployment Summary (chainId 146)

### Core addresses
- Factory (CREATE2): `0xAA28020DDA6b954D16208eccF873D79AC6533833`
- Registry: `0x6949936442425f4137807Ac5d269e6Ef66d50777`
- DRAGON (omniDRAGON): `0x69821FFA2312253209FdabB3D84f034B697E7777`

### Vanity deployments
- veDRAGON: `0x692f8BC5E1C0E90611d2807777bF079E2e401777`
  - Salt: `0x000000000000000000000000000000000000000000000000000000017488bef4`
  - Init: `initialize(redDRAGON, TokenType.LP_TOKEN)` (Sonic policy)
- OmniDragonLotteryManager: `0x69906Fc8e0aA3cAbb184D99dF34EcE7e03769777`
  - Salt: `0x00000000000000000000000000000000000000000000000000000005d21f0ff9`
  - Constructor: `(jackpotVault, veDRAGON, priceOracle, chainId)`

### Vaults and price
- redDRAGON (ERC-4626 LP vault): `0x15764db292E02BDAdba1EdFd55A3b19bbf4a0BD1`
  - Asset (LP): `0xdD796689a646413d04ebCBCa3786900E57a49B6a`
  - token0: `wS` (`0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38`)
  - token1: `DRAGON` (`0x69821FFA2312253209FdabB3D84f034B697E7777`)
- DragonJackpotVault: `0x69352F6940529E00ccc6669606721b07BC659777`
- OmniDragonPriceOracle: `0x69aaB98503216E16EC72ac3F4B8dfc900cC27777`

### LotteryManager configuration (post-deploy)
- setRedDRAGONToken: `0x15764db292E02BDAdba1EdFd55A3b19bbf4a0BD1`
- setVRFIntegrator: `0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5`
- setDragonToken: `0x69821FFA2312253209FdabB3D84f034B697E7777`
- Authorized callers:
  - `setAuthorizedSwapContract(DRAGON, true)`
  - `setAuthorizedSwapContract(redDRAGON, true)`
  - LP pair NOT authorized (0xdD796689a646413d04ebCBCa3786900E57a49B6a → false)

### Frontend integration tips
- Read jackpot: `OmniDragonLotteryManager.getCurrentJackpot()`
- Show instant lottery config: `getInstantLotteryConfig()`
- Compute user win probability: `calculateWinProbability(user, usdAmount)`
- Show user stats: `getUserStats(user)`
- DRAGON/redDRAGON swaps will trigger lottery via authorized callers.

### .env entries
- `VEDRAGON=0x692f8BC5E1C0E90611d2807777bF079E2e401777`
- `LOTTERY_MANAGER_ADDRESS=0x69906Fc8e0aA3cAbb184D99dF34EcE7e03769777`
- `JACKPOT_VAULT_ADDRESS=0x69352F6940529E00ccc6669606721b07BC659777`
- `VANITY_SALT=0x00000000000000000000000000000000000000000000000000000005d21f0ff9`


