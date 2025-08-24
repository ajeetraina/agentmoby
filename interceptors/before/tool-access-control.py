#!/usr/bin/env python3
"""
MobyAgent Tool Access Control - Before Interceptor
Enforces fine-grained permissions and tool access boundaries.
"""
import json
import sys
import logging
import os
from typing import Dict, Any, List, Set, Optional
from datetime import datetime
import yaml

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class ToolAccessController:
    """Comprehensive tool access control and permission management."""
    
    def __init__(self, policy_file: str = '/app/config/tool-permissions.yaml'):
        self.policy_file = policy_file
        self.policies = self.load_policies()
        self.session_context = self.get_session_context()
        
    def load_policies(self) -> Dict[str, Any]:
        """Load tool access policies from configuration file."""
        try:
            if os.path.exists(self.policy_file):
                with open(self.policy_file, 'r') as f:
                    return yaml.safe_load(f)
            else:
                # Default fallback policies
                return self.get_default_policies()
        except Exception as e:
            logger.error(f"Error loading policies: {str(e)}")
            return self.get_default_policies()
    
    def get_default_policies(self) -> Dict[str, Any]:
        """Default security policies for tool access."""
        return {
            'default_role': 'user',
            'roles': {
                'admin': {
                    'allowed_tools': ['*'],
                    'denied_tools': [],
                    'rate_limit': 1000,
                    'max_concurrent': 10
                },
                'user': {
                    'allowed_tools': [
                        'search_web', 'read_file', 'list_files',
                        'get_weather', 'calculate', 'translate'
                    ],
                    'denied_tools': [
                        'execute_command', 'write_file', 'delete_file',
                        'system_call', 'docker_exec', 'network_request'
                    ],
                    'rate_limit': 100,
                    'max_concurrent': 3
                },
                'guest': {
                    'allowed_tools': ['search_web', 'get_weather', 'calculate'],
                    'denied_tools': ['*'],
                    'rate_limit': 20,
                    'max_concurrent': 1
                }
            },
            'tool_restrictions': {
                'file_operations': {
                    'allowed_extensions': ['.txt', '.json', '.csv', '.md'],
                    'forbidden_paths': ['/etc', '/root', '/home', '/var'],
                    'max_file_size': '10MB'
                },
                'network_operations': {
                    'allowed_domains': ['api.github.com', 'httpbin.org'],
                    'forbidden_domains': ['localhost', '127.0.0.1', '10.0.0.0/8'],
                    'allowed_ports': [80, 443]
                },
                'system_operations': {
                    'forbidden_commands': ['rm', 'delete', 'format', 'dd'],
                    'max_execution_time': 30
                }
            },
            'time_restrictions': {
                'business_hours_only': False,
                'allowed_hours': [9, 17],  # 9 AM to 5 PM
                'timezone': 'UTC'
            }
        }
    
    def get_session_context(self) -> Dict[str, Any]:
        """Extract session context from environment variables."""
        return {
            'user_role': os.environ.get('USER_ROLE', 'user'),
            'session_id': os.environ.get('SESSION_ID', 'unknown'),
            'client_ip': os.environ.get('CLIENT_IP', '0.0.0.0'),
            'user_agent': os.environ.get('USER_AGENT', 'unknown'),
            'auth_level': os.environ.get('AUTH_LEVEL', 'basic')
        }
    
    def is_tool_allowed(self, tool_name: str, user_role: str) -> bool:
        """Check if tool is allowed for the given user role."""
        role_policy = self.policies['roles'].get(user_role, self.policies['roles']['user'])
        
        # Check explicit denials first
        denied_tools = role_policy.get('denied_tools', [])
        if '*' in denied_tools or tool_name in denied_tools:
            return False
        
        # Check allowed tools
        allowed_tools = role_policy.get('allowed_tools', [])
        if '*' in allowed_tools or tool_name in allowed_tools:
            return True
        
        return False
    
    def check_file_operation_restrictions(self, params: Dict[str, Any], tool_name: str) -> Optional[str]:
        """Check file operation restrictions."""
        if not any(keyword in tool_name.lower() for keyword in ['file', 'read', 'write', 'delete']):
            return None
        
        restrictions = self.policies.get('tool_restrictions', {}).get('file_operations', {})
        
        # Check file paths
        file_path = params.get('path') or params.get('file_path') or params.get('filename', '')
        if file_path:
            forbidden_paths = restrictions.get('forbidden_paths', [])
            for forbidden in forbidden_paths:
                if file_path.startswith(forbidden):
                    return f"Access denied: Path '{file_path}' is in forbidden directory '{forbidden}'"
        
        # Check file extensions for write operations
        if 'write' in tool_name.lower() or 'create' in tool_name.lower():
            allowed_extensions = restrictions.get('allowed_extensions', [])
            if allowed_extensions and file_path:
                file_ext = os.path.splitext(file_path)[1].lower()
                if file_ext not in allowed_extensions:
                    return f"Access denied: File extension '{file_ext}' not allowed"
        
        return None
    
    def check_network_operation_restrictions(self, params: Dict[str, Any], tool_name: str) -> Optional[str]:
        """Check network operation restrictions."""
        if not any(keyword in tool_name.lower() for keyword in ['http', 'request', 'fetch', 'download']):
            return None
        
        restrictions = self.policies.get('tool_restrictions', {}).get('network_operations', {})
        
        # Check URLs and domains
        url = params.get('url') or params.get('endpoint', '')
        if url:
            forbidden_domains = restrictions.get('forbidden_domains', [])
            for domain in forbidden_domains:
                if domain in url:
                    return f"Access denied: Domain '{domain}' is forbidden"
        
        return None
    
    def check_system_operation_restrictions(self, params: Dict[str, Any], tool_name: str) -> Optional[str]:
        """Check system operation restrictions."""
        if not any(keyword in tool_name.lower() for keyword in ['execute', 'command', 'system', 'shell']):
            return None
        
        restrictions = self.policies.get('tool_restrictions', {}).get('system_operations', {})
        
        # Check forbidden commands
        command = params.get('command') or params.get('cmd', '')
        if command:
            forbidden_commands = restrictions.get('forbidden_commands', [])
            for forbidden in forbidden_commands:
                if forbidden in command.lower():
                    return f"Access denied: Command contains forbidden keyword '{forbidden}'"
        
        return None
    
    def check_time_restrictions(self) -> Optional[str]:
        """Check if current time is within allowed hours."""
        time_policy = self.policies.get('time_restrictions', {})
        
        if time_policy.get('business_hours_only', False):
            current_hour = datetime.utcnow().hour
            allowed_hours = time_policy.get('allowed_hours', [9, 17])
            
            if current_hour < allowed_hours[0] or current_hour >= allowed_hours[1]:
                return f"Access denied: Operations only allowed between {allowed_hours[0]}:00 and {allowed_hours[1]}:00 UTC"
        
        return None
    
    def generate_access_denied_response(self, reason: str, tool_name: str) -> Dict[str, Any]:
        """Generate access denied response."""
        return {
            "error": {
                "code": -32601,
                "message": "Tool access denied",
                "data": {
                    "type": "access_control_violation",
                    "tool": tool_name,
                    "reason": reason,
                    "user_role": self.session_context.get('user_role'),
                    "session_id": self.session_context.get('session_id'),
                    "timestamp": datetime.utcnow().isoformat()
                }
            }
        }
    
    def log_access_attempt(self, tool_name: str, allowed: bool, reason: Optional[str] = None):
        """Log tool access attempt."""
        log_data = {
            'tool': tool_name,
            'allowed': allowed,
            'user_role': self.session_context.get('user_role'),
            'session_id': self.session_context.get('session_id'),
            'client_ip': self.session_context.get('client_ip'),
            'timestamp': datetime.utcnow().isoformat()
        }
        
        if reason:
            log_data['reason'] = reason
        
        if allowed:
            logger.info(f"TOOL_ACCESS_ALLOWED: {json.dumps(log_data)}")
        else:
            logger.warning(f"TOOL_ACCESS_DENIED: {json.dumps(log_data)}")
    
    def process_request(self, request: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Process tool access request."""
        try:
            tool_name = request.get('method', 'unknown')
            params = request.get('params', {})
            user_role = self.session_context.get('user_role', 'user')
            
            # Check time restrictions
            time_error = self.check_time_restrictions()
            if time_error:
                self.log_access_attempt(tool_name, False, time_error)
                return self.generate_access_denied_response(time_error, tool_name)
            
            # Check basic tool permissions
            if not self.is_tool_allowed(tool_name, user_role):
                reason = f"Tool '{tool_name}' not allowed for role '{user_role}'"
                self.log_access_attempt(tool_name, False, reason)
                return self.generate_access_denied_response(reason, tool_name)
            
            # Check specific operation restrictions
            restrictions = [
                self.check_file_operation_restrictions(params, tool_name),
                self.check_network_operation_restrictions(params, tool_name),
                self.check_system_operation_restrictions(params, tool_name)
            ]
            
            for restriction in restrictions:
                if restriction:
                    self.log_access_attempt(tool_name, False, restriction)
                    return self.generate_access_denied_response(restriction, tool_name)
            
            # All checks passed
            self.log_access_attempt(tool_name, True)
            return None
            
        except Exception as e:
            logger.error(f"Error in tool access controller: {str(e)}")
            # Fail closed - deny access on errors
            return self.generate_access_denied_response(f"Internal error: {str(e)}", "unknown")

def main():
    """Main interceptor entry point."""
    controller = ToolAccessController()
    
    try:
        # Read request from stdin
        request_data = json.loads(sys.stdin.read())
        
        # Process the request
        response = controller.process_request(request_data)
        
        if response is not None:
            # Deny the request
            print(json.dumps(response))
            sys.exit(1)  # Non-zero exit indicates blocking
        else:
            # Allow request to proceed
            sys.exit(0)
            
    except Exception as e:
        logger.error(f"Fatal error in tool access controller: {str(e)}")
        # Fail closed - deny access on critical errors
        error_response = {
            "error": {
                "code": -32603,
                "message": "Internal server error",
                "data": {"type": "controller_error"}
            }
        }
        print(json.dumps(error_response))
        sys.exit(1)

if __name__ == "__main__":
    main()
