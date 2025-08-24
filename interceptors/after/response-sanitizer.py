#!/usr/bin/env python3
"""
MobyAgent Response Sanitizer Interceptor
Cleans and secures responses before sending to clients

This interceptor:
1. Removes or redacts sensitive information
2. Filters out secrets and API keys
3. Applies PII protection
4. Enforces response size limits
5. Validates response format
"""

import json
import re
import sys
import logging
import hashlib
import time
from typing import Dict, List, Any, Tuple
import secrets
import string

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('/var/log/interceptors/response-sanitizer.log')
    ]
)
logger = logging.getLogger(__name__)

class ResponseSanitizer:
    """Advanced response sanitization and security filtering"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.remove_secrets = config.get('remove_secrets', True)
        self.redact_pii = config.get('redact_pii', True)
        self.max_response_size = config.get('max_response_size', 50000)
        
        # Secret patterns
        self.secret_patterns = [
            # API Keys
            (r'\b[A-Za-z0-9]{32}\b', 'API_KEY'),
            (r'\bsk-[A-Za-z0-9]{48}\b', 'OPENAI_KEY'),
            (r'\bghp_[A-Za-z0-9]{36}\b', 'GITHUB_TOKEN'),
            (r'\bglpat-[A-Za-z0-9_\-]{20}\b', 'GITLAB_TOKEN'),
            (r'\bAKIA[0-9A-Z]{16}\b', 'AWS_ACCESS_KEY'),
            (r'\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b', 'UUID_TOKEN'),
            
            # Database connection strings
            (r'(mysql|postgresql|mongodb)://[^\s]+', 'DATABASE_URL'),
            (r'jdbc:[^\s]+', 'JDBC_URL'),
            
            # Private keys
            (r'-----BEGIN [A-Z ]+ KEY-----[\s\S]*?-----END [A-Z ]+ KEY-----', 'PRIVATE_KEY'),
            (r'-----BEGIN CERTIFICATE-----[\s\S]*?-----END CERTIFICATE-----', 'CERTIFICATE'),
            
            # Common secret keywords
            (r'(?i)(password|passwd|pwd)\s*[:=]\s*["\']?([^\s"\',]+)', 'PASSWORD'),
            (r'(?i)(secret|token|key)\s*[:=]\s*["\']?([^\s"\',]+)', 'SECRET'),
            (r'(?i)api[_-]?key\s*[:=]\s*["\']?([^\s"\',]+)', 'API_KEY'),
        ]
        
        # PII patterns
        self.pii_patterns = [
            # Email addresses
            (r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', 'EMAIL'),
            
            # Phone numbers
            (r'\b(?:\+?1[-.]?)?\(?([0-9]{3})\)?[-.]?([0-9]{3})[-.]?([0-9]{4})\b', 'PHONE'),
            (r'\b\+[1-9]\d{1,14}\b', 'INTERNATIONAL_PHONE'),
            
            # SSN
            (r'\b\d{3}-\d{2}-\d{4}\b', 'SSN'),
            (r'\b\d{3}\s\d{2}\s\d{4}\b', 'SSN'),
            
            # Credit Card Numbers (basic pattern)
            (r'\b4[0-9]{12}(?:[0-9]{3})?\b', 'VISA_CC'),
            (r'\b5[1-5][0-9]{14}\b', 'MASTERCARD_CC'),
            (r'\b3[47][0-9]{13}\b', 'AMEX_CC'),
            
            # IP Addresses (when they might be PII)
            (r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b', 'IP_ADDRESS'),
            
            # URLs that might contain sensitive info
            (r'https?://[^\s]+(?:token|key|password|secret)=[^\s&]+', 'SENSITIVE_URL'),
        ]
        
        # Additional patterns from config
        config_secret_patterns = config.get('secret_patterns', [])
        for pattern in config_secret_patterns:
            self.secret_patterns.append((pattern, 'CUSTOM_SECRET'))
        
        config_pii_patterns = config.get('pii_patterns', [])
        for pattern in config_pii_patterns:
            self.pii_patterns.append((pattern, 'CUSTOM_PII'))
        
        # Compile regex patterns
        self.compiled_secret_patterns = [(re.compile(pattern, re.IGNORECASE), label) for pattern, label in self.secret_patterns]
        self.compiled_pii_patterns = [(re.compile(pattern, re.IGNORECASE), label) for pattern, label in self.pii_patterns]
        
        # Redaction replacements
        self.redaction_map = {}
    
    def generate_redaction_token(self, data_type: str) -> str:
        """Generate a consistent redaction token for the same sensitive data"""
        # Generate a short random identifier
        random_id = ''.join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(6))
        return f"[REDACTED_{data_type}_{random_id}]"
    
    def sanitize_secrets(self, text: str) -> Tuple[str, List[Dict[str, Any]]]:
        """Remove or redact secrets from text"""
        sanitized_text = text
        detections = []
        
        for pattern, label in self.compiled_secret_patterns:
            matches = pattern.findall(sanitized_text)
            for match in matches:
                if isinstance(match, tuple):  # Group match
                    secret_value = match[-1]  # Last group usually contains the value
                else:
                    secret_value = match
                
                if len(secret_value) > 3:  # Only redact if reasonably long
                    # Generate consistent redaction token
                    secret_hash = hashlib.sha256(secret_value.encode()).hexdigest()[:8]
                    if secret_hash not in self.redaction_map:
                        self.redaction_map[secret_hash] = self.generate_redaction_token(label)
                    
                    redaction_token = self.redaction_map[secret_hash]
                    sanitized_text = sanitized_text.replace(secret_value, redaction_token)
                    
                    detections.append({
                        'type': 'secret',
                        'label': label,
                        'original_length': len(secret_value),
                        'redacted_as': redaction_token,
                        'pattern_matched': pattern.pattern[:50] + '...' if len(pattern.pattern) > 50 else pattern.pattern
                    })
        
        return sanitized_text, detections
    
    def sanitize_pii(self, text: str) -> Tuple[str, List[Dict[str, Any]]]:
        """Remove or redact PII from text"""
        sanitized_text = text
        detections = []
        
        for pattern, label in self.compiled_pii_patterns:
            matches = pattern.finditer(sanitized_text)
            for match in matches:
                pii_value = match.group()
                
                # Generate consistent redaction token
                pii_hash = hashlib.sha256(pii_value.encode()).hexdigest()[:8]
                if pii_hash not in self.redaction_map:
                    self.redaction_map[pii_hash] = self.generate_redaction_token(label)
                
                redaction_token = self.redaction_map[pii_hash]
                sanitized_text = sanitized_text.replace(pii_value, redaction_token)
                
                detections.append({
                    'type': 'pii',
                    'label': label,
                    'original_length': len(pii_value),
                    'redacted_as': redaction_token,
                    'position': match.span()
                })
        
        return sanitized_text, detections
    
    def validate_response_format(self, response: Any) -> Tuple[bool, str]:
        """Validate response format and structure"""
        try:
            if isinstance(response, dict):
                # Check for required fields in structured responses
                if 'error' in response and not isinstance(response.get('error'), (str, dict)):
                    return False, "Invalid error format"
                
                # Check for suspicious structures
                if 'eval' in str(response).lower() or 'exec' in str(response).lower():
                    return False, "Suspicious code execution patterns detected"
                
            elif isinstance(response, str):
                # Check for code injection patterns
                suspicious_patterns = [
                    r'<script[^>]*>.*?</script>',
                    r'javascript:',
                    r'on\w+\s*=',
                    r'eval\s*\(',
                    r'exec\s*\(',
                ]
                
                for pattern in suspicious_patterns:
                    if re.search(pattern, response, re.IGNORECASE | re.DOTALL):
                        return False, f"Suspicious pattern detected: {pattern}"
            
            return True, "Valid format"
            
        except Exception as e:
            return False, f"Validation error: {str(e)}"
    
    def sanitize_response(self, response_data: Dict[str, Any]) -> Dict[str, Any]:
        """Main sanitization logic"""
        sanitization_start = time.time()
        
        try:
            # Extract response content
            response_text = ""
            if 'response' in response_data:
                if isinstance(response_data['response'], str):
                    response_text = response_data['response']
                elif isinstance(response_data['response'], dict):
                    response_text = json.dumps(response_data['response'])
            elif 'content' in response_data:
                response_text = str(response_data['content'])
            elif 'message' in response_data:
                response_text = str(response_data['message'])
            else:
                # Try to find text in the response
                response_text = json.dumps(response_data)
            
            # Check response size
            if len(response_text) > self.max_response_size:
                logger.warning(f"Response too large: {len(response_text)} bytes, truncating to {self.max_response_size}")
                response_text = response_text[:self.max_response_size] + "\n[TRUNCATED - Response too large]"
            
            # Validate format
            is_valid, validation_message = self.validate_response_format(response_data)
            if not is_valid:
                return {
                    'action': 'block',
                    'reason': 'invalid_response_format',
                    'details': validation_message,
                    'sanitization_time': time.time() - sanitization_start
                }
            
            original_length = len(response_text)
            sanitized_text = response_text
            all_detections = []
            
            # Sanitize secrets
            if self.remove_secrets:
                sanitized_text, secret_detections = self.sanitize_secrets(sanitized_text)
                all_detections.extend(secret_detections)
            
            # Sanitize PII
            if self.redact_pii:
                sanitized_text, pii_detections = self.sanitize_pii(sanitized_text)
                all_detections.extend(pii_detections)
            
            # Update response data
            sanitized_response = response_data.copy()
            
            if 'response' in response_data:
                if isinstance(response_data['response'], str):
                    sanitized_response['response'] = sanitized_text
                elif isinstance(response_data['response'], dict):
                    try:
                        sanitized_response['response'] = json.loads(sanitized_text)
                    except json.JSONDecodeError:
                        sanitized_response['response'] = sanitized_text
            elif 'content' in response_data:
                sanitized_response['content'] = sanitized_text
            elif 'message' in response_data:
                sanitized_response['message'] = sanitized_text
            
            # Add sanitization metadata
            sanitization_info = {
                'sanitized': len(all_detections) > 0,
                'detections_count': len(all_detections),
                'original_size': original_length,
                'sanitized_size': len(sanitized_text),
                'processing_time': time.time() - sanitization_start
            }
            
            if all_detections:
                logger.info(f"Sanitized response: {len(all_detections)} items redacted")
                # Don't include detailed detection info in response for security
                sanitization_info['redacted_types'] = list(set(d['type'] for d in all_detections))
            
            return {
                'action': 'allow',
                'reason': 'sanitization_complete',
                'response': sanitized_response,
                'sanitization_info': sanitization_info
            }
            
        except Exception as e:
            logger.error(f"Response sanitization error: {e}")
            return {
                'action': 'block',
                'reason': 'sanitization_error',
                'error': str(e),
                'sanitization_time': time.time() - sanitization_start
            }

def main():
    """CLI interface for the interceptor"""
    if len(sys.argv) != 2:
        print("Usage: response-sanitizer.py <response_json>")
        sys.exit(1)
    
    try:
        # Load response data
        response_json = sys.argv[1]
        response_data = json.loads(response_json)
        
        # Load configuration
        config = {
            'remove_secrets': True,
            'redact_pii': True,
            'max_response_size': 50000,
            'secret_patterns': ['password', 'api_key', 'token', 'secret', 'private_key'],
            'pii_patterns': ['email', 'phone', 'ssn', 'credit_card']
        }
        
        # Initialize and run the sanitizer
        sanitizer = ResponseSanitizer(config)
        result = sanitizer.sanitize_response(response_data)
        
        # Output result
        print(json.dumps(result, indent=2))
        
        # Exit with appropriate code
        sys.exit(0 if result['action'] == 'allow' else 1)
        
    except Exception as e:
        error_result = {
            'action': 'block',
            'reason': 'interceptor_error',
            'error': str(e)
        }
        print(json.dumps(error_result, indent=2))
        sys.exit(1)

if __name__ == '__main__':
    main()
