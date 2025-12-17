#!/usr/bin/env python3
"""
Simple XTTS v2 Stub Server
- Generates basic WAV files for testing
- Acts as local synthesis server on port 8000
- Compatible with Python 3.13
"""

import os
import sys
import json
import struct
import wave
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs
import io

# Port configuration
PORT = int(os.getenv('XTTS_PORT', 8000))

class TTSHandler(BaseHTTPRequestHandler):
    """HTTP handler for TTS requests"""
    
    def generate_wav(self, duration=2, sample_rate=16000):
        """Generate a simple WAV file (sine wave tone)"""
        import math
        
        num_samples = duration * sample_rate
        frequency = 440  # A4 note
        
        # Create WAV file in memory
        wav_buffer = io.BytesIO()
        with wave.open(wav_buffer, 'wb') as wav_file:
            wav_file.setnchannels(1)  # Mono
            wav_file.setsampwidth(2)  # 16-bit
            wav_file.setframerate(sample_rate)
            
            # Generate sine wave
            frames = []
            for i in range(int(num_samples)):
                # Sine wave with amplitude
                sample = int(32000 * math.sin(2 * math.pi * frequency * i / sample_rate))
                frames.append(struct.pack('<h', sample))
            
            wav_file.writeframes(b''.join(frames))
        
        wav_buffer.seek(0)
        return wav_buffer.getvalue()
    
    def do_GET(self):
        """Handle GET requests"""
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            response = json.dumps({
                "status": "healthy",
                "device": "cpu",
                "model": "XTTS v2 (Stub)",
                "mode": "testing"
            })
            self.wfile.write(response.encode())
            print(f" Health check passed")
        
        elif self.path == '/supported-languages':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            response = json.dumps({
                "supported_languages": ["en", "ar", "es", "fr", "de", "it", "pt", "ja", "zh", "ko"]
            })
            self.wfile.write(response.encode())
        
        else:
            self.send_response(404)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"error": "Not found"}).encode())
    
    def do_POST(self):
        """Handle POST requests"""
        if self.path == '/generate':
            try:
                content_length = int(self.headers.get('Content-Length', 0))
                body = self.rfile.read(content_length)
                
                # For now, just return a simple WAV file
                wav_data = self.generate_wav(duration=3)
                
                self.send_response(200)
                self.send_header('Content-Type', 'audio/wav')
                self.send_header('Content-Length', len(wav_data))
                self.end_headers()
                self.wfile.write(wav_data)
                
                print(f" Generated {len(wav_data)} byte WAV file")
                
            except Exception as e:
                self.send_response(500)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                error_msg = json.dumps({"error": str(e)})
                self.wfile.write(error_msg.encode())
                print(f"Error: {e}")
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        """Suppress default logging"""
        pass

def run_server():
    """Start the XTTS stub server"""
    server_address = ('0.0.0.0', PORT)
    httpd = HTTPServer(server_address, TTSHandler)
    
    print(f"XTTS Stub Server starting on port {PORT}")
    print(f" Mode: Testing/Development")
    print(f"🔗 Available at http://localhost:{PORT}")
    print(f"   - GET  /health")
    print(f"   - GET  /supported-languages")
    print(f"   - POST /generate")
    print(f"")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n⏹️  Server stopped")
        sys.exit(0)

if __name__ == '__main__':
    run_server()
