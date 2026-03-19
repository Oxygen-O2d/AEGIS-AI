import os
from dotenv import load_dotenv

# Load environment variables from the .env file
load_dotenv()

NVIDIA_API_KEY = os.getenv("NVIDIA_API_KEY")
GROQ_API_KEY = os.getenv("GROQ_API_KEY")

# Brutal validation: Fail immediately if keys are missing
if not NVIDIA_API_KEY or not GROQ_API_KEY:
    raise ValueError("CRITICAL: Missing API Keys in .env file. Please check your configuration.")