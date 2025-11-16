"""
GlueX API Client
Handles interactions with GlueX Yields API and Router API
"""

import requests
import time
import hmac
import hashlib
import json
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class YieldData:
    """Represents yield information for a vault"""
    vault_address: str
    apy: float
    tvl: float
    risk_score: float
    timestamp: int


@dataclass
class SwapQuote:
    """Represents a swap quote from GlueX Router"""
    input_token: str
    output_token: str
    input_amount: str
    output_amount: str
    min_output_amount: str
    router: str
    calldata: str
    value: str


class GlueXClient:
    """Client for interacting with GlueX APIs"""
    
    YIELDS_API_BASE = "https://yield-api.gluex.xyz"
    ROUTER_API_BASE = "https://router-api.gluex.xyz"
    
    def __init__(self, api_key: str, api_secret: str):
        """
        Initialize GlueX client
        
        Args:
            api_key: GlueX API key
            api_secret: GlueX API secret
        """
        self.api_key = api_key
        self.api_secret = api_secret
        self.session = requests.Session()
        self.session.headers.update({
            "Content-Type": "application/json",
            "X-API-Key": api_key
        })
    
    def _generate_signature(self, data: Dict) -> str:
        """Generate HMAC signature for request"""
        message = json.dumps(data, sort_keys=True)
        signature = hmac.new(
            self.api_secret.encode(),
            message.encode(),
            hashlib.sha256
        ).hexdigest()
        return signature
    
    def get_historical_apy(
        self,
        lp_token_address: str,
        chain: str = "hyperevm"
    ) -> Optional[Dict]:
        """
        Get historical APY for a liquidity pool/vault
        
        Args:
            lp_token_address: Address of the LP token or vault
            chain: Blockchain identifier (default: hyperevm)
            
        Returns:
            Dict containing APY data or None on error
        """
        endpoint = f"{self.YIELDS_API_BASE}/historical-apy"
        payload = {
            "lp_token_address": lp_token_address,
            "chain": chain
        }
        
        try:
            response = self.session.post(endpoint, json=payload)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Error fetching historical APY: {e}")
            return None
    
    def get_diluted_apy(
        self,
        lp_token_address: str,
        amount: str,
        chain: str = "hyperevm"
    ) -> Optional[Dict]:
        """
        Get diluted APY based on deposit amount
        
        Args:
            lp_token_address: Address of the LP token or vault
            amount: Deposit amount in smallest units
            chain: Blockchain identifier
            
        Returns:
            Dict containing diluted APY data or None on error
        """
        endpoint = f"{self.YIELDS_API_BASE}/diluted-apy"
        payload = {
            "lp_token_address": lp_token_address,
            "chain": chain,
            "amount": amount
        }
        
        try:
            response = self.session.post(endpoint, json=payload)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Error fetching diluted APY: {e}")
            return None
    
    def get_multiple_vault_yields(
        self,
        vault_addresses: List[str],
        amount: str = "1000000000000",  # Default: 1M USDC (6 decimals = 1e12)
        chain: str = "hyperevm"
    ) -> List[YieldData]:
        """
        Get yield data for multiple vaults
        
        Args:
            vault_addresses: List of vault addresses
            amount: Amount to use for diluted APY calculation
            chain: Blockchain identifier
            
        Returns:
            List of YieldData objects
        """
        yield_data_list = []
        
        for vault_address in vault_addresses:
            try:
                # Get historical APY
                hist_data = self.get_historical_apy(vault_address, chain)
                
                # Get diluted APY for given amount
                diluted_data = self.get_diluted_apy(vault_address, amount, chain)
                
                if hist_data and diluted_data:
                    # Extract relevant data (structure depends on actual API response)
                    # This is a template - adjust based on actual API response format
                    apy = diluted_data.get('apy', 0) if diluted_data else hist_data.get('apy', 0)
                    tvl = hist_data.get('tvl', 0)
                    
                    yield_data = YieldData(
                        vault_address=vault_address,
                        apy=float(apy),
                        tvl=float(tvl),
                        risk_score=self._calculate_risk_score(apy, tvl),
                        timestamp=int(time.time())
                    )
                    yield_data_list.append(yield_data)
                    
                    logger.info(f"Vault {vault_address[:10]}...: APY={apy}%, TVL=${tvl:,.0f}")
                    
            except Exception as e:
                logger.error(f"Error processing vault {vault_address}: {e}")
                continue
        
        return yield_data_list
    
    def get_router_quote(
        self,
        input_token: str,
        output_token: str,
        input_amount: str,
        input_sender: str,
        output_receiver: str,
        chain: str = "hyperevm",
        slippage: float = 0.5
    ) -> Optional[SwapQuote]:
        """
        Get a swap quote from GlueX Router
        
        Args:
            input_token: Input token address
            output_token: Output token address
            input_amount: Amount to swap (in smallest units)
            input_sender: Address sending the tokens
            output_receiver: Address receiving the tokens
            chain: Blockchain identifier
            slippage: Slippage tolerance in percentage (default: 0.5%)
            
        Returns:
            SwapQuote object or None on error
        """
        endpoint = f"{self.ROUTER_API_BASE}/quote"
        payload = {
            "chain": chain,
            "inputToken": input_token,
            "outputToken": output_token,
            "inputAmount": input_amount,
            "inputSender": input_sender,
            "outputReceiver": output_receiver,
            "slippage": slippage,
            "surgeProtection": True
        }
        
        try:
            response = self.session.post(endpoint, json=payload)
            response.raise_for_status()
            data = response.json()
            
            if data.get('statusCode') == 200:
                result = data['result']
                return SwapQuote(
                    input_token=result['inputToken'],
                    output_token=result['outputToken'],
                    input_amount=result['inputAmount'],
                    output_amount=result['outputAmount'],
                    min_output_amount=result['minOutputAmount'],
                    router=result['router'],
                    calldata=result['calldata'],
                    value=result['value']
                )
            else:
                logger.error(f"Router API error: {data}")
                return None
                
        except requests.exceptions.RequestException as e:
            logger.error(f"Error fetching router quote: {e}")
            return None
    
    def _calculate_risk_score(self, apy: float, tvl: float) -> float:
        """
        Calculate a simple risk score based on APY and TVL
        Higher TVL = lower risk, Higher APY = potentially higher risk
        
        Args:
            apy: Annual percentage yield
            tvl: Total value locked
            
        Returns:
            Risk score (0-100, lower is better)
        """
        # Simple heuristic: normalize and combine factors
        # This is a placeholder - in production, use more sophisticated risk models
        apy_risk = min(apy / 100, 1.0) * 50  # Cap at 100% APY for risk calculation
        tvl_safety = max(0, 50 - (tvl / 10_000_000) * 10)  # More TVL = less risk
        
        risk_score = apy_risk + tvl_safety
        return min(risk_score, 100)
    
    def calculate_sharpe_ratio(
        self,
        yield_data: YieldData,
        risk_free_rate: float = 0.05
    ) -> float:
        """
        Calculate Sharpe ratio for a vault
        
        Args:
            yield_data: Yield data for the vault
            risk_free_rate: Risk-free rate (default: 5%)
            
        Returns:
            Sharpe ratio (higher is better)
        """
        excess_return = (yield_data.apy / 100) - risk_free_rate
        
        # Use risk score as a proxy for volatility
        # Lower risk score = lower volatility
        volatility = yield_data.risk_score / 100
        
        if volatility == 0:
            return 0
        
        sharpe = excess_return / volatility
        return sharpe
    
    def find_best_yield_opportunity(
        self,
        vault_addresses: List[str],
        amount: str,
        optimize_for: str = "sharpe"  # "sharpe", "apy", or "safety"
    ) -> Optional[Tuple[str, YieldData, float]]:
        """
        Find the best yield opportunity among vaults
        
        Args:
            vault_addresses: List of vault addresses to compare
            amount: Amount to invest
            optimize_for: Optimization metric
            
        Returns:
            Tuple of (best_vault_address, yield_data, score) or None
        """
        yield_data_list = self.get_multiple_vault_yields(vault_addresses, amount)
        
        if not yield_data_list:
            return None
        
        best_vault = None
        best_score = -float('inf')
        
        for data in yield_data_list:
            if optimize_for == "sharpe":
                score = self.calculate_sharpe_ratio(data)
            elif optimize_for == "apy":
                score = data.apy
            elif optimize_for == "safety":
                score = -data.risk_score  # Lower risk = higher score
            else:
                score = self.calculate_sharpe_ratio(data)
            
            logger.info(f"Vault {data.vault_address[:10]}...: Score={score:.4f}")
            
            if score > best_score:
                best_score = score
                best_vault = (data.vault_address, data, score)
        
        return best_vault


def test_client():
    """Test function for GlueX client"""
    import os
    from dotenv import load_dotenv
    
    load_dotenv()
    
    api_key = os.getenv('GLUEX_API_KEY', 'test_key')
    api_secret = os.getenv('GLUEX_API_SECRET', 'test_secret')
    
    client = GlueXClient(api_key, api_secret)
    
    # Test vault addresses (GlueX vaults from task)
    vaults = [
        "0xe25514992597786e07872e6c5517fe1906c0cadd",
        "0xcdc3975df9d1cf054f44ed238edfb708880292ea",
        "0x8f9291606862eef771a97e5b71e4b98fd1fa216a",
        "0x9f75eac57d1c6f7248bd2aede58c95689f3827f7",
        "0x63cf7ee583d9954febf649ad1c40c97a6493b1be"
    ]
    
    print("Testing GlueX Client...")
    print("-" * 50)
    
    # Find best opportunity
    result = client.find_best_yield_opportunity(vaults, "1000000000000")
    
    if result:
        vault_addr, yield_data, score = result
        print(f"\nBest Opportunity:")
        print(f"  Vault: {vault_addr}")
        print(f"  APY: {yield_data.apy:.2f}%")
        print(f"  TVL: ${yield_data.tvl:,.0f}")
        print(f"  Sharpe Ratio: {score:.4f}")
    else:
        print("No yield data available")


if __name__ == "__main__":
    test_client()
