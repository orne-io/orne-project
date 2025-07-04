const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  
  console.log("=== DEPLOIEMENT SUR ARBITRUM ===");
  console.log("Deploiement avec le compte:", deployer.address);
  
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Solde du compte:", ethers.formatEther(balance), "ETH");
  
  const minBalance = ethers.parseEther("0.001");
  
  if (balance < minBalance) {
    throw new Error("Solde insuffisant ! Il faut au moins 0.001 ETH sur Arbitrum");
  }

  console.log("\n1. Deploiement du token ORNE...");
  const ORNEToken = await ethers.getContractFactory("ORNEToken");
  const orneToken = await ORNEToken.deploy();
  
  await orneToken.waitForDeployment();
  const orneTokenAddress = await orneToken.getAddress();
  console.log("Token ORNE deploye a:", orneTokenAddress);

  console.log("\n2. Deploiement du Staking Vault...");
  const ORNEStakingVault = await ethers.getContractFactory("ORNEStakingVault");
  const stakingVault = await ORNEStakingVault.deploy(orneTokenAddress);
  
  await stakingVault.waitForDeployment();
  const stakingVaultAddress = await stakingVault.getAddress();
  console.log("Staking Vault deploye a:", stakingVaultAddress);

  console.log("\n=== DEPLOIEMENT TERMINE ===");
  console.log("ORNE Token:", orneTokenAddress);
  console.log("Staking Vault:", stakingVaultAddress);
  console.log("Voir sur Arbiscan:");
  console.log("https://arbiscan.io/address/" + orneTokenAddress);
  console.log("https://arbiscan.io/address/" + stakingVaultAddress);

  const finalBalance = await ethers.provider.getBalance(deployer.address);
  const deploymentCost = balance - finalBalance;
  console.log("\nCout du deploiement:", ethers.formatEther(deploymentCost), "ETH");

  const fs = require('fs');
  const addresses = {
    network: "arbitrum",
    chainId: 42161,
    timestamp: new Date().toISOString(),
    deployer: deployer.address,
    deploymentCost: ethers.formatEther(deploymentCost),
    contracts: {
      ORNEToken: orneTokenAddress,
      ORNEStakingVault: stakingVaultAddress
    }
  };
  
  fs.writeFileSync('deployed-addresses.json', JSON.stringify(addresses, null, 2));
  console.log("\nAdresses sauvegardees dans deployed-addresses.json");
}

main().catch((error) => {
  console.error("Erreur lors du deploiement:", error);
  process.exitCode = 1;
});
