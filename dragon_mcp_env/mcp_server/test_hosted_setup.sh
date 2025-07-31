#!/bin/bash
# Test hosted Dragon MCP setup

echo "🐉 Testing Hosted Dragon MCP Setup"

# Install additional dependencies for hosted version
echo "📦 Installing FastAPI dependencies..."
pip install fastapi uvicorn

# Test local server in hosted mode
echo "🚀 Starting test server on localhost:8000..."
echo "This simulates how it would run on sonicreddragon.io"

# Start the server (will run until Ctrl+C)
python deploy_hosted_dragon_mcp.py

echo "✅ Test server running at http://localhost:8000"
echo "📊 Health check: http://localhost:8000/health"
echo "🔧 API docs: http://localhost:8000/docs"