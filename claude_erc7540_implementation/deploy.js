const hre = require("hardhat");

async function main() {
  console.log("Deploying ERC7540 Vault...");

  // Configuration
  const UNDERLYING_ASSET = "0x..."; // Replace with actual asset address
  const VAULT_NAME = "Async Vault Token";
  const VAULT_SYMBOL = "aVault";
  const OPERATOR_ADDRESS = "0x..."; // Replace with operator address
  const FULFILLMENT_DELAY = 3600; // 1 hour in seconds

  // Get the contract factory
  const ERC7540Vault = await hre.ethers.getContractFactory("ERC7540Vault");

  // Deploy the vault
  const vault = await ERC7540Vault.deploy(
    UNDERLYING_ASSET,
    VAULT_NAME,
    VAULT_SYMBOL,
    OPERATOR_ADDRESS,
    FULFILLMENT_DELAY
  );

  await vault.waitForDeployment();

  const vaultAddress = await vault.getAddress();
  console.log(`ERC7540Vault deployed to: ${vaultAddress}`);

  // Verify ERC-165 support
  console.log("\nVerifying ERC-165 interface support...");
  
  const supportsOperators = await vault.supportsInterface("0xe3bc4e65");
  console.log(`Supports ERC7540 operators: ${supportsOperators}`);
  
  const supportsAsyncDeposit = await vault.supportsInterface("0xce3bbe50");
  console.log(`Supports async deposits: ${supportsAsyncDeposit}`);
  
  const supportsAsyncRedeem = await vault.supportsInterface("0x620ee8e4");
  console.log(`Supports async redemptions: ${supportsAsyncRedeem}`);

  console.log("\nDeployment configuration:");
  console.log(`- Asset: ${UNDERLYING_ASSET}`);
  console.log(`- Name: ${VAULT_NAME}`);
  console.log(`- Symbol: ${VAULT_SYMBOL}`);
  console.log(`- Operator: ${OPERATOR_ADDRESS}`);
  console.log(`- Fulfillment Delay: ${FULFILLMENT_DELAY} seconds`);

  console.log("\nTo verify on Etherscan, run:");
  console.log(`npx hardhat verify --network <network> ${vaultAddress} ${UNDERLYING_ASSET} "${VAULT_NAME}" "${VAULT_SYMBOL}" ${OPERATOR_ADDRESS} ${FULFILLMENT_DELAY}`);

  return vaultAddress;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
