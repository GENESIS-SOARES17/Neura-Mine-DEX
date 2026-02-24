import { ethers } from "hardhat";

async function main() {
  // Endereços dos contratos já implantados (verifique se estão corretos)
  const feePoolAddress = "0x3B31bb18D38c7c8A30DBcB19951C9328b69248c1";
  const miniAMMAddress = "0xc11DC3CbBC8C037E2a0afEE1A976514cB6dF0eB3";
  const predictionAddress = "0x81A2876502556a9dd6e78329EE983d40c252204F";

  const feePool = await ethers.getContractAt("FeePool", feePoolAddress);
  const miniAMM = await ethers.getContractAt("MiniAMM", miniAMMAddress);
  const prediction = await ethers.getContractAt("PredictionMarket", predictionAddress);

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

  // Adicionar tokens ao FeePool
  for (const token of tokenAddresses) {
    try {
      const tx = await feePool.addAllowedToken(token);
      await tx.wait();
      console.log(`✅ FeePool: allowed token ${token}`);
    } catch (err: any) {
      if (err.message.includes("Token already added")) {
        console.log(`ℹ️ FeePool: token ${token} already added`);
      } else {
        throw err;
      }
    }
  }

  // Adicionar tokens ao PredictionMarket
  for (const token of tokenAddresses) {
    try {
      const tx = await prediction.addAllowedToken(token);
      await tx.wait();
      console.log(`✅ PredictionMarket: allowed token ${token}`);
    } catch (err: any) {
      if (err.message.includes("Token already added")) {
        console.log(`ℹ️ PredictionMarket: token ${token} already added`);
      } else {
        throw err;
      }
    }
  }

  // Criar pares no MiniAMM (todas as combinações)
  for (let i = 0; i < tokenAddresses.length; i++) {
    for (let j = i + 1; j < tokenAddresses.length; j++) {
      const tokenA = tokenAddresses[i];
      const tokenB = tokenAddresses[j];
      try {
        const tx = await miniAMM.createPair(tokenA, tokenB);
        await tx.wait();
        console.log(`✅ Pair created: ${tokenA} / ${tokenB}`);
      } catch (err: any) {
        if (err.message.includes("Pair exists")) {
          console.log(`ℹ️ Pair already exists: ${tokenA} / ${tokenB}`);
        } else {
          throw err;
        }
      }
    }
  }

  console.log("🎉 Tokens adicionados e pares criados com sucesso!");
}

main().catch(console.error);