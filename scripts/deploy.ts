import { ethers } from "hardhat";

async function main() {
  console.log("Deploying contracts to Neura Testnet...");

  // ============================================================
  // ✅ TOKENS IMPLANTADOS COM SUCESSO
  // ============================================================
  const TOKENS = {
    SOL: "0x5fBab0918D3EF006B20e211A067CF2810f89681B",
    ETH: "0x5381C3f1e9b81a3755F26aaaFb19a2bbD081af24",
    ARB: "0x01e38d0Be46aAC64e2549BF116D3784e1A413008",
    OP:  "0x7d2c93cbeF265253d214Fc4ef5AC3ED65600160d",
    TRX: "0x5ebC69e9DC734CB069E245a27cE82Cc0A4b903fC",
    POL: "0x454224C0E7d40ebFcC1D3d73Cc2038cbdfD3F6Ff",
    SUI: "0xA4FaFAfe9a11475c9FA8467e6977ab89Ef58805A",
  };
  // ============================================================

  const tokenAddresses = Object.values(TOKENS);

  // Deploy FeePool
  const FeePool = await ethers.getContractFactory("FeePool");
  const feePool = await FeePool.deploy();
  await feePool.waitForDeployment();
  const feePoolAddress = await feePool.getAddress();
  console.log("✅ FeePool deployed to:", feePoolAddress);

  // Deploy MiniAMM
  const MiniAMM = await ethers.getContractFactory("MiniAMM");
  const miniAMM = await MiniAMM.deploy(feePoolAddress);
  await miniAMM.waitForDeployment();
  const miniAMMAddress = await miniAMM.getAddress();
  console.log("✅ MiniAMM deployed to:", miniAMMAddress);

  // Deploy PredictionMarket
  const PredictionMarket = await ethers.getContractFactory("PredictionMarket");
  const predictionMarket = await PredictionMarket.deploy(feePoolAddress);
  await predictionMarket.waitForDeployment();
  const predictionMarketAddress = await predictionMarket.getAddress();
  console.log("✅ PredictionMarket deployed to:", predictionMarketAddress);

  // Configurar permissões no FeePool
  await feePool.setAMMContract(miniAMMAddress);
  console.log("✅ FeePool: AMM contract set");
  await feePool.setPredictionContract(predictionMarketAddress);
  console.log("✅ FeePool: Prediction contract set");

  // Adicionar tokens permitidos no FeePool
  for (const token of tokenAddresses) {
    await feePool.addAllowedToken(token);
    console.log(`✅ FeePool: allowed token ${token}`);
  }

  // Adicionar tokens permitidos no PredictionMarket
  for (const token of tokenAddresses) {
    await predictionMarket.addAllowedToken(token);
    console.log(`✅ PredictionMarket: allowed token ${token}`);
  }

  // Criar pares iniciais (primeiro par SOL/ETH)
  if (tokenAddresses.length >= 2) {
    console.log("Creating initial pair SOL/ETH...");
    try {
      await miniAMM.createPair(TOKENS.SOL, TOKENS.ETH);
      console.log("✅ Pair SOL/ETH created");
    } catch (err: any) {
      console.log("⚠️ Pair creation failed (maybe already exists):", err.message);
    }
  }

  console.log("\n🎉 Deploy completed!");
  console.log("📄 Contract addresses:");
  console.log(`- FeePool: ${feePoolAddress}`);
  console.log(`- MiniAMM: ${miniAMMAddress}`);
  console.log(`- PredictionMarket: ${predictionMarketAddress}`);
}

main().catch((error) => {
  console.error("❌ Deploy failed:", error);
  process.exitCode = 1;
});