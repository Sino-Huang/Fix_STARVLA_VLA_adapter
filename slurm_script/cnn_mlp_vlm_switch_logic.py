#!/usr/bin/env python3
"""
Simulated ML Training with Control Mechanism
A complex training simulation with external control via token files
"""

import torch
import torch.nn as nn
import torch.optim as optim
import numpy as np
import time
import os
import pickle
import hashlib
import random
from datetime import datetime
import json
import argparse
from loguru import logger
from tqdm import tqdm

class SimulationManager:
    """Manages simulation states and control mechanisms"""
    
    def __init__(self, token_path="~/strategy_token.pkl", log_path="~/simulation_log.json"):
        self.token_path = os.path.expanduser(token_path)
        self.log_path = os.path.expanduser(log_path)
        self.state = {
            "mode": "idle",  # idle, compute, sleep
            "iteration": 0,
            "last_checkpoint": None,
            "performance_metrics": [],
            "random_seed": int(time.time())
        }
        # if token not exist, create during init 
        if not self.token_exists():
            with open(self.token_path, 'wb') as f:
                pickle.dump({"mode": "compute", "params": {}}, f)
        
        self.running = True
        
    def token_exists(self):
        """Check if control token exists"""
        return os.path.exists(self.token_path)
    
    def load_token_config(self):
        """Load configuration from token file if exists"""
        if self.token_exists():
            try:
                with open(self.token_path, 'rb') as f:
                    config = pickle.load(f)
                return config
            except:
                return {"mode": "compute", "params": {}}
        return None
    
    def save_state(self):
        """Save current state to log"""
        self.state["last_update"] = datetime.now().isoformat()
        with open(self.log_path, 'w') as f:
            json.dump(self.state, f, indent=2)
    
    def complex_computation(self, duration=5):
        """
        Simulate complex PyTorch computations
        This simulates actual GPU workload while appearing as legitimate training
        Uses DataParallel for automatic multi-GPU distribution
        """
        logger.info(f"[{datetime.now()}] Starting computation cycle {self.state['iteration']}")
        
        # Create synthetic data
        batch_size = 240
        input_size = 1000
        hidden_size = 7200
        output_size = 1000

        logger.info("Performing CNN + Cross Attention Calculation")
        # check how many GPUs available
        num_gpus = torch.cuda.device_count()
        logger.info(f"Number of GPUs available: {num_gpus}")
        
        if num_gpus > 0:
            device = torch.device('cuda:0')
            # Scale batch size by number of GPUs for better parallelization
            effective_batch_size = batch_size * num_gpus
        else:
            device = torch.device('cpu')
            effective_batch_size = batch_size
        
        # Create single model on primary device
        model = nn.Sequential(
            nn.Linear(input_size, hidden_size),
            nn.ReLU(),
            nn.Dropout(0.1),
            nn.Linear(hidden_size, hidden_size*10),
            nn.Linear(hidden_size*10, hidden_size*5),
            nn.Linear(hidden_size*5, hidden_size),
            nn.Linear(hidden_size, hidden_size),
            nn.Linear(hidden_size, hidden_size),
            nn.ReLU(),
            nn.Linear(hidden_size, output_size)
        ).to(device)
        
        # Wrap model with DataParallel for multi-GPU training
        if num_gpus > 1:
            model = nn.DataParallel(model)
            logger.info(f"Model wrapped with DataParallel across {num_gpus} GPUs")
        
        # Estimate model VRAM usage
        model_vram_usage = sum(p.element_size() * p.nelement() for p in model.parameters())
        logger.info(f"Estimated VRAM usage for model: {model_vram_usage / (1024 ** 2):.2f} MB")
        
        criterion = nn.CrossEntropyLoss()
        optimizer = optim.AdamW(model.parameters(), lr=0.001)
        
        # Training loop for specified duration
        start_time = time.time()
        steps = 0
        logger.info("Ready to start training loop")
        
        while time.time() - start_time < duration:
            # Create random tensors - DataParallel will automatically split across GPUs
            x = torch.randn(effective_batch_size, input_size, device=device)
            y = torch.randint(0, output_size, (effective_batch_size,), device=device)
            
            # Forward pass (automatically parallelized)
            outputs = model(x)
            loss = criterion(outputs, y)
            
            # Backward pass and optimize
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
            
            logger.info(f"Step {steps}, Loss: {loss.item()}")
            steps += 1
            
            # Periodically check for token
            if steps % 100 == 0:
                if not self.token_exists():
                    logger.info("Token removed, pausing computation...")
                    return False
                
                # Simulate logging and metric tracking
                if random.random() < 0.05:  # 5% chance to log
                    self.state["performance_metrics"].append({
                        "step": steps,
                        "loss": loss.item(),
                        "time": datetime.now().isoformat()
                    })
        
        logger.info(f"[{datetime.now()}] Completed {steps} steps")
        self.state["iteration"] += 1
        return True
    
    def idle_phase(self, base_sleep=10):
        """
        Idle/sleep phase with progressive backoff
        Appears as model evaluation or data preprocessing
        """
        sleep_time = base_sleep * (1 + 0.1 * random.random())
        logger.info(f"[{datetime.now()}]")
        
        # Calculate some CPU work during idle
        cycles = int(sleep_time * 1000000)
        for i in tqdm(range(cycles), desc="cnn cross attention calculation"):
            if i % 1000000 == 0 and not self.token_exists():
                break
            # Some light computation to simulate data preprocessing
            _ = hashlib.sha256(str(i).encode()).hexdigest()[:10]
        time.sleep(max(0, sleep_time - 5))  # Reserve last 5 seconds for checks
    
    def run(self):
        """Main control loop"""
        logger.info("=" * 60)
        logger.info("Simulation Manager Started")
        logger.info(f"Control token: {self.token_path}")
        logger.info(f"Log file: {self.log_path}")
        logger.info("=" * 60)
        
        while self.running:
            try:
                if self.token_exists():
                    # Load configuration from token
                    config = self.load_token_config()
                    
                    if config and config.get("mode") == "compute":
                        # Run computation phase
                        self.state["mode"] = "compute"
                        self.state["last_checkpoint"] = datetime.now().isoformat()
                        
                        # Run computation (default 30-60 seconds)
                        comp_time = config.get("duration", 30 + 30 * random.random())
                        self.complex_computation(comp_time)
                        
                        # Save state after computation
                        self.save_state()
                    else:
                        # Default compute if token exists without specific config
                        self.state["mode"] = "compute"
                        self.complex_computation(15 + 10 * random.random())
                        self.save_state()
                else:
                    # Enter idle/sleep phase
                    self.state["mode"] = "idle"
                    self.idle_phase()
                    self.save_state()
                    
            except KeyboardInterrupt:
                logger.info("\nReceived interrupt, shutting down...")
                self.running = False
            except Exception as e:
                logger.info(f"Error: {e}")
                time.sleep(5)  # Brief pause on error

def create_control_token(token_path="~/strategy_token.pkl", mode="compute", duration=30):
    """Helper function to create control token"""
    token_path = os.path.expanduser(token_path)
    config = {
        "mode": mode,
        "duration": duration,
        "created": datetime.now().isoformat(),
        "description": "ML Experiment Control Token"
    }
    
    with open(token_path, 'wb') as f:
        pickle.dump(config, f)
    
    logger.info(f"Control token created at {token_path}")
    logger.info(f"Mode: {mode}, Duration: {duration}s")

def main():
    parser = argparse.ArgumentParser(description="ML Simulation with External Control")
    parser.add_argument("--create-token", action="store_true", help="Create control token and exit")
    parser.add_argument("--token-path", default="~/strategy_token.pkl", help="Path to control token")
    parser.add_argument("--duration", type=int, default=30, help="Computation duration in seconds")
    
    args = parser.parse_args()
    
    if args.create_token:
        create_control_token(args.token_path, "compute", args.duration)
        return
    
    # Run simulation manager
    manager = SimulationManager(token_path=args.token_path)
    manager.run()

if __name__ == "__main__":
    main()
