#!/usr/bin/env python3
"""
MobyAgent Audit Logger - After Interceptor
Comprehensive logging and audit trail for all tool responses.
"""
import json
import sys
import logging
import os
import hashlib
from typing import Dict, Any, List, Optional
from datetime import datetime
import gzip
import base64

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class AuditLogger:
    """Comprehensive audit logging for MCP tool responses."""
    
    def __init__(self):
        self.audit_dir = '/var/log/mobyagent/audit'
        self.ensure_audit_directory()
        self.session_id = os.environ.get('SESSION_ID', 'unknown')
        self.client_ip = os.environ.get('CLIENT_IP', '0.0.0.0')
        self.user_role = os.environ.get('USER_ROLE', 'user')
        
    def ensure_audit_directory(self):
        """Ensure audit directory exists."""
        try:
            os.makedirs(self.audit_dir, exist_ok=True)
        except Exception as e:
            logger.error(f"Failed to create audit directory: {str(e)}")
            self.audit_dir = '/tmp/mobyagent-audit'
            os.makedirs(self.audit_dir, exist_ok=True)
    
    def generate_request_hash(self, request: Dict[str, Any]) -> str:
        """Generate a hash for the request for correlation."""
        request_str = json.dumps(request, sort_keys=True)
        return hashlib.sha256(request_str.encode()).hexdigest()[:16]
    
    def classify_data_sensitivity(self, data: Any) -> str:
        """Classify data sensitivity level."""
        data_str = json.dumps(data).lower() if data else ""
        
        # Check for highly sensitive patterns
        highly_sensitive_patterns = [
            'password', 'secret', 'token', 'key', 'credential',
            'private_key', 'api_key', 'auth_token', 'session_id',
            'credit_card', 'ssn', 'social_security'
        ]
        
        # Check for moderately sensitive patterns
        moderately_sensitive_patterns = [
            'email', 'phone', 'address', 'name', 'user',
            'account', 'id', 'personal', 'private'
        ]
        
        for pattern in highly_sensitive_patterns:
            if pattern in data_str:
                return 'high'
        
        for pattern in moderately_sensitive_patterns:
            if pattern in data_str:
                return 'medium'
        
        return 'low'
    
    def analyze_response_content(self, response: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze response content for security insights."""
        analysis = {
            'has_error': 'error' in response,
            'data_size': len(json.dumps(response)),
            'sensitivity_level': self.classify_data_sensitivity(response),
            'contains_files': False,
            'contains_code': False,
            'contains_urls': False,
            'execution_indicators': []
        }
        
        response_str = json.dumps(response).lower()
        
        # Check for file operations
        file_indicators = ['filename', 'filepath', 'directory', 'file_content']
        analysis['contains_files'] = any(indicator in response_str for indicator in file_indicators)
        
        # Check for code content
        code_indicators = ['function', 'class', 'import', 'def ', 'var ', 'const ', 'let ']
        analysis['contains_code'] = any(indicator in response_str for indicator in code_indicators)
        
        # Check for URLs
        url_indicators = ['http://', 'https://', 'ftp://', 'file://']
        analysis['contains_urls'] = any(indicator in response_str for indicator in url_indicators)
        
        # Check for potential execution indicators
        exec_indicators = ['executed', 'ran', 'output', 'stderr', 'stdout', 'exit_code']
        analysis['execution_indicators'] = [ind for ind in exec_indicators if ind in response_str]
        
        return analysis
    
    def create_audit_record(self, request: Dict[str, Any], response: Dict[str, Any]) -> Dict[str, Any]:
        """Create comprehensive audit record."""
        timestamp = datetime.utcnow()
        analysis = self.analyze_response_content(response)
        
        audit_record = {
            'audit_version': '1.0',
            'timestamp': timestamp.isoformat(),
            'event_type': 'tool_response',
            'session_id': self.session_id,
            'client_ip': self.client_ip,
            'user_role': self.user_role,
            'request_hash': self.generate_request_hash(request),
            
            # Request information
            'request': {
                'method': request.get('method', 'unknown'),
                'params_hash': hashlib.sha256(
                    json.dumps(request.get('params', {}), sort_keys=True).encode()
                ).hexdigest()[:16],
                'id': request.get('id')
            },
            
            # Response information
            'response': {
                'success': 'error' not in response,
                'data_size': analysis['data_size'],
                'sensitivity_level': analysis['sensitivity_level'],
                'error_type': response.get('error', {}).get('code') if 'error' in response else None
            },
            
            # Analysis results
            'analysis': analysis,
            
            # Compliance and security tags
            'tags': self.generate_security_tags(request, response, analysis),
            
            # Performance metrics
            'metrics': {
                'processing_time_ms': os.environ.get('PROCESSING_TIME_MS', 'unknown'),
                'memory_usage_mb': os.environ.get('MEMORY_USAGE_MB', 'unknown')
            }
        }
        
        return audit_record
    
    def generate_security_tags(self, request: Dict[str, Any], response: Dict[str, Any], analysis: Dict[str, Any]) -> List[str]:
        """Generate security and compliance tags."""
        tags = []
        
        # Tool-based tags
        tool_name = request.get('method', '')
        if 'file' in tool_name.lower():
            tags.append('file_operation')
        if 'network' in tool_name.lower() or 'http' in tool_name.lower():
            tags.append('network_operation')
        if 'execute' in tool_name.lower() or 'command' in tool_name.lower():
            tags.append('system_operation')
        
        # Sensitivity tags
        if analysis['sensitivity_level'] == 'high':
            tags.append('sensitive_data')
        
        # Content tags
        if analysis['contains_files']:
            tags.append('file_content')
        if analysis['contains_code']:
            tags.append('code_content')
        if analysis['contains_urls']:
            tags.append('url_content')
        
        # Error tags
        if analysis['has_error']:
            tags.append('error_response')
        
        # Compliance tags
        if analysis['data_size'] > 100000:  # 100KB
            tags.append('large_response')
        
        return tags
    
    def write_audit_log(self, audit_record: Dict[str, Any]):
        """Write audit record to log files."""
        timestamp = datetime.utcnow()
        
        # Daily audit file
        daily_file = os.path.join(
            self.audit_dir, 
            f"audit-{timestamp.strftime('%Y-%m-%d')}.jsonl"
        )
        
        try:
            with open(daily_file, 'a') as f:
                f.write(json.dumps(audit_record) + '\n')
        except Exception as e:
            logger.error(f"Failed to write audit log: {str(e)}")
        
        # Sensitive data special handling
        if audit_record['analysis']['sensitivity_level'] == 'high':
            sensitive_file = os.path.join(
                self.audit_dir,
                f"sensitive-{timestamp.strftime('%Y-%m-%d')}.jsonl"
            )
            try:
                with open(sensitive_file, 'a') as f:
                    f.write(json.dumps(audit_record) + '\n')
            except Exception as e:
                logger.error(f"Failed to write sensitive audit log: {str(e)}")
    
    def send_to_wazuh(self, audit_record: Dict[str, Any]):
        """Send audit record to Wazuh for SIEM integration."""
        # Format for Wazuh integration
        wazuh_event = {
            'agent': {'name': 'mobyagent-gateway'},
            'manager': {'name': 'wazuh-manager'},
            'id': audit_record['request_hash'],
            'full_log': json.dumps(audit_record),
            'timestamp': audit_record['timestamp'],
            'location': 'mobyagent-audit',
            'decoder': {'name': 'mobyagent-decoder'}
        }
        
        # Log in Wazuh format
        logger.info(f"WAZUH_AUDIT: {json.dumps(wazuh_event)}")
    
    def create_security_alert(self, audit_record: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Create security alerts based on audit analysis."""
        alerts = []
        
        # High sensitivity data alert
        if audit_record['analysis']['sensitivity_level'] == 'high':
            alerts.append({
                'type': 'sensitive_data_exposure',
                'severity': 'high',
                'message': 'High sensitivity data detected in response'
            })
        
        # Large response alert
        if audit_record['analysis']['data_size'] > 1000000:  # 1MB
            alerts.append({
                'type': 'large_response',
                'severity': 'medium',
                'message': f"Large response detected: {audit_record['analysis']['data_size']} bytes"
            })
        
        # Execution indicators alert
        if audit_record['analysis']['execution_indicators']:
            alerts.append({
                'type': 'execution_detected',
                'severity': 'medium',
                'message': f"Execution indicators: {', '.join(audit_record['analysis']['execution_indicators'])}"
            })
        
        if alerts:
            return {
                'alerts': alerts,
                'audit_id': audit_record['request_hash'],
                'timestamp': audit_record['timestamp']
            }
        
        return None
    
    def process_response(self, request: Dict[str, Any], response: Dict[str, Any]) -> Dict[str, Any]:
        """Process and audit tool response."""
        try:
            # Create audit record
            audit_record = self.create_audit_record(request, response)
            
            # Write to audit logs
            self.write_audit_log(audit_record)
            
            # Send to Wazuh
            self.send_to_wazuh(audit_record)
            
            # Check for security alerts
            security_alert = self.create_security_alert(audit_record)
            if security_alert:
                logger.warning(f"SECURITY_ALERT: {json.dumps(security_alert)}")
            
            # Log summary
            logger.info(f"AUDIT_PROCESSED: tool={audit_record['request']['method']} "
                       f"sensitivity={audit_record['analysis']['sensitivity_level']} "
                       f"size={audit_record['analysis']['data_size']}bytes "
                       f"session={self.session_id}")
            
            # Return original response (audit is transparent)
            return response
            
        except Exception as e:
            logger.error(f"Error in audit logger: {str(e)}")
            # Return original response even if auditing fails
            return response

def main():
    """Main interceptor entry point."""
    auditor = AuditLogger()
    
    try:
        # Read both request and response from stdin
        # After interceptors receive both request and response
        input_data = json.loads(sys.stdin.read())
        request_data = input_data.get('request', {})
        response_data = input_data.get('response', {})
        
        # Process the response
        processed_response = auditor.process_response(request_data, response_data)
        
        # Output the processed response
        print(json.dumps(processed_response))
        sys.exit(0)
        
    except Exception as e:
        logger.error(f"Fatal error in audit logger: {str(e)}")
        # Try to return original response or empty response
        try:
            input_data = json.loads(sys.stdin.read())
            response_data = input_data.get('response', {})
            print(json.dumps(response_data))
        except:
            print(json.dumps({"error": {"code": -32603, "message": "Audit logger error"}}))
        sys.exit(0)

if __name__ == "__main__":
    main()
