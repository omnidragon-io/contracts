// GENERATED VANITY DEPLOYMENT SCRIPT
// Deploy OmniDragonRegistry to vanity address: 0x69eea84a94e0fe8fb79865f7c57e750ab29a5777

import { ethers } from 'hardhat';

async function main() {
console.log('🚀 Deploying OmniDragonRegistry to vanity address...');

const [signer] = await ethers.getSigners();
console.log('Deployer:', signer.address);

// Vanity deployment parameters
const salt = '0xde5a8507d6d4f32f46631b7482cac642580bdb6f4eb589e86d56dfb863f916ea';
const expectedAddress = '0x69eea84a94e0fe8fb79865f7c57e750ab29a5777';
const deployerAddress = '0xDDd0050d1E084dFc72d5d06447Cc10bcD3fEF60F';

console.log('Expected address:', expectedAddress);
console.log('Salt:', salt);

// Get contract factory
const Registry = await ethers.getContractFactory('OmniDragonRegistry');

// Constructor args
const constructorArgs = [deployerAddress];

// Calculate CREATE2 address to verify
const initCode = Registry.getDeployTransaction(...constructorArgs).data;
const bytecodeHash = ethers.utils.keccak256(initCode);

const calculatedAddress = ethers.utils.getCreate2Address(
deployerAddress,
salt,
bytecodeHash
);

console.log('Calculated address:', calculatedAddress);

if (calculatedAddress.toLowerCase() !== expectedAddress.toLowerCase()) {
console.warn('⚠️  Address mismatch! Contract bytecode may have changed.');
console.log('Expected:', expectedAddress);
console.log('Calculated:', calculatedAddress);
}

// Deploy using CREATE2
const registry = await Registry.deploy(...constructorArgs, {
salt: salt,
gasLimit: 3000000
});

await registry.deployed();

console.log('🎉 Registry deployed!');
console.log('Address:', registry.address);
console.log('Transaction:', registry.deployTransaction.hash);

// Verify deployment
const owner = await registry.owner();

console.log('✅ Verified:');
console.log('   Owner:', owner);

return registry.address;
}

main().catch(console.error);
