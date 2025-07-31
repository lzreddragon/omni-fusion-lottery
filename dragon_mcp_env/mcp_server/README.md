# Dragon MCP Server

This directory contains all the files for the Dragon Model Context Protocol (MCP) server, which provides AI-callable tools for interacting with the omniDRAGON ecosystem.

## 📁 Directory Structure

```
dragon_mcp_env/mcp_server/
├── dragon_mcp.py                    # Main MCP server implementation
├── requirements-dragon-mcp.txt      # Python dependencies
├── setup_dragon_mcp.sh             # Setup script
├── .env.example                     # Environment variables template
├── test_dragon_mcp.py              # Test suite for the MCP server
├── deploy_hosted_dragon_mcp.py     # Hosted deployment script
├── hosted_dragon_mcp_config.json   # Hosted server configuration
├── test_hosted_setup.sh            # Hosted setup testing
└── README.md                       # This file
```

## 🚀 Quick Start

### 1. Environment Setup
```bash
# From the project root directory
cd dragon_mcp_env/mcp_server
cp .env.example ../../.env
# Edit ../../.env with your configuration
```

### 2. Install Dependencies
```bash
# Run from this directory
bash setup_dragon_mcp.sh
```

### 3. Test the Server
```bash
python test_dragon_mcp.py
```

## 🔧 Configuration

The MCP server requires a `.env` file in the project root with the following variables:

```env
# RPC URLs
RPC_URL_SONIC=https://rpc.soniclabs.com/
RPC_URL_ETHEREUM=https://eth-mainnet.alchemyapi.io/v2/YOUR_KEY
RPC_URL_ARBITRUM=https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY
RPC_URL_BASE=https://base-mainnet.g.alchemy.com/v2/YOUR_KEY
RPC_URL_AVALANCHE=https://api.avax.network/ext/bc/C/rpc

# Contract Addresses
REGISTRY_ADDRESS=0x413c217f52f57692A60A0EA0974e89786440a6dA
OMNIDRAGON_ADDRESS=0x0cD587aE70220aAA4702568A57415664890B88da
PRIMARY_ORACLE_ADDRESS=0x10dA3b44416223E1b1acE16ED8d48a20B4cfc245

# Private Key (for testing only)
PRIVATE_KEY=0xYOUR_PRIVATE_KEY
```

## 🛠 Available Tools

The Dragon MCP server provides the following AI-callable tools:

### Oracle Tools
- `get_dragon_price` - Get current DRAGON price from oracle
- `check_oracle_health` - Monitor oracle network health
- `update_oracle_price` - Manually trigger price updates

### Lottery Tools
- `get_lottery_stats` - Get lottery statistics for a chain
- `simulate_lottery` - Simulate lottery win probability
- `test_lottery_entry` - Test lottery entry transactions

### LayerZero Tools
- `check_layerzero_status` - Check cross-chain message status
- `estimate_layerzero_fee` - Estimate messaging fees

### VRF Tools
- `request_vrf_randomness` - Request Chainlink VRF randomness

## 📦 Integration with Cursor

The MCP server is automatically configured for Cursor IDE integration via `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "dragon": {
      "command": "/path/to/dragon_mcp_env/bin/python",
      "args": ["/path/to/dragon_mcp_env/mcp_server/dragon_mcp.py"]
    }
  }
}
```

## 🧪 Testing

Run the test suite to verify functionality:

```bash
python test_dragon_mcp.py
```

## 🌐 Hosted Deployment

For production deployment, see:
- `deploy_hosted_dragon_mcp.py` - Deployment script
- `hosted_dragon_mcp_config.json` - Configuration template
- `test_hosted_setup.sh` - Testing script

## 📄 License

Part of the omniDRAGON ecosystem - MIT License