import json
import asyncio
import pandas as pd
import time
from app.services.llm_router import get_fast_triage, get_attack_prediction, verify_safety

async def run_evaluator():
    print("🚀 Igniting Subsume Automated Benchmark Engine...\n")
    
    # Load your dataset
    try:
        with open("data/model_eval_dataset.json", "r") as f:
            dataset = json.load(f)
    except FileNotFoundError:
        print("❌ ERROR: Could not find data/model_eval_dataset.json")
        return

    results = []
    
    # We are still slicing to [:5] for safety. 
    # Change to dataset["test_cases"] to run all 80!
    test_batch = dataset["test_cases"][:5]
    
    for case in test_batch:
        print(f"🧪 Testing {case['id']} | {case['category']} -> {case['model_target']}")
        
        prompt = case["prompt"]
        expected = case["expected_keywords_in_response"]
        actual_response = ""
        
        try:
            # Route to the correct function based on the dataset's target model
            if case["model_target"] == "llama-3.1-8b-instant":
                # This goes to Groq. If you changed llm_router.py to use 70B, it will use 70B!
                actual_response = await get_fast_triage(prompt)
            
            elif case["model_target"] in ["deepseek-v3.2", "nemotron-3-super-120b-a12b"]:
                # This routes heavy reasoning to NVIDIA NIM
                actual_response = await get_attack_prediction(prompt)
            
            elif case["model_target"] == "nemotron-content-safety-reasoning-4b":
                # This routes safety checks to the Nemotron safety model
                actual_response = await verify_safety(prompt)
            
            else:
                actual_response = "SKIPPED - Model not implemented"
                
            # Print the exact string the LLM generated so you can prove it's valid JSON
            print(f"   ↳ RAW OUTPUT: {actual_response}")
            
            # The Scoring Logic (Checks if the expected words are inside the returned string)
            found_words = [word for word in expected if word.lower() in actual_response.lower()]
            percentage = (len(found_words) / len(expected)) * 100 if expected else 0
            
            score = 0
            if percentage >= 80: score = 3
            elif percentage >= 50: score = 1
            
            results.append({
                "Test_ID": case["id"],
                "Category": case["category"],
                "Keywords_Found": f"{len(found_words)}/{len(expected)}",
                "Accuracy_%": round(percentage, 1),
                "Score": score
            })
            
            print(f"   ↳ Score: {score}/3 ({percentage:.0f}% match)\n")
            
            # Sleep for 2 seconds to avoid Rate Limit HTTP 429 Errors on free tiers
            time.sleep(2)
            
        except Exception as e:
            print(f"   ↳ ❌ ERROR: {str(e)}\n")
    
    # Generate the Proof (CSV Report)
    df = pd.DataFrame(results)
    df.to_csv("benchmark_results.csv", index=False)
    print("✅ Benchmark Complete! Results saved to benchmark_results.csv")

if __name__ == "__main__":
    asyncio.run(run_evaluator())