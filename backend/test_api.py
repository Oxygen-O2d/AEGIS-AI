import asyncio
import os
from dotenv import load_dotenv
from openai import AsyncOpenAI

# Load keys from .env
load_dotenv()
NVIDIA_API_KEY = os.getenv("NVIDIA_API_KEY")
GROQ_API_KEY = os.getenv("GROQ_API_KEY")

if not NVIDIA_API_KEY or not GROQ_API_KEY:
    print("❌ ERROR: Missing API keys in .env file.")
    exit(1)

# Initialize Clients
nvidia_client = AsyncOpenAI(base_url="https://integrate.api.nvidia.com/v1", api_key=NVIDIA_API_KEY)
groq_client = AsyncOpenAI(base_url="https://api.groq.com/openai/v1", api_key=GROQ_API_KEY)

async def test_apis():
    print("🚀 Igniting Subsume API Connections...\n")
    test_log = '{"event": "POST /login username=admin\' OR \'1\'=\'1", "ip": "185.220.101.45"}'

    try:
        print("1. Testing Groq (Llama-3.1-8b) Fast Triage...")
        groq_res = await groq_client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=[{"role": "user", "content": f"Classify this threat in 5 words: {test_log}"}]
        )
        print(f"✅ GROQ SUCCESS: {groq_res.choices[0].message.content}\n")

        print("2. Testing NVIDIA (DeepSeek-V3) Heavy Reasoning...")
        nv_res = await nvidia_client.chat.completions.create(
            model="deepseek-ai/deepseek-v3.2",
            messages=[{"role": "user", "content": f"What MITRE ATT&CK technique is this: {test_log}"}]
        )
        print(f"✅ NVIDIA SUCCESS: {nv_res.choices[0].message.content}\n")

        print("🔥 ALL SYSTEMS NOMINAL. YOU ARE READY TO BUILD.")

    except Exception as e:
        print(f"❌ CONNECTION FAILED: {str(e)}")

if __name__ == "__main__":
    asyncio.run(test_apis())