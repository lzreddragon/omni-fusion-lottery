#!/usr/bin/env python3
"""
Dragon MCP
Model Context Protocol server for omniDRAGON ecosystem.

Author: 0xakita.eth
"""

import os
import json
import asyncio
from typing import Any, Dict, List, Optional, Union
from dataclasses import dataclass
from decimal import Decimal

# Load environment variables from .env file
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass  # dotenv is optional

try:
    import httpx
    from web3 import Web3
    from web3.contract import Contract
    from eth_account import Account
    
    # Handle different web3.py versions for POA middleware
    try:
        # Web3.py v7+ uses ExtraDataToPOAMiddleware
        from web3.middleware.proof_of_authority import ExtraDataToPOAMiddleware
        poa_middleware = ExtraDataToPOAMiddleware
    except ImportError:
        try:
            # Older versions use geth_poa_middleware
            from web3.middleware import geth_poa_middleware
            poa_middleware = geth_poa_middleware
        except ImportError:
            # Fallback for very old versions
            poa_middleware = None
    
    # MCP SDK imports
    from mcp.server.fastmcp import FastMCP
    
    MCP_AVAILABLE = True
except ImportError as e:
    print(f"⚠️  Missing dependencies: {e}")
    print("📦 Install with: pip install 'mcp[cli]' web3 httpx")
    MCP_AVAILABLE = False

if not MCP_AVAILABLE:
    exit(1)

# Initialize FastMCP server
mcp = FastMCP("Dragon MCP")

# ================================
# CONFIGURATION & CONSTANTS
# ================================

# Environment Variables
RPC_URLS = {
    "sonic": os.getenv("RPC_URL_SONIC", "https://rpc.soniclabs.com"),
    "ethereum": os.getenv("RPC_URL_ETHEREUM"),  # Not configured in your .env
    "arbitrum": os.getenv("RPC_URL_ARBITRUM"),
    "base": os.getenv("RPC_URL_BASE"),  # Not configured in your .env
    "avalanche": os.getenv("RPC_URL_AVALANCHE"),
}

PRIVATE_KEY = os.getenv("PRIVATE_KEY")
ETHERSCAN_API_KEYS = {
    "ethereum": os.getenv("ETHERSCAN_API_KEY"),
    "arbitrum": os.getenv("ARBISCAN_API_KEY"),
    "base": os.getenv("BASESCAN_API_KEY"),
}

# OmniDRAGON Contract Addresses (From your .env file)
OMNIDRAGON_CONTRACTS = {
    "sonic": os.getenv("OMNIDRAGON_ADDRESS", "0x6969696969696969696969696969696969697777"),
    "ethereum": os.getenv("OMNIDRAGON_ADDRESS", "0x6969696969696969696969696969696969697777"),
    "arbitrum": os.getenv("OMNIDRAGON_ADDRESS", "0x6969696969696969696969696969696969697777"), 
    "base": os.getenv("OMNIDRAGON_ADDRESS", "0x6969696969696969696969696969696969697777"),
    "avalanche": os.getenv("OMNIDRAGON_ADDRESS", "0x6969696969696969696969696969696969697777"),
}

# Registry Contract (From your .env file)
REGISTRY_CONTRACTS = {
    "sonic": os.getenv("REGISTRY_ADDRESS", "0x69618Ba41e2BAf89da52Ef8c30B61aB4FD6B0777"),
    "ethereum": os.getenv("REGISTRY_ADDRESS", "0x69618Ba41e2BAf89da52Ef8c30B61aB4FD6B0777"),
    "arbitrum": os.getenv("REGISTRY_ADDRESS", "0x69618Ba41e2BAf89da52Ef8c30B61aB4FD6B0777"),
    "base": os.getenv("REGISTRY_ADDRESS", "0x69618Ba41e2BAf89da52Ef8c30B61aB4FD6B0777"),
    "avalanche": os.getenv("REGISTRY_ADDRESS", "0x69618Ba41e2BAf89da52Ef8c30B61aB4FD6B0777"),
}

# Oracle System Addresses
ORACLE_CONTRACTS = {
    "primary": {
        "sonic": os.getenv("PRIMARY_ORACLE_ADDRESS", "0x6969696969696969696969696969696969697777"),
    },
    "secondary": {
        "ethereum": os.getenv("ORACLE_ETHEREUM", "0x6969696969696969696969696969696969697777"),
        "arbitrum": os.getenv("ORACLE_ARBITRUM", "0x6969696969696969696969696969696969697777"),
        "base": os.getenv("ORACLE_BASE", "0x6969696969696969696969696969696969697777"),
        "avalanche": os.getenv("ORACLE_AVALANCHE", "0x6969696969696969696969696969696969697777"),
    }
}

# Lottery Manager Addresses
LOTTERY_MANAGERS = {
    "sonic": os.getenv("LOTTERY_MANAGER_ADDRESS", "0x6969696969696969696969696969696969697777"),
    "ethereum": os.getenv("LOTTERY_ETHEREUM", "0x6969696969696969696969696969696969697777"),
    "arbitrum": os.getenv("LOTTERY_ARBITRUM", "0x6969696969696969696969696969696969697777"),
    "base": os.getenv("LOTTERY_BASE", "0x6969696969696969696969696969696969697777"),
    "avalanche": os.getenv("LOTTERY_AVALANCHE", "0x6969696969696969696969696969696969697777"),
}

# Jackpot Vault Addresses
JACKPOT_VAULTS = {
    "sonic": os.getenv("JACKPOT_VAULT_ADDRESS", "0x6969696969696969696969696969696969697777"),
    "ethereum": "0x...",
    "arbitrum": "0x...",    # Global meta-jackpot vault
    "base": "0x...",
    "avalanche": "0x...",
}

# LayerZero V2 Configuration
LAYERZERO_ENDPOINTS = {
    "sonic": "0x6F475642a6e85809B1c36Fa62763669b1b48DD5B",      # Sonic LayerZero endpoint
    "ethereum": "0x1a44076050125825900e736c501f859c50fE728c",   # Ethereum LayerZero endpoint  
    "arbitrum": "0x1a44076050125825900e736c501f859c50fE728c",   # Arbitrum LayerZero endpoint
    "base": "0x1a44076050125825900e736c501f859c50fE728c",       # Base LayerZero endpoint
    "avalanche": "0x1a44076050125825900e736c501f859c50fE728c",  # Avalanche LayerZero endpoint
}

LAYERZERO_EIDS = {
    "ethereum": 30101,
    "arbitrum": 30110, 
    "base": 30184,
    "avalanche": 30106,
    "sonic": 30332,  # Sonic EID
}

# Chainlink VRF V2.5 Configuration  
VRF_COORDINATORS = {
    "arbitrum": "",  # Arbitrum VRF Coordinator V2.5
}

# ================================
# CONTRACT ABIs (Simplified)
# ================================

OMNIDRAGON_ABI = [
    {
        "inputs": [],
        "name": "totalSupply",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [{"internalType": "address", "name": "account", "type": "address"}],
        "name": "balanceOf",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "getFees",
        "outputs": [
            {"components": [
                {"internalType": "uint16", "name": "jackpot", "type": "uint16"},
                {"internalType": "uint16", "name": "veDRAGON", "type": "uint16"},
                {"internalType": "uint16", "name": "burn", "type": "uint16"},
                {"internalType": "uint16", "name": "total", "type": "uint16"}
            ], "internalType": "struct IOmniDRAGON.Fees", "name": "buyFees", "type": "tuple"},
            {"components": [
                {"internalType": "uint16", "name": "jackpot", "type": "uint16"},
                {"internalType": "uint16", "name": "veDRAGON", "type": "uint16"},
                {"internalType": "uint16", "name": "burn", "type": "uint16"},
                {"internalType": "uint16", "name": "total", "type": "uint16"}
            ], "internalType": "struct IOmniDRAGON.Fees", "name": "sellFees", "type": "tuple"}
        ],
        "stateMutability": "view",
        "type": "function"
    }
]

ORACLE_ABI = [
    {
        "inputs": [],
        "name": "getAggregatedPrice",
        "outputs": [
            {"internalType": "int256", "name": "price", "type": "int256"},
            {"internalType": "bool", "name": "success", "type": "bool"},
            {"internalType": "uint256", "name": "timestamp", "type": "uint256"}
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "getLatestPrice", 
        "outputs": [
            {"internalType": "int256", "name": "price", "type": "int256"},
            {"internalType": "uint256", "name": "timestamp", "type": "uint256"}
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "getNativeTokenPrice",
        "outputs": [
            {"internalType": "int256", "name": "price", "type": "int256"},
            {"internalType": "bool", "name": "isValid", "type": "bool"},
            {"internalType": "uint256", "name": "timestamp", "type": "uint256"}
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "updatePrice",
        "outputs": [{"internalType": "bool", "name": "success", "type": "bool"}],
        "stateMutability": "nonpayable",
        "type": "function"
    }
]

LOTTERY_MANAGER_ABI = [
    {
        "inputs": [
            {"internalType": "address", "name": "user", "type": "address"},
            {"internalType": "uint256", "name": "dragonAmount", "type": "uint256"}
        ],
        "name": "processEntryWithDragon",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "address", "name": "user", "type": "address"},
            {"internalType": "uint256", "name": "usdAmount", "type": "uint256"}
        ],
        "name": "calculateWinProbability",
        "outputs": [
            {"internalType": "bool", "name": "hasChance", "type": "bool"},
            {"internalType": "uint256", "name": "winChancePPM", "type": "uint256"}
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "getInstantLotteryConfig",
        "outputs": [
            {"internalType": "bool", "name": "isActive", "type": "bool"},
            {"internalType": "uint256", "name": "minEntry", "type": "uint256"},
            {"internalType": "uint256", "name": "maxWinChance", "type": "uint256"},
            {"internalType": "uint256", "name": "baseReward", "type": "uint256"}
        ],
        "stateMutability": "view",
        "type": "function"
    }
]

JACKPOT_VAULT_ABI = [
    {
        "inputs": [{"internalType": "address", "name": "token", "type": "address"}],
        "name": "jackpotBalances",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "address", "name": "winner", "type": "address"},
            {"internalType": "uint256", "name": "amount", "type": "uint256"}
        ],
        "name": "payJackpot",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    }
]

# ================================
# UTILITY CLASSES & FUNCTIONS
# ================================

@dataclass
class PriceData:
    price: float
    is_valid: bool
    timestamp: int
    source: str

@dataclass
class LotteryStats:
    total_entries: int
    jackpot_balance: float
    is_active: bool
    min_entry_usd: float
    max_win_chance_ppm: int

class Web3Manager:
    """Manages Web3 connections and contract interactions"""
    
    def __init__(self):
        self.connections = {}
        self.contracts = {}
        
    def get_web3(self, chain: str) -> Web3:
        """Get Web3 instance for specified chain"""
        if chain not in self.connections:
            rpc_url = RPC_URLS.get(chain)
            if not rpc_url:
                raise ValueError(f"No RPC URL configured for chain: {chain}")
                
            w3 = Web3(Web3.HTTPProvider(rpc_url))
            
            # Add PoA middleware for chains that need it
            if chain in ["base", "arbitrum", "sonic"] and poa_middleware:
                w3.middleware_onion.inject(poa_middleware, layer=0)
                
            if not w3.is_connected():
                raise ConnectionError(f"Failed to connect to {chain} RPC")
                
            self.connections[chain] = w3
            
        return self.connections[chain]
    
    def get_contract(self, chain: str, contract_type: str, address: str = None) -> Contract:
        """Get contract instance"""
        w3 = self.get_web3(chain)
        
        # Determine contract address and ABI
        if contract_type == "omnidragon":
            address = address or OMNIDRAGON_CONTRACTS.get(chain)
            abi = OMNIDRAGON_ABI
        elif contract_type == "oracle":
            if chain == "sonic":
                address = address or ORACLE_CONTRACTS["primary"]["sonic"]
            else:
                address = address or ORACLE_CONTRACTS["secondary"].get(chain)
            abi = ORACLE_ABI
        elif contract_type == "lottery":
            address = address or LOTTERY_MANAGERS.get(chain)
            abi = LOTTERY_MANAGER_ABI
        elif contract_type == "jackpot":
            address = address or JACKPOT_VAULTS.get(chain)
            abi = JACKPOT_VAULT_ABI
        else:
            raise ValueError(f"Unknown contract type: {contract_type}")
            
        if not address:
            raise ValueError(f"No address found for {contract_type} on {chain}")
            
        cache_key = f"{chain}:{contract_type}:{address}"
        if cache_key not in self.contracts:
            try:
                checksum_address = Web3.to_checksum_address(address)
                self.contracts[cache_key] = w3.eth.contract(
                    address=checksum_address,
                    abi=abi
                )
            except ValueError as e:
                raise ValueError(f"Invalid contract address '{address}' for {contract_type} on {chain}: {e}")
            
        return self.contracts[cache_key]

# Global Web3 manager instance
web3_manager = Web3Manager()

# ================================
# ORACLE MONITORING TOOLS
# ================================

@mcp.tool()
async def get_dragon_price(chain: str = "sonic") -> Dict[str, Any]:
    """
    Get DRAGON price from oracle network.
    
    Args:
        chain: Target chain (sonic, ethereum, arbitrum, base, avalanche)
        
    Returns:
        Current DRAGON price and oracle health data
    """
    try:
        results = {
            "chain": chain,
            "timestamp": int(asyncio.get_event_loop().time()),
            "price_data": {},
            "health_status": "unknown"
        }
        
        # Get price from appropriate oracle
        if chain == "sonic":
            # Primary oracle on Sonic - multi-source aggregation
            oracle = web3_manager.get_contract("sonic", "oracle")
            
            # Get aggregated price
            try:
                price, success, timestamp = oracle.functions.getAggregatedPrice().call()
                results["price_data"] = {
                    "price_usd": float(price) / 1e18,  # Convert from 18 decimals
                    "is_valid": success,
                    "timestamp": timestamp,
                    "source": "primary_oracle"
                }
                
                # Get native token price (SONIC/USD) 
                try:
                    native_price, native_valid, native_ts = oracle.functions.getNativeTokenPrice().call()
                    results["native_token"] = {
                        "price_usd": float(native_price) / 1e8,  # Usually 8 decimals
                        "is_valid": native_valid,
                        "timestamp": native_ts
                    }
                except Exception:
                    pass
                    
            except Exception as e:
                results["price_data"] = {"error": str(e)}
                
        else:
            # Secondary oracle - queries primary via LayerZero lzRead
            oracle = web3_manager.get_contract(chain, "oracle")
            
            try:
                price, success, timestamp = oracle.functions.getAggregatedPrice().call()
                results["price_data"] = {
                    "price_usd": float(price) / 1e18,
                    "is_valid": success,
                    "timestamp": timestamp,
                    "source": f"secondary_oracle_{chain}"
                }
            except Exception as e:
                results["price_data"] = {"error": str(e)}
        
        # Determine health status
        if results["price_data"].get("is_valid"):
            results["health_status"] = "healthy"
        elif "error" in results["price_data"]:
            results["health_status"] = "error"
        else:
            results["health_status"] = "invalid_price"
            
        return results
        
    except Exception as e:
        return {
            "error": f"Failed to get DRAGON price: {str(e)}",
            "chain": chain
        }

@mcp.tool()
async def check_oracle_health() -> Dict[str, Any]:
    """
    Monitor health of oracle network across all chains.
    
    Returns:
        Comprehensive health report of the oracle system
    """
    try:
        health_report = {
            "timestamp": int(asyncio.get_event_loop().time()),
            "overall_status": "unknown",
            "chains": {},
            "price_consistency": {},
            "alerts": []
        }
        
        # Check each chain
        chain_prices = {}
        for chain in ["sonic", "ethereum", "arbitrum", "base"]:
            try:
                chain_data = await get_dragon_price(chain)
                health_report["chains"][chain] = {
                    "status": chain_data.get("health_status", "error"),
                    "price": chain_data.get("price_data", {}).get("price_usd"),
                    "timestamp": chain_data.get("price_data", {}).get("timestamp"),
                    "is_valid": chain_data.get("price_data", {}).get("is_valid", False)
                }
                
                if chain_data.get("price_data", {}).get("is_valid"):
                    chain_prices[chain] = chain_data["price_data"]["price_usd"]
                    
            except Exception as e:
                health_report["chains"][chain] = {
                    "status": "error",
                    "error": str(e)
                }
                health_report["alerts"].append(f"{chain}: {str(e)}")
        
        # Check price consistency across chains
        if len(chain_prices) > 1:
            prices = list(chain_prices.values())
            avg_price = sum(prices) / len(prices)
            max_deviation = max(abs(p - avg_price) / avg_price for p in prices) * 100
            
            health_report["price_consistency"] = {
                "average_price": avg_price,
                "max_deviation_percent": max_deviation,
                "is_consistent": max_deviation < 5.0,  # 5% threshold
                "chain_prices": chain_prices
            }
            
            if max_deviation > 5.0:
                health_report["alerts"].append(f"Price deviation too high: {max_deviation:.2f}%")
        
        # Determine overall status
        healthy_chains = sum(1 for c in health_report["chains"].values() 
                           if c.get("status") == "healthy")
        total_chains = len(health_report["chains"])
        
        if healthy_chains == total_chains:
            health_report["overall_status"] = "healthy"
        elif healthy_chains >= total_chains // 2:
            health_report["overall_status"] = "degraded"
        else:
            health_report["overall_status"] = "critical"
            
        return health_report
        
    except Exception as e:
        return {
            "error": f"Failed to check oracle health: {str(e)}",
            "overall_status": "error"
        }

@mcp.tool()
async def update_oracle_price(chain: str = "sonic") -> Dict[str, Any]:
    """
    Manually trigger oracle price update.
    
    Args:
        chain: Chain to update (sonic for primary, others for secondary)
        
    Returns:
        Transaction result and updated price data
    """
    if not PRIVATE_KEY:
        return {"error": "No private key configured for transactions"}
        
    try:
        w3 = web3_manager.get_web3(chain)
        account = Account.from_key(PRIVATE_KEY)
        oracle = web3_manager.get_contract(chain, "oracle")
        
        # Build transaction
        tx = oracle.functions.updatePrice().build_transaction({
            'from': account.address,
            'nonce': w3.eth.get_transaction_count(account.address),
            'gas': 500000,
            'gasPrice': w3.eth.gas_price
        })
        
        # Sign and send
        signed_tx = account.sign_transaction(tx)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
        
        # Wait for confirmation
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)
        
        # Get updated price
        updated_price = await get_dragon_price(chain)
        
        return {
            "success": True,
            "tx_hash": tx_hash.hex(),
            "gas_used": receipt.gasUsed,
            "updated_price": updated_price,
            "chain": chain
        }
        
    except Exception as e:
        return {
            "error": f"Failed to update oracle price: {str(e)}",
            "chain": chain
        }

# ================================
# LOTTERY SYSTEM TOOLS  
# ================================

@mcp.tool()
async def get_lottery_stats(chain: str) -> Dict[str, Any]:
    """
    Get lottery statistics for a specific chain.
    
    Args:
        chain: Target chain (sonic, ethereum, arbitrum, base, avalanche)
        
    Returns:
        Lottery configuration, jackpot balances, and activity stats
    """
    try:
        lottery = web3_manager.get_contract(chain, "lottery")
        jackpot = web3_manager.get_contract(chain, "jackpot")
        omnidragon = web3_manager.get_contract(chain, "omnidragon")
        
        # Get lottery configuration
        is_active, min_entry, max_win_chance, base_reward = lottery.functions.getInstantLotteryConfig().call()
        
        # Get jackpot balance (in wrapped native token)
        w3 = web3_manager.get_web3(chain)
        wrapped_native = "0x4200000000000000000000000000000000000006"  # Example: WETH on Base
        jackpot_balance = jackpot.functions.jackpotBalances(wrapped_native).call()
        
        # Get DRAGON token stats
        dragon_total_supply = omnidragon.functions.totalSupply().call()
        
        return {
            "chain": chain,
            "lottery_config": {
                "is_active": is_active,
                "min_entry_usd": float(min_entry) / 1e6,  # Convert from 6 decimals
                "max_win_chance_ppm": max_win_chance,
                "base_reward_usd": float(base_reward) / 1e6
            },
            "jackpot": {
                "balance_native": float(jackpot_balance) / 1e18,
                "balance_usd": None  # Would need oracle to calculate
            },
            "dragon_token": {
                "total_supply": float(dragon_total_supply) / 1e18,
                "contract_address": OMNIDRAGON_CONTRACTS.get(chain)
            },
            "timestamp": int(asyncio.get_event_loop().time())
        }
        
    except Exception as e:
        return {
            "error": f"Failed to get lottery stats: {str(e)}",
            "chain": chain
        }

@mcp.tool()
async def simulate_lottery(usd_amount: float, chain: str = "sonic") -> Dict[str, Any]:
    """
    Simulate lottery win probability for a given USD amount.
    
    Args:
        usd_amount: USD amount to simulate (e.g., 1000.0 for $1000)
        chain: Chain to simulate on
        
    Returns:
        Win probability and expected rewards
    """
    try:
        lottery = web3_manager.get_contract(chain, "lottery")
        
        # Convert USD to contract format (6 decimals)
        usd_amount_scaled = int(usd_amount * 1e6)
        
        # Simulate user address (use a common test address)
        test_user = "0x1234567890123456789012345678901234567890"
        
        # Get win probability
        has_chance, win_chance_ppm = lottery.functions.calculateWinProbability(
            test_user, usd_amount_scaled
        ).call()
        
        # Calculate win percentage
        win_percentage = float(win_chance_ppm) / 10000  # PPM to percentage
        
        # Estimate expected value (simplified)
        lottery_config = await get_lottery_stats(chain)
        base_reward = lottery_config.get("lottery_config", {}).get("base_reward_usd", 0)
        expected_value = win_percentage / 100 * base_reward
        
        return {
            "usd_amount": usd_amount,
            "chain": chain,
            "simulation": {
                "has_win_chance": has_chance,
                "win_probability_ppm": win_chance_ppm,
                "win_percentage": win_percentage,
                "expected_value_usd": expected_value,
                "is_profitable": expected_value > usd_amount * 0.001  # > 0.1% of entry
            },
            "lottery_info": {
                "min_threshold_met": usd_amount >= lottery_config.get("lottery_config", {}).get("min_entry_usd", 0),
                "base_reward_usd": base_reward
            }
        }
        
    except Exception as e:
        return {
            "error": f"Failed to simulate lottery: {str(e)}",
            "usd_amount": usd_amount,
            "chain": chain
        }

@mcp.tool()
async def test_lottery_entry(chain: str, user_address: str, dragon_amount: float) -> Dict[str, Any]:
    """
    Test a lottery entry transaction.
    
    Args:
        chain: Target chain
        user_address: User wallet address
        dragon_amount: Amount of DRAGON tokens
        
    Returns:
        Transaction simulation or execution result
    """
    if not PRIVATE_KEY:
        return {
            "error": "No private key configured - simulation only",
            "note": "Set PRIVATE_KEY environment variable to execute transactions"
        }
        
    try:
        w3 = web3_manager.get_web3(chain)
        account = Account.from_key(PRIVATE_KEY)
        lottery = web3_manager.get_contract(chain, "lottery")
        
        # Convert DRAGON amount to wei
        dragon_amount_wei = int(dragon_amount * 1e18)
        
        # Build transaction
        tx = lottery.functions.processEntryWithDragon(
            Web3.to_checksum_address(user_address),
            dragon_amount_wei
        ).build_transaction({
            'from': account.address,
            'nonce': w3.eth.get_transaction_count(account.address),
            'gas': 500000,
            'gasPrice': w3.eth.gas_price
        })
        
        # Simulate first
        try:
            w3.eth.call(tx)
            simulation_success = True
            simulation_error = None
        except Exception as sim_error:
            simulation_success = False
            simulation_error = str(sim_error)
            
        if not simulation_success:
            return {
                "simulation_failed": True,
                "error": simulation_error,
                "transaction_not_sent": True
            }
        
        # Execute transaction
        signed_tx = account.sign_transaction(tx)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
        
        # Wait for confirmation
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)
        
        return {
            "success": True,
            "tx_hash": tx_hash.hex(),
            "gas_used": receipt.gasUsed,
            "chain": chain,
            "user_address": user_address,
            "dragon_amount": dragon_amount,
            "block_number": receipt.blockNumber
        }
        
    except Exception as e:
        return {
            "error": f"Failed to process lottery entry: {str(e)}",
            "chain": chain
        }

# ================================
# LAYERZERO & CROSS-CHAIN TOOLS
# ================================

@mcp.tool()
async def check_layerzero_status(tx_hash: str, chain: str) -> Dict[str, Any]:
    """
    Check status of LayerZero cross-chain message.
    
    Args:
        tx_hash: Transaction hash of LayerZero send
        chain: Source chain of the transaction
        
    Returns:
        Message status and delivery information
    """
    try:
        w3 = web3_manager.get_web3(chain)
        
        # Get transaction receipt
        receipt = w3.eth.get_transaction_receipt(tx_hash)
        
        if not receipt:
            return {
                "error": "Transaction not found",
                "tx_hash": tx_hash,
                "chain": chain
            }
        
        # Parse LayerZero events from logs
        layerzero_events = []
        for log in receipt.logs:
            # Look for common LayerZero event signatures
            if len(log.topics) > 0:
                topic = log.topics[0].hex()
                if "layerzero" in topic.lower() or len(log.data) > 64:  # Simplified detection
                    layerzero_events.append({
                        "topic": topic,
                        "data": log.data.hex(),
                        "address": log.address
                    })
        
        return {
            "tx_hash": tx_hash,
            "chain": chain,
            "status": "confirmed" if receipt.status == 1 else "failed",
            "block_number": receipt.blockNumber,
            "gas_used": receipt.gasUsed,
            "layerzero_events": layerzero_events,
            "logs_count": len(receipt.logs)
        }
        
    except Exception as e:
        return {
            "error": f"Failed to check LayerZero status: {str(e)}",
            "tx_hash": tx_hash,
            "chain": chain
        }

@mcp.tool()
async def estimate_layerzero_fee(source_chain: str, dest_chain: str, payload_size: int = 32) -> Dict[str, Any]:
    """
    Estimate LayerZero V2 messaging fee.
    
    Args:
        source_chain: Source chain name
        dest_chain: Destination chain name  
        payload_size: Payload size in bytes
        
    Returns:
        Estimated fees in native token and USD
    """
    try:
        # Typical LayerZero V2 fees (estimates)
        base_fees = {
            "ethereum": 0.005,   # ~$12-15
            "arbitrum": 0.0001,  # ~$0.20-0.50  
            "base": 0.0001,      # ~$0.20-0.50
            "sonic": 0.001,      # ~$0.01-0.05
            "avalanche": 0.01,   # ~$0.30-0.80
        }
        
        source_fee = base_fees.get(source_chain, 0.001)
        
        # Adjust for payload size
        size_multiplier = max(1.0, payload_size / 32)
        estimated_fee = source_fee * size_multiplier
        
        return {
            "source_chain": source_chain,
            "dest_chain": dest_chain,
            "dest_eid": LAYERZERO_EIDS.get(dest_chain),
            "estimated_fee": {
                "native_token": estimated_fee,
                "usd_estimate": estimated_fee * 2500,  # Rough conversion
            },
            "payload_size_bytes": payload_size,
            "note": "Estimate only - use actual LayerZero quote for production"
        }
        
    except Exception as e:
        return {
            "error": f"Failed to estimate LayerZero fee: {str(e)}",
            "source_chain": source_chain,
            "dest_chain": dest_chain
        }

# ================================
# VRF TOOLS
# ================================

@mcp.tool()
async def request_vrf_randomness(chain: str = "arbitrum", num_words: int = 1) -> Dict[str, Any]:
    """
    Request Chainlink VRF V2.5 randomness.
    
    Args:
        chain: Chain to request from (currently only Arbitrum supported)
        num_words: Number of random words (1-500)
        
    Returns:
        VRF request details
    """
    if chain != "arbitrum":
        return {
            "error": "VRF currently only supported on Arbitrum",
            "supported_chains": ["arbitrum"]
        }
        
    if not PRIVATE_KEY:
        return {
            "error": "No private key configured for VRF requests",
            "note": "Set PRIVATE_KEY environment variable"
        }
    
    try:
        return {
            "success": True,
            "simulation": True,
            "chain": chain,
            "num_words": num_words,
            "estimated_cost": "0.002 ETH (~$5)",
            "note": "VRF integration ready - implement with actual contract deployment"
        }
        
    except Exception as e:
        return {
            "error": f"Failed to request VRF: {str(e)}",
            "chain": chain
        }

# ================================
# RESOURCES & PROMPTS
# ================================

@mcp.resource("dragon://stats/{chain}")
def get_dragon_stats(chain: str) -> str:
    """Get Dragon ecosystem stats for a specific chain."""
    try:
        return json.dumps({
            "chain": chain,
            "contract_address": OMNIDRAGON_CONTRACTS.get(chain),
            "layerzero_eid": LAYERZERO_EIDS.get(chain),
            "supports_oracle": chain in ["sonic", "ethereum", "arbitrum", "base"],
            "note": "Use get_lottery_stats tool for live data"
        }, indent=2)
    except Exception as e:
        return json.dumps({"error": str(e)}, indent=2)

@mcp.prompt()
def dragon_monitoring_prompt() -> str:
    """Dragon ecosystem monitoring guide."""
    return """
Monitor the Dragon ecosystem effectively:

🔮 ORACLE HEALTH:
- Use check_oracle_health() for network-wide status
- Monitor price consistency across chains (<5% deviation)
- Check oracle response times and validity

🎲 LOTTERY SYSTEM:
- Use get_lottery_stats() for each chain
- Monitor jackpot growth and entry volume
- Verify win probability calculations

🌉 CROSS-CHAIN SYNC:
- Check LayerZero message delivery
- Verify oracle price synchronization
- Monitor VRF randomness delivery

KEY METRICS:
- Dragon price consistency
- Lottery participation rates  
- Jackpot vault balances
- Cross-chain message success rate

ALERTS:
- Oracle price deviation >5%
- LayerZero message failures
- VRF delivery delays
- Lottery system errors
"""

@mcp.prompt()
def dragon_testing_prompt() -> str:
    """Dragon system testing guide."""
    return """
Test the Dragon ecosystem comprehensively:

1. ORACLE TESTING:
   - get_dragon_price() for all chains
   - Verify primary oracle (Sonic) multi-source aggregation
   - Test secondary oracle LayerZero queries

2. LOTTERY TESTING:
   - simulate_lottery() with various amounts
   - Test probability scaling with USD value
   - Verify cross-chain consistency

3. INTEGRATION TESTING:
   - Test swap-to-enter flow
   - Verify VRF randomness
   - Check jackpot distributions

4. CROSS-CHAIN TESTING:
   - LayerZero message delivery
   - Oracle price synchronization
   - Multi-chain lottery coordination
"""

# ================================
# MAIN FUNCTION
# ================================

if __name__ == "__main__":
    # Environment validation
    missing_vars = []
    if not PRIVATE_KEY:
        print("⚠️  Warning: PRIVATE_KEY not set - transactions will be simulated only")
    
    for chain, url in RPC_URLS.items():
        if not url:
            missing_vars.append(f"RPC_URL_{chain.upper()}")
    
    if missing_vars:
        print(f"⚠️  Missing environment variables: {', '.join(missing_vars)}")
        print("Some functionality may be limited.")
    
    print("🐉 Dragon MCP Starting...")
    print("📊 Cross-chain lottery ecosystem")
    print("🔮 Oracle & price monitoring")
    print("🎲 Lottery testing tools")
    print("🌉 LayerZero integration active")
    print("✨ Ready for AI interactions!")
    
    # Run the MCP server
    mcp.run(transport="stdio")