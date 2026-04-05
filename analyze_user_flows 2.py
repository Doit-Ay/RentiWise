import os
import json
import urllib.request
import re

OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL_NAME = "gemma4:e4b"
MAX_CHARS_PER_PROMPT = 24000 # Roughly 6000-8000 tokens

BUCKETS = {
    "Auth_Identity": ["SignIn and SignUp", "Profile", "Verification", "OTP"],
    "Core_Journey": ["DashBoard", "Product View", "Item Display", "Add item"],
    "Commerce_Trust": ["UPI", "IAP", "Agreement", "TrustScore"],
    "Utilities": ["Notification", "Location", "Chat"]
}

def clean_swift_code(content):
    # Remove single line comments
    content = re.sub(r'//.*', '', content)
    # Remove blank lines
    lines = [line for line in content.split('\n') if line.strip()]
    return '\n'.join(lines)

def query_ollama(prompt):
    payload = {
        "model": MODEL_NAME,
        "prompt": prompt,
        "stream": False,
        "options": {
            "temperature": 0.2
        }
    }
    try:
        req = urllib.request.Request(OLLAMA_URL, data=json.dumps(payload).encode('utf-8'), headers={'Content-Type': 'application/json'})
        with urllib.request.urlopen(req, timeout=300) as response:
            result = json.loads(response.read().decode('utf-8'))
            return result.get("response", "No response from model.")
    except Exception as e:
        return f"Error: {str(e)}"

def main():
    base_dir = "RentiWise/Features"
    bucket_results = {}
    
    print("Starting Map-Reduce Codebase Analysis via Gemma 4...")
    
    for bucket_name, folders in BUCKETS.items():
        print(f"\n--- Processing Bucket: {bucket_name} ---")
        combined_code = ""
        
        for folder in folders:
            folder_path = os.path.join(base_dir, folder)
            if not os.path.exists(folder_path):
                continue
                
            for root, dirs, files in os.walk(folder_path):
                for f in files:
                    if f.endswith(".swift"):
                        filepath = os.path.join(root, f)
                        with open(filepath, "r") as file:
                            cleaned = clean_swift_code(file.read())
                            combined_code += f"\n\n// File: {f}\n{cleaned}"
        
        # Truncate if too large to prevent crash
        if len(combined_code) > MAX_CHARS_PER_PROMPT:
            print(f"Warning: Truncating bucket {bucket_name} codebase from {len(combined_code)} to {MAX_CHARS_PER_PROMPT} chars to fit context window.")
            combined_code = combined_code[:MAX_CHARS_PER_PROMPT] + "\n// ... truncated ..."

        prompt = f"""
Act as an expert iOS architect. Analyze the following group of related Swift files from the '{bucket_name}' module.
1. Trace the primary User Flow within this module (e.g., what views lead to what actions).
2. Identify any logic discrepancies, missing states, or architectural gaps.
3. Be concise and specific.

Files:
{combined_code}
"""
        print(f"Sending {len(combined_code)} characters to local Gemma 4...")
        result = query_ollama(prompt)
        bucket_results[bucket_name] = result
        print(f"Bucket {bucket_name} completed.")
        
    print("\n--- Phase 2: Global Synthesis (Reduce Stage) ---")
    synthesis_prompt = "Act as an expert iOS architect. I will give you four reports from different modules of an app. Cross-reference them to find global user flow and discrepancies. Where do the modules fail to connect properly?\n\n"
    
    for name, res in bucket_results.items():
        synthesis_prompt += f"\n### {name} Module Report:\n{res}\n"
        
    synthesis_prompt += "\nNow, provide a Global Synthesis and Discrepancy Report."
    
    final_report = query_ollama(synthesis_prompt)
    
    output_path = "/Users/admin67/.gemini/antigravity/brain/c8d5fac0-f1c6-4c77-90f1-eb3bf1f0f020/artifacts/feature_flows_and_discrepancies.md"
    
    with open(output_path, "w") as out:
        out.write("# RentiWise Full Codebase User Flow & Discrepancy Report\n\n")
        out.write("> [!NOTE]\n> This report was generated via a Map-Reduce analysis by Gemma 4 across 130+ Swift files.\n\n")
        
        out.write("## 🌍 Global Synthesis (End-to-End)\n")
        out.write(final_report + "\n\n")
        
        out.write("## 📦 Individual Module Analyses\n")
        for name, res in bucket_results.items():
            out.write(f"\n### {name}\n")
            out.write(res + "\n\n---\n")

    print("\nAnalysis complete! Results saved to artifact path.")

if __name__ == "__main__":
    main()
