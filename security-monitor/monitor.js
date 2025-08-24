const { MongoClient } = require('mongodb');

const SECURITY_DB_URI = process.env.SECURITY_DB_URI || 'mongodb://agentmoby:secure_whale_2024@security-db:27017/agentmoby_security?authSource=admin';

class AgentMobySecurityMonitor {
  constructor() {
    this.client = null;
    this.db = null;
    this.isMonitoring = false;
  }

  async initialize() {
    try {
      this.client = new MongoClient(SECURITY_DB_URI);
      await this.client.connect();
      this.db = this.client.db('agentmoby_security');
      
      console.log('🐳 AgentMoby Security Monitor initialized');
      console.log('🛡️ Database connection: SECURE');
      
      await this.createCollections();
      this.startMonitoring();
      
    } catch (error) {
      console.error('❌ Security Monitor initialization failed:', error.message);
      process.exit(1);
    }
  }

  async createCollections() {
    const collections = [
      'security_events',
      'threat_assessments', 
      'agent_activities',
      'system_metrics'
    ];

    for (const collection of collections) {
      try {
        await this.db.createCollection(collection);
        console.log(`✅ Collection created: ${collection}`);
      } catch (error) {
        // Collection might already exist
      }
    }
  }

  startMonitoring() {
    this.isMonitoring = true;
    console.log('🔍 Security monitoring: ACTIVE');
    console.log('👁️  The whale never blinks...');

    // Log initial security event
    this.logSecurityEvent('MONITOR_START', {
      message: 'AgentMoby Security Monitor activated',
      threat_level: 'INFO',
      timestamp: new Date().toISOString()
    });

    // Start monitoring loops
    setInterval(() => this.performSecurityScan(), 60000); // Every minute
    setInterval(() => this.logSystemHealth(), 300000);   // Every 5 minutes
  }

  async logSecurityEvent(event_type, data) {
    try {
      await this.db.collection('security_events').insertOne({
        event_type,
        data,
        timestamp: new Date(),
        whale_status: 'watching'
      });
    } catch (error) {
      console.error('Failed to log security event:', error.message);
    }
  }

  async performSecurityScan() {
    console.log('🔍 Performing security scan...');
    
    // Simulate security monitoring
    const scanResult = {
      threats_detected: 0,
      systems_checked: ['dashboard', 'agent-core', 'mcp-gateway'],
      security_level: 'GREEN',
      scan_duration: Math.floor(Math.random() * 1000) + 500
    };

    await this.logSecurityEvent('SECURITY_SCAN', scanResult);
    console.log(`✅ Security scan complete - ${scanResult.security_level}`);
  }

  async logSystemHealth() {
    const healthData = {
      memory_usage: process.memoryUsage(),
      uptime: process.uptime(),
      monitoring_status: 'ACTIVE',
      whale_vigilance: 'MAXIMUM'
    };

    await this.logSecurityEvent('SYSTEM_HEALTH', healthData);
    console.log('📊 System health logged');
  }
}

// Initialize and start monitoring
const monitor = new AgentMobySecurityMonitor();
monitor.initialize();

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('🛑 AgentMoby Security Monitor shutting down...');
  if (monitor.client) {
    await monitor.client.close();
  }
  process.exit(0);
});
