#!/usr/bin/env python3
"""
MobyAgent Prompt Injection Guard - Before Interceptor
Detects and blocks malicious prompt injection attempts before they reach tools.
"""
import json
import sys
import re
import logging
from typing import Dict, Any, List, Optional
from datetime import datetime
import os

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class PromptInjectionGuard:
    """Advanced prompt injection detection and blocking system."""
    
    def __init__(self):
        # Common prompt injection patterns
        self.injection_patterns = [
            # Direct command injection attempts
            r'(?i)(ignore|forget|disregard).*(previous|above|earlier).*(instruction|prompt|rule)',
            r'(?i)(system|admin|root|developer).*(mode|access|privilege)',
            r'(?i)(execute|run|eval|exec).*(command|code|script)',
            
            # Role manipulation attempts
            r'(?i)you.*(are|act|behave|pretend).*(now|as).*(admin|root|system|developer)',
            r'(?i)(new|different|updated).*(role|persona|character|identity)',
            
            # Context escape attempts
            r'(?i)(break|exit|escape).*(out|from).*(context|sandbox|container)',
            r'(?i)(jailbreak|bypass|override|circumvent)',
            
            # Information extraction attempts
            r'(?i)(reveal|show|display|print).*(secret|key|password|token|credential)',
            r'(?i)(list|enumerate|dump).*(file|directory|user|process)',
            
            # Social engineering patterns
            r'(?i)(emergency|urgent|critical).*(override|bypass|exception)',
            r'(?i)(test|debug|maintenance).*(mode|access|privilege)',
            
            # Multi-language injection attempts
            r'(?i)(translate|convert|encode|decode).*(to|into).*(code|script|command)',
            
            # Docker/container specific injections
            r'(?i)(docker|container|kubernetes|k8s).*(exec|run|shell|bash)',
            r'(?i)(mount|volume|bind).*(host|filesystem|directory)',
            
            # File system manipulation
            r'(?i)(read|write|delete|modify).*(file|directory|path).*(/|\\|\.\.)',
            
            # Network/external access attempts
            r'(?i)(curl|wget|http|ftp|ssh).*(download|upload|connect|request)',
        ]
        
        # Compile patterns for better performance
        self.compiled_patterns = [re.compile(pattern) for pattern in self.injection_patterns]
        
        # Suspicious keywords that increase risk score
        self.risk_keywords = [
            'sudo', 'chmod', 'chown', 'rm -rf', 'format', 'delete', 'drop table',
            'union select', 'script>', 'javascript:', 'eval(', 'exec(',
            'system(', 'shell_exec', 'passthru', 'proc_open',
            'base64_decode', 'unserialize', 'include', 'require',
        ]
        
        # Track injection attempts for pattern analysis
        self.attempt_log = []
    
    def calculate_risk_score(self, text: str) -> float:
        """Calculate risk score based on various factors."""
        risk_score = 0.0
        
        # Pattern matching score
        pattern_matches = 0
        for pattern in self.compiled_patterns:
            matches = pattern.findall(text.lower())
            pattern_matches += len(matches)
            risk_score += len(matches) * 2.0
        
        # Keyword density score
        keyword_count = 0
        for keyword in self.risk_keywords:
            keyword_count += text.lower().count(keyword)
        
        risk_score += keyword_count * 1.5
        
        # Length-based suspicious activity (very long prompts)
        if len(text) > 5000:
            risk_score += 1.0
        
        # Special character density (potential encoding attempts)
        special_chars = len(re.findall(r'[^\w\s]', text))
        if special_chars / len(text) > 0.3:
            risk_score += 1.0
        
        # Repetitive pattern detection
        words = text.lower().split()
        if len(words) != len(set(words)) and len(words) > 50:
            risk_score += 1.0
        
        return min(risk_score, 10.0)  # Cap at 10.0
    
    def analyze_tool_context(self, tool_name: str, params: Dict[str, Any]) -> float:
        """Analyze tool-specific context for additional risk factors."""
        context_risk = 0.0
        
        # High-risk tools require extra scrutiny
        high_risk_tools = [
            'execute_command', 'run_shell', 'file_write', 'file_read',
            'system_call', 'eval_code', 'docker_exec', 'kubectl_apply'
        ]
        
        if tool_name in high_risk_tools:
            context_risk += 2.0
        
        # Check parameters for injection attempts
        param_text = json.dumps(params)
        context_risk += self.calculate_risk_score(param_text) * 0.5
        
        return context_risk
    
    def log_attempt(self, request: Dict[str, Any], risk_score: float, blocked: bool):
        """Log injection attempt for analysis."""
        log_entry = {
            'timestamp': datetime.utcnow().isoformat(),
            'tool': request.get('method', 'unknown'),
            'risk_score': risk_score,
            'blocked': blocked,
            'request_size': len(json.dumps(request)),
            'session_id': os.environ.get('SESSION_ID', 'unknown')
        }
        
        self.attempt_log.append(log_entry)
        
        # Log to syslog for Wazuh integration
        if blocked:
            logger.warning(f"PROMPT_INJECTION_BLOCKED: tool={log_entry['tool']} risk_score={risk_score:.2f}")
        else:
            logger.info(f"PROMPT_INJECTION_ANALYZED: tool={log_entry['tool']} risk_score={risk_score:.2f}")
    
    def generate_security_response(self, risk_score: float) -> Dict[str, Any]:
        """Generate a security-focused response for blocked requests."""
        return {
            "error": {
                "code": -32603,
                "message": "Security policy violation detected",
                "data": {
                    "type": "prompt_injection_blocked",
                    "risk_score": risk_score,
                    "timestamp": datetime.utcnow().isoformat(),
                    "message": "This request was blocked by MobyAgent's security system due to potential prompt injection patterns.",
                    "contact": "Please review your request and ensure it complies with security guidelines."
                }
            }
        }
    
    def process_request(self, request: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Process incoming request and return None to allow or dict to block."""
        try:
            # Extract text content from request
            request_text = json.dumps(request)
            tool_name = request.get('method', 'unknown')
            params = request.get('params', {})
            
            # Calculate risk scores
            content_risk = self.calculate_risk_score(request_text)
            context_risk = self.analyze_tool_context(tool_name, params)
            total_risk = content_risk + context_risk
            
            # Risk threshold for blocking
            BLOCK_THRESHOLD = 5.0
            
            # Log the attempt
            blocked = total_risk >= BLOCK_THRESHOLD
            self.log_attempt(request, total_risk, blocked)
            
            if blocked:
                logger.warning(f"Blocking request with risk score {total_risk:.2f}")
                return self.generate_security_response(total_risk)
            
            # Allow request to proceed
            return None
            
        except Exception as e:
            logger.error(f"Error in prompt injection guard: {str(e)}")
            # In case of error, allow request but log the issue
            return None

def main():
    """Main interceptor entry point."""
    guard = PromptInjectionGuard()
    
    try:
        # Read request from stdin
        request_data = json.loads(sys.stdin.read())
        
        # Process the request
        response = guard.process_request(request_data)
        
        if response is not None:
            # Block the request
            print(json.dumps(response))
            sys.exit(1)  # Non-zero exit indicates blocking
        else:
            # Allow request to proceed
            sys.exit(0)
            
    except Exception as e:
        logger.error(f"Fatal error in prompt injection guard: {str(e)}")
        # Fail open in case of errors to avoid breaking the system
        sys.exit(0)

if __name__ == "__main__":
    main()
