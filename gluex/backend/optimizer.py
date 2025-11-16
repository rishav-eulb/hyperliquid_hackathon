"""
HyperYield Optimizer - Main Service
Monitors yields and triggers rebalancing operations
"""

import os
import time
import logging
from typing import Optional, Dict
from dataclasses import dataclass
from web3 import Web3
from eth_account import Account
from dotenv import load_dotenv

from gluex_client import GlueXClient, YieldData

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@dataclass
class OptimizerConfig:
    """Configuration for the optimizer"""
    rpc_url: str
    private_key: str
    vault_address: str
    manager_address: str
    gluex_api_key: str
    gluex_api_secret: str
    check_interval: int = 300  # 5 minutes
    min_apy_diff: float = 0.5  # 0.5% minimum difference
    gas_price_gwei: int = 1  # HyperEVM typically has low gas
    optimize_for: str = "sharpe"  # sharpe, apy, or safety


class HyperYieldOptimizer:
    """Main optimizer service"""
    
    # GlueX vault addresses from task
    GLUEX_VAULTS = [
        "0xe25514992597786e07872e6c5517fe1906c0cadd",
        "0xcdc3975df9d1cf054f44ed238edfb708880292ea",
        "0x8f9291606862eef771a97e5b71e4b98fd1fa216a",
        "0x9f75eac57d1c6f7248bd2aede58c95689f3827f7",
        "0x63cf7ee583d9954febf649ad1c40c97a6493b1be"
    ]
    
    # Vault Manager ABI (simplified)
    MANAGER_ABI = [
        {
            "inputs": [
                {"name": "targetVault", "type": "address"},
                {"name": "amount", "type": "uint256"},
                {"name": "routerAddress", "type": "address"},
                {"name": "swapCalldata", "type": "bytes"}
            ],
            "name": "executeRebalance",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
        },
        {
            "inputs": [],
            "name": "getCurrentAllocation",
            "outputs": [
                {"name": "vault", "type": "address"},
                {"name": "amount", "type": "uint256"},
                {"name": "lastUpdate", "type": "uint256"}
            ],
            "stateMutability": "view",
            "type": "function"
        },
        {
            "inputs": [],
            "name": "canRebalance",
            "outputs": [{"name": "", "type": "bool"}],
            "stateMutability": "view",
            "type": "function"
        }
    ]
    
    def __init__(self, config: OptimizerConfig):
        """Initialize the optimizer"""
        self.config = config
        
        # Initialize Web3
        self.w3 = Web3(Web3.HTTPProvider(config.rpc_url))
        self.account = Account.from_key(config.private_key)
        
        logger.info(f"Optimizer account: {self.account.address}")
        
        # Initialize contracts
        self.manager_contract = self.w3.eth.contract(
            address=Web3.to_checksum_address(config.manager_address),
            abi=self.MANAGER_ABI
        )
        
        # Initialize GlueX client
        self.gluex_client = GlueXClient(
            config.gluex_api_key,
            config.gluex_api_secret
        )
        
        # State tracking
        self.current_vault: Optional[str] = None
        self.current_apy: float = 0
        self.last_check_time: int = 0
        self.rebalance_count: int = 0
        
        logger.info("HyperYield Optimizer initialized successfully")
    
    def get_current_allocation(self) -> Dict:
        """Get current vault allocation from contract"""
        try:
            vault, amount, last_update = self.manager_contract.functions.getCurrentAllocation().call()
            return {
                'vault': vault,
                'amount': amount,
                'last_update': last_update
            }
        except Exception as e:
            logger.error(f"Error getting current allocation: {e}")
            return {'vault': None, 'amount': 0, 'last_update': 0}
    
    def can_rebalance(self) -> bool:
        """Check if rebalancing is allowed (cooldown period)"""
        try:
            return self.manager_contract.functions.canRebalance().call()
        except Exception as e:
            logger.error(f"Error checking rebalance status: {e}")
            return False
    
    def find_best_opportunity(self) -> Optional[tuple]:
        """Find the best yield opportunity across whitelisted vaults"""
        logger.info("Scanning vaults for best opportunity...")
        
        # Get total assets in vault (for diluted APY calculation)
        allocation = self.get_current_allocation()
        amount = str(allocation['amount']) if allocation['amount'] > 0 else "1000000000000"
        
        # Find best opportunity using GlueX API
        result = self.gluex_client.find_best_yield_opportunity(
            self.GLUEX_VAULTS,
            amount,
            self.config.optimize_for
        )
        
        return result
    
    def should_rebalance(
        self,
        current_vault: str,
        current_apy: float,
        new_vault: str,
        new_apy: float
    ) -> bool:
        """Determine if rebalancing is worthwhile"""
        # Don't rebalance to same vault
        if current_vault and current_vault.lower() == new_vault.lower():
            logger.info("Already in optimal vault")
            return False
        
        # Check if APY difference meets threshold
        apy_improvement = new_apy - current_apy
        if apy_improvement < self.config.min_apy_diff:
            logger.info(
                f"APY improvement ({apy_improvement:.2f}%) below threshold "
                f"({self.config.min_apy_diff}%)"
            )
            return False
        
        # Check cooldown period
        if not self.can_rebalance():
            logger.info("Rebalance cooldown period active")
            return False
        
        logger.info(f"Rebalancing recommended: +{apy_improvement:.2f}% APY improvement")
        return True
    
    def execute_rebalance(
        self,
        target_vault: str,
        amount: int,
        swap_calldata: bytes = b''
    ) -> bool:
        """Execute rebalancing transaction"""
        try:
            logger.info(f"Executing rebalance to {target_vault[:10]}...")
            
            # Build transaction
            tx = self.manager_contract.functions.executeRebalance(
                Web3.to_checksum_address(target_vault),
                amount,
                "0x0000000000000000000000000000000000000000",  # No router for direct transfers
                swap_calldata
            ).build_transaction({
                'from': self.account.address,
                'gas': 500000,
                'gasPrice': self.w3.to_wei(self.config.gas_price_gwei, 'gwei'),
                'nonce': self.w3.eth.get_transaction_count(self.account.address)
            })
            
            # Sign and send transaction
            signed_tx = self.account.sign_transaction(tx)
            tx_hash = self.w3.eth.send_raw_transaction(signed_tx.rawTransaction)
            
            logger.info(f"Transaction sent: {tx_hash.hex()}")
            
            # Wait for confirmation
            receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)
            
            if receipt['status'] == 1:
                logger.info("✅ Rebalancing successful!")
                self.rebalance_count += 1
                return True
            else:
                logger.error("❌ Rebalancing transaction failed")
                return False
                
        except Exception as e:
            logger.error(f"Error executing rebalance: {e}")
            return False
    
    def run_optimization_cycle(self):
        """Run one optimization cycle"""
        logger.info("=" * 60)
        logger.info("Starting optimization cycle...")
        
        # Get current allocation
        allocation = self.get_current_allocation()
        current_vault = allocation['vault']
        current_amount = allocation['amount']
        
        if current_vault and current_vault != "0x0000000000000000000000000000000000000000":
            logger.info(f"Current vault: {current_vault[:10]}...")
            logger.info(f"Current amount: {current_amount / 1e6:.2f} USDC")
        else:
            logger.info("No current allocation")
            current_vault = None
        
        # Find best opportunity
        result = self.find_best_opportunity()
        
        if not result:
            logger.warning("No yield data available, skipping cycle")
            return
        
        target_vault, yield_data, score = result
        
        logger.info(f"Best opportunity: {target_vault[:10]}...")
        logger.info(f"  APY: {yield_data.apy:.2f}%")
        logger.info(f"  Score: {score:.4f}")
        logger.info(f"  TVL: ${yield_data.tvl:,.0f}")
        
        # Determine if rebalancing is needed
        if self.should_rebalance(
            current_vault or "",
            self.current_apy,
            target_vault,
            yield_data.apy
        ):
            # Use current amount or default minimum
            rebalance_amount = current_amount if current_amount > 0 else 1_000_000_000  # 1000 USDC
            
            # Execute rebalancing
            if self.execute_rebalance(target_vault, rebalance_amount):
                self.current_vault = target_vault
                self.current_apy = yield_data.apy
                logger.info(f"📊 Total rebalances: {self.rebalance_count}")
        
        self.last_check_time = int(time.time())
    
    def run(self):
        """Main optimizer loop"""
        logger.info("🚀 HyperYield Optimizer started")
        logger.info(f"Check interval: {self.config.check_interval}s")
        logger.info(f"Min APY difference: {self.config.min_apy_diff}%")
        logger.info(f"Optimization strategy: {self.config.optimize_for}")
        logger.info("=" * 60)
        
        while True:
            try:
                self.run_optimization_cycle()
                
                logger.info(f"Sleeping for {self.config.check_interval}s...")
                time.sleep(self.config.check_interval)
                
            except KeyboardInterrupt:
                logger.info("Shutting down optimizer...")
                break
            except Exception as e:
                logger.error(f"Error in optimization cycle: {e}", exc_info=True)
                logger.info("Waiting 60s before retry...")
                time.sleep(60)
        
        logger.info("HyperYield Optimizer stopped")


def main():
    """Main entry point"""
    load_dotenv()
    
    # Load configuration
    config = OptimizerConfig(
        rpc_url=os.getenv('HYPEREVM_RPC_URL', 'https://api.hyperliquid-testnet.xyz/evm'),
        private_key=os.getenv('PRIVATE_KEY', ''),
        vault_address=os.getenv('VAULT_ADDRESS', ''),
        manager_address=os.getenv('MANAGER_ADDRESS', ''),
        gluex_api_key=os.getenv('GLUEX_API_KEY', ''),
        gluex_api_secret=os.getenv('GLUEX_API_SECRET', ''),
        check_interval=int(os.getenv('CHECK_INTERVAL', '300')),
        min_apy_diff=float(os.getenv('MIN_APY_DIFF', '0.5')),
        optimize_for=os.getenv('OPTIMIZE_FOR', 'sharpe')
    )
    
    # Validate configuration
    if not config.private_key:
        logger.error("PRIVATE_KEY not set in environment")
        return
    
    if not config.manager_address:
        logger.error("MANAGER_ADDRESS not set in environment")
        return
    
    if not config.gluex_api_key:
        logger.error("GLUEX_API_KEY not set in environment")
        return
    
    # Create and run optimizer
    optimizer = HyperYieldOptimizer(config)
    optimizer.run()


if __name__ == "__main__":
    main()
