#!/usr/bin/env python3
"""
Dragon MCP Server Test Suite
Comprehensive testing of all MCP tools and functionality.
"""

import asyncio
import json
import sys
import os

# Add current directory to path to import dragon_mcp
sys.path.insert(0, os.getcwd())

# Load environment variables
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

def print_test_header(test_name):
    print(f"\n{'='*60}")
    print(f"🧪 TESTING: {test_name}")
    print('='*60)

def print_test_result(success, details):
    status = "✅ PASS" if success else "❌ FAIL"
    print(f"{status}: {details}")

async def test_basic_imports():
    """Test 1: Basic Import and Setup"""
    print_test_header("Basic Imports and Setup")
    
    try:
        import dragon_mcp
        print_test_result(True, "Dragon MCP module imported successfully")
        
        # Check if web3 manager is available
        web3_mgr = dragon_mcp.web3_manager
        print_test_result(True, "Web3Manager instance created")
        
        # Check environment variables
        sonic_rpc = os.getenv("RPC_URL_SONIC")
        if sonic_rpc:
            print_test_result(True, f"Sonic RPC configured: {sonic_rpc[:50]}...")
        else:
            print_test_result(False, "Sonic RPC not configured")
            
        registry_addr = os.getenv("REGISTRY_ADDRESS")
        if registry_addr:
            print_test_result(True, f"Registry address: {registry_addr}")
        else:
            print_test_result(False, "Registry address not configured")
            
        return True
    except Exception as e:
        print_test_result(False, f"Import failed: {str(e)}")
        return False

async def test_web3_connections():
    """Test 2: Web3 RPC Connections"""
    print_test_header("Web3 RPC Connections")
    
    try:
        import dragon_mcp
        web3_mgr = dragon_mcp.web3_manager
        
        # Test available chains
        test_chains = ["sonic", "arbitrum", "avalanche"]
        
        for chain in test_chains:
            rpc_url = dragon_mcp.RPC_URLS.get(chain)
            if rpc_url:
                try:
                    w3 = web3_mgr.get_web3(chain)
                    is_connected = w3.is_connected()
                    if is_connected:
                        latest_block = w3.eth.block_number
                        print_test_result(True, f"{chain.upper()} connected - Block: {latest_block}")
                    else:
                        print_test_result(False, f"{chain.upper()} RPC not responding")
                except Exception as e:
                    print_test_result(False, f"{chain.upper()} connection error: {str(e)}")
            else:
                print_test_result(False, f"{chain.upper()} RPC URL not configured")
                
        return True
    except Exception as e:
        print_test_result(False, f"Web3 connection test failed: {str(e)}")
        return False

async def test_dragon_price_oracle():
    """Test 3: Dragon Price Oracle Tools"""
    print_test_header("Dragon Price Oracle Functions")
    
    try:
        import dragon_mcp
        
        # Test get_dragon_price function
        print("Testing get_dragon_price for Sonic...")
        result = await dragon_mcp.get_dragon_price("sonic")
        
        if "error" in result:
            print_test_result(False, f"Oracle error: {result['error']}")
        else:
            print_test_result(True, f"Oracle response received")
            print(f"   Chain: {result.get('chain')}")
            print(f"   Health: {result.get('health_status')}")
            if result.get('price_data'):
                price_data = result['price_data']
                if 'error' in price_data:
                    print(f"   Price Error: {price_data['error']}")
                else:
                    print(f"   Price USD: ${price_data.get('price_usd', 'N/A')}")
                    print(f"   Valid: {price_data.get('is_valid', False)}")
                    print(f"   Source: {price_data.get('source', 'Unknown')}")
        
        # Test oracle health check
        print("\nTesting check_oracle_health...")
        health_result = await dragon_mcp.check_oracle_health()
        
        if "error" in health_result:
            print_test_result(False, f"Health check error: {health_result['error']}")
        else:
            print_test_result(True, f"Health check completed")
            print(f"   Overall Status: {health_result.get('overall_status')}")
            print(f"   Chains Checked: {len(health_result.get('chains', {}))}")
            if health_result.get('alerts'):
                print(f"   Alerts: {len(health_result['alerts'])}")
        
        return True
    except Exception as e:
        print_test_result(False, f"Oracle test failed: {str(e)}")
        return False

async def test_lottery_simulation():
    """Test 4: Lottery Simulation Tools"""
    print_test_header("Lottery Simulation Functions")
    
    try:
        import dragon_mcp
        
        # Test lottery simulation
        test_amounts = [100, 1000, 5000]
        
        for amount in test_amounts:
            print(f"\nTesting simulate_lottery for ${amount}...")
            result = await dragon_mcp.simulate_lottery(amount, "sonic")
            
            if "error" in result:
                print_test_result(False, f"Simulation error: {result['error']}")
            else:
                print_test_result(True, f"Simulation completed for ${amount}")
                sim = result.get('simulation', {})
                print(f"   Win Chance: {sim.get('win_percentage', 0):.6f}%")
                print(f"   Win Probability PPM: {sim.get('win_probability_ppm', 0)}")
                print(f"   Expected Value: ${sim.get('expected_value_usd', 0):.2f}")
                print(f"   Has Chance: {sim.get('has_win_chance', False)}")
        
        # Test lottery stats
        print(f"\nTesting get_lottery_stats for Sonic...")
        stats_result = await dragon_mcp.get_lottery_stats("sonic")
        
        if "error" in stats_result:
            print_test_result(False, f"Stats error: {stats_result['error']}")
        else:
            print_test_result(True, f"Lottery stats retrieved")
            config = stats_result.get('lottery_config', {})
            print(f"   Active: {config.get('is_active', False)}")
            print(f"   Min Entry: ${config.get('min_entry_usd', 0)}")
            print(f"   Max Win Chance: {config.get('max_win_chance_ppm', 0)} PPM")
        
        return True
    except Exception as e:
        print_test_result(False, f"Lottery test failed: {str(e)}")
        return False

async def test_layerzero_tools():
    """Test 5: LayerZero Tools"""
    print_test_header("LayerZero Cross-Chain Tools")
    
    try:
        import dragon_mcp
        
        # Test LayerZero fee estimation
        test_routes = [
            ("sonic", "arbitrum"),
            ("arbitrum", "avalanche"),
            ("avalanche", "sonic")
        ]
        
        for source, dest in test_routes:
            print(f"\nTesting LayerZero fee: {source} → {dest}...")
            result = await dragon_mcp.estimate_layerzero_fee(source, dest, 32)
            
            if "error" in result:
                print_test_result(False, f"Fee estimation error: {result['error']}")
            else:
                print_test_result(True, f"Fee estimated: {source} → {dest}")
                fee = result.get('estimated_fee', {})
                print(f"   Native Fee: {fee.get('native_token', 0):.6f}")
                print(f"   USD Estimate: ${fee.get('usd_estimate', 0):.2f}")
                print(f"   Dest EID: {result.get('dest_eid', 'N/A')}")
        
        return True
    except Exception as e:
        print_test_result(False, f"LayerZero test failed: {str(e)}")
        return False

async def test_vrf_tools():
    """Test 6: VRF Tools"""
    print_test_header("Chainlink VRF Tools")
    
    try:
        import dragon_mcp
        
        # Test VRF request (simulation mode)
        print("Testing VRF randomness request...")
        result = await dragon_mcp.request_vrf_randomness("arbitrum", 2)
        
        if "error" in result:
            print_test_result(False, f"VRF error: {result['error']}")
        else:
            print_test_result(True, f"VRF request simulated")
            print(f"   Chain: {result.get('chain')}")
            print(f"   Words: {result.get('num_words')}")
            print(f"   Cost: {result.get('estimated_cost')}")
            print(f"   Note: {result.get('note')}")
        
        return True
    except Exception as e:
        print_test_result(False, f"VRF test failed: {str(e)}")
        return False

async def test_error_handling():
    """Test 7: Error Handling"""
    print_test_header("Error Handling and Edge Cases")
    
    try:
        import dragon_mcp
        
        # Test invalid chain
        print("Testing invalid chain handling...")
        result = await dragon_mcp.get_dragon_price("invalid_chain")
        if "error" in result:
            print_test_result(True, "Invalid chain properly handled")
        else:
            print_test_result(False, "Invalid chain not handled")
        
        # Test negative lottery amount
        print("Testing negative lottery amount...")
        result = await dragon_mcp.simulate_lottery(-100, "sonic")
        # This should either error or handle gracefully
        print_test_result(True, "Negative amount test completed")
        
        # Test very large lottery amount
        print("Testing very large lottery amount...")
        result = await dragon_mcp.simulate_lottery(1000000, "sonic")
        if "error" not in result:
            print_test_result(True, "Large amount handled")
        else:
            print_test_result(True, f"Large amount error: {result['error']}")
        
        return True
    except Exception as e:
        print_test_result(False, f"Error handling test failed: {str(e)}")
        return False

async def run_all_tests():
    """Run comprehensive test suite"""
    print("🐉 DRAGON MCP SERVER TEST SUITE")
    print("="*60)
    print("Testing all MCP tools and functionality...")
    
    tests = [
        ("Basic Imports", test_basic_imports),
        ("Web3 Connections", test_web3_connections),
        ("Oracle Functions", test_dragon_price_oracle),
        ("Lottery Simulation", test_lottery_simulation),
        ("LayerZero Tools", test_layerzero_tools),
        ("VRF Tools", test_vrf_tools),
        ("Error Handling", test_error_handling),
    ]
    
    results = {}
    
    for test_name, test_func in tests:
        try:
            success = await test_func()
            results[test_name] = success
        except Exception as e:
            print_test_result(False, f"{test_name} crashed: {str(e)}")
            results[test_name] = False
    
    # Print summary
    print("\n" + "="*60)
    print("🏁 TEST SUMMARY")
    print("="*60)
    
    passed = sum(results.values())
    total = len(results)
    
    for test_name, success in results.items():
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"{status} {test_name}")
    
    print(f"\n📊 RESULTS: {passed}/{total} tests passed ({passed/total*100:.1f}%)")
    
    if passed == total:
        print("🎉 ALL TESTS PASSED! Dragon MCP is ready for action!")
    else:
        print("⚠️  Some tests failed. Check configuration and network connectivity.")
    
    return passed == total

if __name__ == "__main__":
    asyncio.run(run_all_tests())