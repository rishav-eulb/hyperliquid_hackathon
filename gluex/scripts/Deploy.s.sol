// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/HyperYieldVault.sol";
import "../contracts/VaultManager.sol";

/**
 * @title DeployScript
 * @notice Deployment script for HyperYield Optimizer contracts
 */
contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Get USDC address from environment or use default testnet address
        // HyperEVM Testnet USDC: 0x6D1Cb5c1d568Ff737a6E917dd1Fb0Ec2e92E1a5e (example - verify actual address)
        address usdc = vm.envOr("USDC_ADDRESS", address(0x6D1Cb5c1d568Ff737a6E917dd1Fb0Ec2e92E1a5e));
        
        console.log("Deploying contracts with account:", deployer);
        console.log("Account balance:", deployer.balance);
        console.log("Using USDC address:", usdc);
        
        require(usdc != address(0), "USDC address cannot be zero");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy HyperYieldVault
        console.log("Deploying HyperYieldVault...");
        HyperYieldVault vault = new HyperYieldVault(
            usdc,
            "HyperYield USDC",
            "hyUSDC"
        );
        console.log("HyperYieldVault deployed at:", address(vault));
        
        // Deploy VaultManager
        console.log("Deploying VaultManager...");
        VaultManager manager = new VaultManager(
            address(vault),
            usdc
        );
        console.log("VaultManager deployed at:", address(manager));
        
        // Configure vault with manager
        console.log("Setting VaultManager in HyperYieldVault...");
        vault.setVaultManager(address(manager));
        
        // Authorize deployer as bot
        console.log("Authorizing deployer as optimizer bot...");
        manager.authorizeBot(deployer);
        
        vm.stopBroadcast();
        
        console.log("\n=== Deployment Summary ===");
        console.log("HyperYieldVault:", address(vault));
        console.log("VaultManager:", address(manager));
        console.log("\nAdd these to your .env file:");
        console.log("VAULT_ADDRESS=", address(vault));
        console.log("MANAGER_ADDRESS=", address(manager));
        console.log("\nGlueX Vaults whitelisted:");
        address[] memory gluexVaults = manager.getGluexVaults();
        for (uint256 i = 0; i < gluexVaults.length; i++) {
            console.log("  -", gluexVaults[i]);
        }
    }
}
