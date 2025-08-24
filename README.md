# 🐳 AgentMoby: The Whale that never blinks

<img width="256" height="256" alt="MobyAgent Security Whale" src="https://github.com/user-attachments/assets/e0b5fccc-e3da-4fcb-993d-e6a799408e51" />

> A security-hardened AI agent reference architecture using Docker MCP Gateway, Docker Model Runner, and production-ready best practices.

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://docker.com)
[![Security](https://img.shields.io/badge/Security-Hardened-green?style=for-the-badge)](https://github.com/ajeetraina/agentmoby)
[![MCP](https://img.shields.io/badge/MCP-Gateway-blue?style=for-the-badge)](https://docs.docker.com/ai/mcp-gateway/)

## 🎯 Overview

MobyAgent demonstrates a **security-first approach** to building AI agents in production environments. Named after Docker's iconic whale mascot, this "whale that never blinks" maintains constant vigilance against AI security threats while delivering powerful agentic capabilities.

## 🎯 5 Specialized Security Agents:

- Security Analyst (Port 8001) - Primary threat detection
- Incident Response (Port 8002) - Response planning & coordination
- Threat Intelligence (Port 8003) - Research & intel gathering
- Code Security (Port 8004) - Vulnerability scanning & code review
- Compliance Agent (Port 8005) - Policy enforcement & compliance

## 🛡️ 5 Security Interceptors:

- Security Filter (Port 9091) - Content filtering & prompt injection protection
- Agent Router (Port 9092) - Smart routing between specialized agents
- Audit Logger (Port 9093) - Complete interaction logging & compliance
- Rate Limiter (Port 9094) - Per-agent and per-user rate limiting
- Authorization (Port 9095) - Role-based access control

## 🎛️ Management & UI Services:

- Crew Coordinator (Port 8090) - Multi-agent orchestration
- Multi-Agent Dashboard (Port 3001) - Enhanced UI for team coordination
- Security Metrics Dashboard (Port 3002) - Team performance & metrics
- MongoDB Express (Port 8081) - Database administration


## 🚀 Quick Start

Deploy the entire secure agent infrastructure with a single command:

```bash
git clone https://github.com/ajeetraina/agentmoby.git
cd agentmoby
docker compose up -d
```

Access the agent UI at `http://localhost:3000` and start asking questions safely!


 Your Complete AgentMoby System:

```
🎨 Dashboard: http://localhost:3000 (Real-time monitoring)
🤖 AI Agent: http://localhost:8000 (OpenAI-powered API)
🛍️ Sock Store: http://localhost:9090 (Full e-commerce with 9 products!)
📊 Catalogue API: http://localhost:8081 (Product inventory working!)
🔌 MCP Gateway: http://localhost:8811 (Tool management)
```



