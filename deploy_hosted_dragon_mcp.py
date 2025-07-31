#!/usr/bin/env python3
"""
Hosted Dragon MCP Server
Production deployment for sonicreddragon.io hosting.

This version runs as a web service that can be accessed by multiple Cursor instances.
"""

import os
import json
import asyncio
from typing import Any, Dict
from fastapi import FastAPI, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

# Import the Dragon MCP functionality
from dragon_mcp import (
    get_dragon_price,
    check_oracle_health,
    update_oracle_price,
    get_lottery_stats,
    simulate_lottery,
    test_lottery_entry,
    check_layerzero_status,
    estimate_layerzero_fee,
    request_vrf_randomness
)

# FastAPI app
app = FastAPI(
    title="Dragon MCP Server",
    description="Hosted MCP server for omniDRAGON ecosystem monitoring and testing",
    version="1.0.0"
)

# Add CORS middleware for web access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://cursor.sh", "https://sonicreddragon.io"],
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

# Security configuration
VALID_API_KEYS = {
    os.getenv("DRAGON_MCP_API_KEY", "dev-key-12345"): "development",
    os.getenv("TEAM_API_KEY"): "team",
    os.getenv("ADMIN_API_KEY"): "admin"
}

# Rate limiting (simple in-memory store)
request_counts = {}
RATE_LIMIT = 100  # requests per hour

# Request/Response models
class DragonPriceRequest(BaseModel):
    chain: str = "sonic"

class DragonPriceResponse(BaseModel):
    success: bool
    data: Dict[str, Any]
    timestamp: int

class LotterySimulationRequest(BaseModel):
    usd_amount: float
    chain: str = "sonic"

class LayerZeroStatusRequest(BaseModel):
    tx_hash: str
    chain: str

# Authentication dependency
async def verify_api_key(authorization: str = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header")
    
    api_key = authorization[7:]  # Remove "Bearer " prefix
    if api_key not in VALID_API_KEYS:
        raise HTTPException(status_code=401, detail="Invalid API key")
    
    return VALID_API_KEYS[api_key]

# Rate limiting dependency
async def check_rate_limit(api_key_type: str = Depends(verify_api_key)):
    # Simple rate limiting - implement Redis/database for production
    current_count = request_counts.get(api_key_type, 0)
    if current_count >= RATE_LIMIT:
        raise HTTPException(status_code=429, detail="Rate limit exceeded")
    
    request_counts[api_key_type] = current_count + 1
    return api_key_type

# Health check endpoint
@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "Dragon MCP Server"}

# Oracle endpoints
@app.post("/oracle/price", response_model=DragonPriceResponse)
async def get_price_endpoint(
    request: DragonPriceRequest,
    _: str = Depends(check_rate_limit)
):
    try:
        result = await get_dragon_price(request.chain)
        return DragonPriceResponse(
            success=True,
            data=result,
            timestamp=int(asyncio.get_event_loop().time())
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/oracle/health")
async def oracle_health_endpoint(_: str = Depends(check_rate_limit)):
    try:
        result = await check_oracle_health()
        return {"success": True, "data": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/oracle/update")
async def update_price_endpoint(
    request: DragonPriceRequest,
    api_key_type: str = Depends(check_rate_limit)
):
    # Only admin can trigger price updates
    if api_key_type != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    try:
        result = await update_oracle_price(request.chain)
        return {"success": True, "data": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Lottery endpoints
@app.get("/lottery/stats/{chain}")
async def lottery_stats_endpoint(
    chain: str,
    _: str = Depends(check_rate_limit)
):
    try:
        result = await get_lottery_stats(chain)
        return {"success": True, "data": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/lottery/simulate")
async def simulate_lottery_endpoint(
    request: LotterySimulationRequest,
    _: str = Depends(check_rate_limit)
):
    try:
        result = await simulate_lottery(request.usd_amount, request.chain)
        return {"success": True, "data": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# LayerZero endpoints
@app.post("/layerzero/status")
async def layerzero_status_endpoint(
    request: LayerZeroStatusRequest,
    _: str = Depends(check_rate_limit)
):
    try:
        result = await check_layerzero_status(request.tx_hash, request.chain)
        return {"success": True, "data": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/layerzero/fee/{source_chain}/{dest_chain}")
async def estimate_fee_endpoint(
    source_chain: str,
    dest_chain: str,
    payload_size: int = 32,
    _: str = Depends(check_rate_limit)
):
    try:
        result = await estimate_layerzero_fee(source_chain, dest_chain, payload_size)
        return {"success": True, "data": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# VRF endpoints
@app.post("/vrf/request")
async def vrf_request_endpoint(
    chain: str = "arbitrum",
    num_words: int = 1,
    api_key_type: str = Depends(check_rate_limit)
):
    # Only team/admin can request VRF
    if api_key_type == "development":
        raise HTTPException(status_code=403, detail="Team access required for VRF")
    
    try:
        result = await request_vrf_randomness(chain, num_words)
        return {"success": True, "data": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# MCP-compatible endpoints
@app.get("/mcp/tools")
async def list_tools(_: str = Depends(verify_api_key)):
    """List available MCP tools"""
    return {
        "tools": [
            {
                "name": "get_dragon_price",
                "description": "Get DRAGON price from oracle network",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "chain": {"type": "string", "default": "sonic"}
                    }
                }
            },
            {
                "name": "check_oracle_health",
                "description": "Monitor oracle network health",
                "inputSchema": {"type": "object", "properties": {}}
            },
            {
                "name": "get_lottery_stats",
                "description": "Get lottery statistics for a chain",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "chain": {"type": "string", "required": True}
                    },
                    "required": ["chain"]
                }
            },
            {
                "name": "simulate_lottery",
                "description": "Simulate lottery probability",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "usd_amount": {"type": "number", "required": True},
                        "chain": {"type": "string", "default": "sonic"}
                    },
                    "required": ["usd_amount"]
                }
            }
        ]
    }

@app.post("/mcp/call/{tool_name}")
async def call_tool(
    tool_name: str,
    request_data: Dict[str, Any],
    api_key_type: str = Depends(check_rate_limit)
):
    """Execute MCP tool"""
    tool_map = {
        "get_dragon_price": get_dragon_price,
        "check_oracle_health": check_oracle_health,
        "get_lottery_stats": get_lottery_stats,
        "simulate_lottery": simulate_lottery,
        "check_layerzero_status": check_layerzero_status,
        "estimate_layerzero_fee": estimate_layerzero_fee
    }
    
    if tool_name not in tool_map:
        raise HTTPException(status_code=404, detail=f"Tool '{tool_name}' not found")
    
    try:
        tool_func = tool_map[tool_name]
        
        # Call tool with appropriate arguments
        if tool_name == "get_dragon_price":
            result = await tool_func(request_data.get("chain", "sonic"))
        elif tool_name == "check_oracle_health":
            result = await tool_func()
        elif tool_name == "get_lottery_stats":
            result = await tool_func(request_data["chain"])
        elif tool_name == "simulate_lottery":
            result = await tool_func(
                request_data["usd_amount"],
                request_data.get("chain", "sonic")
            )
        elif tool_name == "check_layerzero_status":
            result = await tool_func(
                request_data["tx_hash"],
                request_data["chain"]
            )
        elif tool_name == "estimate_layerzero_fee":
            result = await tool_func(
                request_data["source_chain"],
                request_data["dest_chain"],
                request_data.get("payload_size", 32)
            )
        
        return {"success": True, "data": result}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    print("🐉 Dragon MCP Server (Hosted)")
    print("🌐 Starting web service...")
    print("📊 Oracle monitoring & lottery tools")
    print("🔗 API endpoints ready")
    
    # Run server
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=int(os.getenv("PORT", 8000)),
        log_level="info"
    )