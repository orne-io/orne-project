const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  
  console.log("=== DÉPLOIEMENT SUR ARBITRUM ===");
  console.log("Déploiement avec le compte:", deployer.address);
  console.log("Solde du compte:", (await deployer.getBalance()).toString());
  
  // Vérifier qu'on a assez d'ETH
  const balance = await deployer.getBalance();
  const minBalance = ethers.utils.parseEther("0.01"); // 0.01 ETH minimum
  
  if (balance.lt(minBalance)) {
    throw new Error("Solde insuffisant ! Il faut au moins 0.01 ETH sur Arbitrum");
  }

  // Déployer le token ORNE
  console.log("\n1. Déploiement du token ORNE...");
  const ORNEToken = await ethers.getContractFactory("ORNEToken");
  const orneToken = await ORNEToken.deploy();
  await orneToken.deployed();
  console.log("✅ ORNE Token déployé à:", orneToken.address);

  // Attendre quelques confirmations
  console.log("⏳ Attente de 5 confirmations...");
  await orneToken.deployTransaction.wait(5);

  // Déployer le staking vault
  console.log("\n2. Déploiement du Staking Vault...");
  const ORNEStakingVault = await ethers.getContractFactory("ORNEStakingVault");
  const stakingVault = await ORNEStakingVault.deploy(orneToken.address);
  await stakingVault.deployed();
  console.log("✅ Staking Vault déployé à:", stakingVault.address);

  // Attendre quelques confirmations
  console.log("⏳ Attente de 5 confirmations...");
  await stakingVault.deployTransaction.wait(5);

  // Afficher les informations finales
  console.log("\n=== DÉPLOIEMENT TERMINÉ ===");
  console.log("🎉 Tous les contrats ont été déployés avec succès !");
  console.log("\nADRESSES DES CONTRATS:");
  console.log("ORNE Token:", orneToken.address);
  console.log("Staking Vault:", stakingVault.address);
  console.log("\nExplorateur Arbitrum:");
  console.log("https://arbiscan.io/address/" + orneToken.address);
  console.log("https://arbiscan.io/address/" + stakingVault.address);

  // Sauvegarder dans un fichier
  const fs = require('fs');
  const addresses = {
    network: "arbitrum",
    timestamp: new Date().toISOString(),
    contracts: {
      ORNEToken: orneToken.address,
      ORNEStakingVault: stakingVault.address
    }
  };
  
  fs.writeFileSync('deployed-addresses.json', JSON.stringify(addresses, null, 2));
  console.log("\n📄 Adresses sauvegardées dans deployed-addresses.json");
}

main().catch((error) => {
  console.error("❌ Erreur lors du déploiement:", error);
  process.exitCode = 1;
});
