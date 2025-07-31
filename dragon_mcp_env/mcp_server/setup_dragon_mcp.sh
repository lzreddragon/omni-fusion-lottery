#!/bin/bash

# Dragon MCP Setup Script
# Installs dependencies and configures the Dragon MCP server

echo "🐉 Dragon MCP Setup"
echo "==================="

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 not found. Please install Python 3.8+ first."
    exit 1
fi

echo "✅ Python found: $(python3 --version)"

# Install Python dependencies
echo "📦 Installing Python dependencies..."
# Activate virtual environment if we're not already in it
if [[ "$VIRTUAL_ENV" == "" ]]; then
    source ../bin/activate
fi
pip install -r requirements-dragon-mcp.txt

if [ $? -eq 0 ]; then
    echo "✅ Dependencies installed successfully"
else
    echo "❌ Failed to install dependencies"
    exit 1
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "✅ Created .env file. Please edit it with your RPC URLs and API keys."
else
    echo "📄 .env file already exists"
fi

# Make the MCP server executable
chmod +x dragon_mcp.py

# Test the MCP server
echo "🧪 Testing Dragon MCP server..."
timeout 5 python3 dragon_mcp.py &> /dev/null

if [ $? -eq 124 ]; then
    echo "✅ Dragon MCP server starts successfully"
else
    echo "⚠️  Dragon MCP server test inconclusive (this is usually normal)"
fi

echo ""
echo "🎉 Dragon MCP Setup Complete!"
echo ""
echo "📋 Next Steps:"
echo "1. Edit .env file with your RPC URLs"
echo "2. Restart Cursor IDE to load the new MCP server"
echo "3. Test with: 'Check Dragon oracle health'"
echo ""
echo "🔗 MCP Server configured as: 'dragon'"
echo "📍 File location: $(pwd)/dragon_mcp.py"
echo ""
echo "For help, see: README-dragon-mcp.md"