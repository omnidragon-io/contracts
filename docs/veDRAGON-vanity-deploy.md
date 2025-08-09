## veDRAGON Vanity Deployment — Status and Next Steps

### What’s done
- **Factory verified**: `0xAA28020DDA6b954D16208eccF873D79AC6533833` (matches `deployments/sonic/CREATE2FactoryWithOwnership.json` and `.env`).
- **veDRAGON init code prepared**: saved to `vedragon_initcode.hex` (creationCode + constructor args `"Voting Escrow DRAGON", "veDRAGON"`).
- **Bytecode hash computed**: `vedragon_bytecode_hash.txt` = `0x2199bc8a5294d858cb362e4cb7114534c18efa49d22f08fe86dfdba831edc333`.
- **Vanity search (Rust) completed** for prefix `0x69` and suffix `777` against the factory + veDRAGON init code hash:
  - **VANITY_SALT**: `0x000000000000000000000000000000000000000000000000000000017488bef4`
  - **EXPECTED_ADDRESS**: `0x692f8bc5e1c0e90611d2807777bf079e2e401777`
- **Rust deployer added**: `src/deploy_vedragon.rs` to call factory `deploy(bytes,bytes32,string)`.
  - Built successfully; runtime hex parsing from `vedragon_initcode.hex` still errors (OddLength). Code includes sanitization; best path is to compute init code in-memory or use Foundry script.
- **Foundry script reference**: `script/DeployVanityCore.s.sol` already shows the veDRAGON vanity deployment flow via factory.

### Key files and constants
- **Factory**: `0xAA28020DDA6b954D16208eccF873D79AC6533833`
- **Vanity salt**: `0x000000000000000000000000000000000000000000000000000000017488bef4`
- **Vanity address**: `0x692f8bc5e1c0e90611d2807777bf079e2e401777`
- **veDRAGON constructor**: `(name = "Voting Escrow DRAGON", symbol = "veDRAGON")`
- **Artifacts**:
  - `vedragon_initcode.hex`
  - `vedragon_bytecode_hash.txt`
  - `script/DeployVanityCore.s.sol` (reference deployment)
  - `src/deploy_vedragon.rs` (Rust deployer)

### Next steps (recommended: Foundry)
1) **Update script salts**
   - In `script/DeployVanityCore.s.sol`, set:
     - `SALT_VEDRAGON = 0x000000000000000000000000000000000000000000000000000000017488bef4`
   - Optional: assert/print the computed address equals `0x692f8bc5e1c0e90611d2807777bf079e2e401777` via `vm.computeCreate2Address`.

2) **Broadcast deploy on Sonic**
   - Ensure `.env` has `PRIVATE_KEY` and `RPC_URL_SONIC`.
   - Run:
     ```bash
     forge script script/DeployVanityCore.s.sol \
       --rpc-url $RPC_URL_SONIC \
       --private-key $PRIVATE_KEY \
       --broadcast
     ```

3) **Initialize veDRAGON** (per chain policy)
   - Sonic (chainId 146) path is shown in `DeployVanityCore.s.sol`:
     - `veDRAGON(ve).initialize(REDDRAGON_SONIC, veDRAGON.TokenType.LP_TOKEN);`
   - Otherwise, reference `DeployCoreDependencies.s.sol` for DRAGON-token init:
     - `veDRAGON.initialize(omniDRAGON, veDRAGON.TokenType.DRAGON);`

4) **Verify and record**
   - Confirm code at `0x692f8bc5e1c0e90611d2807777bf079e2e401777`.
   - Update `.env` with `VEDRAGON=<deployed address>`.
   - Add to `deployments/` and commit.

5) **Downstream usage**
   - `script/DeployLotteryManager.s.sol` reads `VEDRAGON` from env; deploy after updating it.

### Alternative path (Rust-only)
If you want to keep deployment in Rust:
- Modify `src/deploy_vedragon.rs` to compute init code in-memory rather than reading `vedragon_initcode.hex`:
  - Obtain `veDRAGON` bytecode (e.g., via `forge inspect ... bytecode` at build time or embed generated JSON) and ABI-encode constructor `(name, symbol)` directly in Rust, then `abi.encodePacked` equivalent to produce `initCode`.
- Then run:
  ```bash
  ./target/release/deploy-vedragon \
    --rpc $RPC_URL_SONIC \
    --pk $PRIVATE_KEY \
    --factory 0xAA28020DDA6b954D16208eccF873D79AC6533833 \
    --salt 0x000000000000000000000000000000000000000000000000000000017488bef4
  ```

### Cross-chain replication
- Using the same `initCode` and `salt` with the same factory contract yields the same vanity address across chains. Ensure the factory address and bytecode hash match on target chains.

### Notes / Pitfalls
- The OddLength hex panic came from reading `vedragon_initcode.hex`. Even after sanitization, safest approach is to generate `initCode` in-process (no file I/O) to avoid formatting artifacts.
- Ensure the factory API is `deploy(bytes,bytes32,string)` as used in scripts; this matches `CREATE2FactoryWithOwnership` in `deployments/sonic/CREATE2FactoryWithOwnership.json`.

### Quick reference
- **Foundry deploy (recommended):**
  ```bash
  forge script script/DeployVanityCore.s.sol \
    --rpc-url $RPC_URL_SONIC \
    --private-key $PRIVATE_KEY \
    --broadcast
  ```
- **Rust deploy (after computing initCode inline):**
  ```bash
  ./target/release/deploy-vedragon \
    --rpc $RPC_URL_SONIC \
    --pk $PRIVATE_KEY \
    --factory 0xAA28020DDA6b954D16208eccF873D79AC6533833 \
    --salt 0x000000000000000000000000000000000000000000000000000000017488bef4
  ```


