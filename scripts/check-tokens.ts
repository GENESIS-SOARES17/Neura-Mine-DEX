import { ethers } from "hardhat";

// Lista de tokens fornecida originalmente (com checksum incorreto)
const TOKENS_RAW = {
  SOL: "0xaFaFC2942bA7f1C47a9E453da1a55ba3C5a55652",
  ETH: "0x1a8357522Ed5c1a76f361520DEC1b02a3a0D4014",
  ARB: "0x2444FAe99F9Aa127043D32bE8589fac4b601c733",
  OP:  "0x3630388bd5e6927b7B6F8B6Eb5863315D9401401",
  TRX: "0x3655ccBD4E10C74a58B48B016fD68fa168F49324",
  POL: "0x5Ac7435DC9Ca69C85BfcD9187D2D9BdC5cDEf711",
  SUI: "0x6a283F60975099f2B361607Faf8CF7a683e3F4a6",
};

async function main() {
  console.log("🔍 Verificando tokens na Neura Testnet...\n");

  const validTokens: { symbol: string; address: string }[] = [];

  for (const [symbol, addressRaw] of Object.entries(TOKENS_RAW)) {
    process.stdout.write(`📌 Testando ${symbol} (${addressRaw})... `);

    try {
      // Converte para checksum (ou minúsculas, mas o ethers aceita checksum)
      const address = ethers.getAddress(addressRaw); // lança erro se checksum inválido

      // Tenta obter o contrato com a interface mínima ERC20
      const token = await ethers.getContractAt("IERC20", address);

      // Tenta chamar totalSupply() – se reverter, o token não é ERC20 válido
      await token.totalSupply();

      // Se chegou até aqui, o token é válido
      console.log("✅ Válido");
      validTokens.push({ symbol, address });
    } catch (error: any) {
      console.log("❌ Inválido ou erro de acesso");
      console.log(`   Motivo: ${error.message || error}`);
    }
  }

  console.log("\n📋 Tokens válidos encontrados:");
  validTokens.forEach(t => console.log(`   ${t.symbol}: ${t.address}`));

  // Gerar código para substituir nos scripts
  console.log("\n🔧 Copie e cole esta lista nos seus scripts (deploy.ts e add-tokens.ts):\n");
  console.log("const TOKENS = {");
  validTokens.forEach(t => {
    console.log(`  ${t.symbol}: "${t.address}",`);
  });
  console.log("};");
}

main().catch(console.error);