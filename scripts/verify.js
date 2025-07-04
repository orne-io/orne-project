const { run } = require("hardhat");

async function main() {
  const addresses = require("../deployed-addresses.json");
  
  console.log("=== VÉRIFICATION DES CONTRATS ===");
  
  try {
    // Vérifier le token ORNE
    console.log("1. Vérification du token ORNE...");
    await run("verify:verify", {
      address: addresses.contracts.ORNEToken,
      constructorArguments: []
    });
    console.log("✅ Token ORNE vérifié");
    
    // Vérifier le staking vault
    console.log("2. Vérification du Staking Vault...");
    await run("verify:verify", {
      address: addresses.contracts.ORNEStakingVault,
      constructorArguments: [addresses.contracts.ORNEToken]
    });
    console.log("✅ Staking Vault vérifié");
    
    console.log("\n🎉 Tous les contrats sont vérifiés !");
    
  } catch (error) {
    console.error("❌ Erreur lors de la vérification:", error);
  }
}

main().catch(console.error);
