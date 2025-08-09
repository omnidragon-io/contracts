use clap::Parser;
use ethers::abi::{encode, Token};
use ethers::prelude::*;
use ethers::types::transaction::eip2718::TypedTransaction;
use ethers::utils::{id, keccak256};
use sha3::Digest;
use std::str::FromStr;
use std::sync::Arc;

#[derive(Parser, Debug)]
#[command(author, version, about = "Deploy veDRAGON via CREATE2FactoryWithOwnership")] 
struct Args {
    /// RPC URL
    #[arg(long)]
    rpc: String,

    /// Deployer private key (hex, with or without 0x)
    #[arg(long)]
    pk: String,

    /// CREATE2 factory address
    #[arg(long, default_value = "0xAA28020DDA6b954D16208eccF873D79AC6533833")]
    factory: String,

    /// Salt to use (0x-prefixed 32-byte hex)
    #[arg(long)]
    salt: String,
}

#[tokio::main]
async fn main() -> eyre::Result<()> {
    let args = Args::parse();

    // Provider + signer
    let provider = Provider::<Http>::try_from(args.rpc.clone())?.interval(std::time::Duration::from_millis(2000));
    let chain_id = provider.get_chainid().await?.as_u64();

    let pk_clean = args.pk.trim_start_matches("0x");
    let wallet = LocalWallet::from_str(pk_clean)?.with_chain_id(chain_id);
    let signer = SignerMiddleware::new(provider, wallet);
    let client = Arc::new(signer);

    let factory: Address = args.factory.parse()?;

    // Build veDRAGON init code: creationCode + abi.encode("Voting Escrow DRAGON", "veDRAGON")
    // creationCode via foundry inspection is complex from Rust; instead reconstruct via known deployed out artifact path when present
    // Here we re-encode by linking already computed init code stored in file vedragon_initcode.hex by prior step.
    let init_hex = std::fs::read_to_string("vedragon_initcode.hex")?;
    let mut init_clean = init_hex.trim().trim_start_matches("0x").to_string();
    // Remove any non-hex characters just in case
    init_clean.retain(|c| c.is_ascii_hexdigit());
    if init_clean.len() % 2 == 1 {
        init_clean = format!("0{}", init_clean);
    }
    let init_bytes = hex::decode(&init_clean).expect("invalid init code hex");

    // Sanity log
    let bytecode_hash = H256::from_slice(keccak256(&init_bytes).as_slice());
    println!("Init code hash: 0x{}", hex::encode(bytecode_hash.as_bytes()));

    // Prepare call data for factory.deploy(bytes,bytes32,string)
    // function deploy(bytes memory initCode, bytes32 salt, string memory name)
    let salt_h: H256 = args.salt.parse()?;
    let deploy_selector = id("deploy(bytes,bytes32,string)")[..4].to_vec();
    let encoded = encode(&[
        Token::Bytes(init_bytes),
        Token::FixedBytes(salt_h.as_bytes().to_vec()),
        Token::String("veDRAGON".to_string()),
    ]);
    let data = [deploy_selector, encoded].concat();

    // Estimate and send tx
    let mut tx: TypedTransaction = TransactionRequest::new().to(factory).data(data).into();
    let gas = client.estimate_gas(&tx, None).await.unwrap_or_else(|_| U256::from(3_000_000u64));
    tx.set_gas(gas);
    let pending = client.send_transaction(tx, None).await?;
    let receipt = pending.confirmations(1).await?.expect("no receipt");
    println!("Factory tx: {:?}", receipt.transaction_hash);

    // Compute predicted address to show
    let factory_addr: Address = factory;
    let predicted = {
        let mut hasher = sha3::Keccak256::new();
        hasher.update([0xff]);
        hasher.update(factory_addr.as_bytes());
        hasher.update(salt_h.as_bytes());
        hasher.update(bytecode_hash.as_bytes());
        let hash = hasher.finalize();
        Address::from_slice(&hash[12..])
    };
    println!("Predicted veDRAGON address: {:#x}", predicted);

    Ok(())
}


