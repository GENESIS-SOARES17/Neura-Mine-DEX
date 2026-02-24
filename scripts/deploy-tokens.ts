import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying tokens with account:", deployer.address);

  const tokens = [
    { name: "Solana", symbol: "SOL", supply: ethers.parseEther("1000000") },
    { name: "Ethereum", symbol: "ETH", supply: ethers.parseEther("1000000") },
    { name: "Arbitrum", symbol: "ARB", supply: ethers.parseEther("1000000") },
    { name: "Optimism", symbol: "OP", supply: ethers.parseEther("1000000") },
    { name: "TRON", symbol: "TRX", supply: ethers.parseEther("1000000") },
    { name: "Polygon", symbol: "POL", supply: ethers.parseEther("1000000") },
    { name: "Sui", symbol: "SUI", supply: ethers.parseEther("1000000") },
  ];

  const MockERC20 = await ethers.getContractFactory("MockERC20");
  const deployedTokens: { symbol: string; address: string }[] = [];

  for (const t of tokens) {
    console.log(`Deploying ${t.symbol}...`);
    const token = await MockERC20.deploy(t.name, t.symbol, t.supply);
    await token.waitForDeployment();
    const address = await token.getAddress();
    console.log(`✅ ${t.symbol} deployed to: ${address}`);
    deployedTokens.push({ symbol: t.symbol, address });
  }

  console.log("\n📋 Token addresses (copia e cola nos scripts):");
  deployedTokens.forEach(t => {
    console.log(`  ${t.symbol}: "${t.address}",`);
  });
}

main().catch(console.error);