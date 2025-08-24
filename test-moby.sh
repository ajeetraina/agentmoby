#!/bin/bash

echo "🧪 AgentMoby Comprehensive Testing Suite"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Test result function
test_result() {
    local test_name="$1"
    local success="$2"
    local details="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ "$success" = true ]; then
        echo -e "✅ ${GREEN}$test_name${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "❌ ${RED}$test_name${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    if [ ! -z "$details" ]; then
        echo "   $details"
    fi
    echo ""
}

echo "🔍 Step 1: Basic Service Health Checks"
echo "======================================"

# Check container status
echo "📦 Checking container status..."
containers=$(docker compose ps --format "table {{.Service}}\t{{.Status}}" | tail -n +2)
echo "$containers"
echo ""

# Test basic service endpoints
services=(
    "http://localhost:3000/health|AgentMoby Dashboard|adk-ui"
    "http://localhost:8000/health|ADK API|adk"
    "http://localhost:9090|Sock Store Frontend|front-end"
    "http://localhost:8081|Catalogue API|catalogue" 
    "http://localhost:8811|MCP Gateway|mcp-gateway"
)

for service in "${services[@]}"; do
    url=$(echo $service | cut -d'|' -f1)
    name=$(echo $service | cut -d'|' -f2)
    container=$(echo $service | cut -d'|' -f3)
    
    if curl -s -f "$url" > /dev/null 2>&1; then
        test_result "$name Health Check" true "Responding at $url"
    else
        test_result "$name Health Check" false "Not responding at $url"
        echo "   💡 Check logs: docker compose logs $container"
    fi
done

echo "🤖 Step 2: AI Agent Functionality Testing"
echo "========================================"

# Test ADK API with AI capabilities
echo "Testing AI agent with real OpenAI API..."
ai_response=$(curl -s -X POST http://localhost:8000/api/agent \
    -H "Content-Type: application/json" \
    -d '{"message": "Hello! Can you tell me what AgentMoby is in one sentence?"}' \
    --max-time 30)

if [ $? -eq 0 ] && [ ! -z "$ai_response" ]; then
    test_result "AI Agent Response" true "Got response: ${ai_response:0:100}..."
else
    test_result "AI Agent Response" false "No response or timeout"
    echo "   💡 Check: docker compose logs adk"
fi

# Test API status endpoint
api_status=$(curl -s http://localhost:8000/api/status --max-time 10)
if [ $? -eq 0 ] && echo "$api_status" | grep -q "running"; then
    test_result "ADK API Status" true "Service reporting as running"
else
    test_result "ADK API Status" false "Service not reporting status correctly"
fi

echo "🔌 Step 3: MCP Gateway Testing"
echo "============================="

# Check MCP Gateway health
mcp_health=$(curl -s http://localhost:8811/health --max-time 10)
if [ $? -eq 0 ]; then
    test_result "MCP Gateway Health" true "Gateway responding"
else
    test_result "MCP Gateway Health" false "Gateway not responding"
fi

# Check MCP Gateway logs for API key validation
echo "📋 Checking MCP Gateway logs for API key status..."
mcp_logs=$(docker compose logs --tail=50 mcp-gateway 2>/dev/null)

if echo "$mcp_logs" | grep -q "Initialized"; then
    test_result "MCP Gateway Initialization" true "Gateway initialized successfully"
else
    test_result "MCP Gateway Initialization" false "Gateway initialization issues"
    echo "   💡 Recent logs:"
    echo "$mcp_logs" | tail -10 | sed 's/^/   /'
fi

# Check for API key errors
if echo "$mcp_logs" | grep -i -q "api.*key\|authentication"; then
    echo "   ⚠️  API key related messages found in logs"
    echo "$mcp_logs" | grep -i "api.*key\|authentication" | tail -3 | sed 's/^/   /'
fi

echo "🌐 Step 4: Web Interface Testing"
echo "==============================="

# Test web interfaces
web_endpoints=(
    "http://localhost:3000|AgentMoby Dashboard"
    "http://localhost:9090|Sock Store Frontend"
)

for endpoint in "${web_endpoints[@]}"; do
    url=$(echo $endpoint | cut -d'|' -f1)
    name=$(echo $endpoint | cut -d'|' -f2)
    
    response=$(curl -s "$url" --max-time 10)
    if [ $? -eq 0 ] && [ ${#response} -gt 100 ]; then
        test_result "$name Web Interface" true "Page loaded successfully (${#response} bytes)"
    else
        test_result "$name Web Interface" false "Page not loading or too small"
    fi
done

echo "🗄️ Step 5: Database Connectivity Testing"  
echo "======================================="

# Test MongoDB connection
mongo_test=$(docker compose exec -T mongodb mongosh --quiet --eval "db.adminCommand('ping')" 2>/dev/null)
if echo "$mongo_test" | grep -q "ok.*1"; then
    test_result "MongoDB Connection" true "Database responding to ping"
else
    test_result "MongoDB Connection" false "Database not responding"
fi

# Test MySQL connection  
mysql_test=$(docker compose exec -T catalogue-db mysql -u root -pfake_password -e "SELECT 1;" 2>/dev/null)
if echo "$mysql_test" | grep -q "1"; then
    test_result "MySQL Connection" true "Database accepting connections"
else
    test_result "MySQL Connection" false "Database connection failed"
fi

echo "🚀 Step 6: Integration Testing"
echo "============================="

# Test service-to-service communication
echo "Testing ADK to MCP Gateway communication..."
adk_logs=$(docker compose logs --tail=20 adk 2>/dev/null)
if echo "$adk_logs" | grep -q "8811\|mcp-gateway"; then
    test_result "ADK to MCP Gateway Communication" true "Services communicating"
else
    test_result "ADK to MCP Gateway Communication" false "No communication detected"
fi

# Test catalogue service database integration
catalogue_logs=$(docker compose logs --tail=20 catalogue 2>/dev/null)
if echo "$catalogue_logs" | grep -q "Database.*connect\|transport=HTTP"; then
    test_result "Catalogue Database Integration" true "Service connected to database"
else
    test_result "Catalogue Database Integration" false "Database integration issues"
fi

echo "📊 Final Results"
echo "==============="
echo ""
echo -e "🧪 Tests completed: ${BLUE}$TOTAL_TESTS${NC}"
echo -e "✅ Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "❌ Tests failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "🎉 ${GREEN}All tests passed! AgentMoby is fully operational!${NC}"
    echo ""
    echo "🌐 Your AgentMoby is ready to use:"
    echo "  • 🎨 Dashboard: http://localhost:3000 (Beautiful UI with real-time monitoring)"
    echo "  • 🤖 AI Agent: http://localhost:8000 (OpenAI-powered API)"
    echo "  • 🛍️ Demo Store: http://localhost:9090 (Full e-commerce example)"
    echo "  • 📊 Catalogue: http://localhost:8081 (Product API)"
    echo "  • 🔌 MCP Gateway: http://localhost:8811 (Tool management)"
    echo ""
    echo "💡 Try these interactive tests:"
    echo "  1. Visit http://localhost:3000 and interact with the dashboard"
    echo "  2. Test the AI agent with complex queries"
    echo "  3. Browse the sock store demo at http://localhost:9090"
    
elif [ $TESTS_FAILED -lt 3 ]; then
    echo -e "⚠️ ${YELLOW}Most tests passed, but some issues detected${NC}"
    echo ""
    echo "🔧 Common fixes:"
    echo "  • Wait a bit longer for services to fully initialize"
    echo "  • Check API key validity and permissions"
    echo "  • Restart problematic services: docker compose restart [service-name]"
    
else
    echo -e "🚨 ${RED}Multiple tests failed - system needs troubleshooting${NC}"
    echo ""
    echo "🔍 Troubleshooting steps:"
    echo "  1. Check all containers: docker compose ps"
    echo "  2. View logs: docker compose logs"
    echo "  3. Verify API keys are correctly set"
    echo "  4. Try restarting: docker compose restart"
fi

echo ""
echo "📋 Detailed Testing Commands"
echo "==========================="
echo ""
echo "Manual AI Testing:"
echo "curl -X POST http://localhost:8000/api/agent \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"message\": \"Explain how containerized AI agents improve security\"}'"
echo ""
echo "Check Service Logs:"
echo "docker compose logs -f adk       # AI agent logs"
echo "docker compose logs -f mcp-gateway  # MCP tool logs"
echo "docker compose logs -f adk-ui    # Dashboard logs"
echo ""
echo "Real-time Monitoring:"
echo "watch 'docker compose ps && echo && curl -s http://localhost:3000/health'"
echo ""
echo "🎯 Happy testing! Your AgentMoby is ready for action! 🐳"
EOF
