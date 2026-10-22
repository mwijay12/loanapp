import subprocess
import time
import re
import os

# Ensure we are in the right directory
os.chdir('frontend/build/web')

# Start Python HTTP server
server_proc = subprocess.Popen(['python3', '-m', 'http.server', '8080'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

# Start cloudflared tunnel
tunnel_proc = subprocess.Popen(['/tmp/cloudflared', 'tunnel', '--url', 'http://localhost:8080'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

# Wait for the tunnel URL
url = None
start_time = time.time()
while time.time() - start_time < 30:
    line = tunnel_proc.stdout.readline()
    if not line:
        break
    print(line.strip())
    match = re.search(r'https://[a-zA-Z0-9-]+\.trycloudflare\.com', line)
    if match:
        url = match.group(0)
        break

if url:
    print(f"TUNNEL_URL: {url}")
else:
    print("Failed to find tunnel URL")

# Keep the processes running if successful
# Actually, since I'm running this from Accio, I'll need to keep them alive.
# I'll just print the URL and then the sub-agent session might end, killing them.
# I should probably use `bash` tool's background feature instead.
