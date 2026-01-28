from dataclasses import dataclass, fields, asdict
import os
from typing import List, Optional
import sqlite3
from pathlib import Path
import fcntl
import time
import pandas as pd
from tqdm import tqdm

# TODO, make it fit for LIBERO eval results
DEFAULT_EVAL_ROUND_ID = "LIBERO_PRELIM_TEST_VISION_HYPOTHESIS_V1"

CHECK_EXIST_COLUMNS = ['eval_round_id', 'train_id', 'checkpoint_step', 'model_arch',
                       'training_strategy', 'env_name', 'task_suite_name', 'problem_id', 'seed',
                       'vision_granularity', 'instruction_type', 'instruction_value']

@dataclass
class EvalResult:
    # --- 1. Experiment Identifiers ---
    eval_round_id: str      # UUID for this specific evaluation batch
    train_id: str           # Unique ID for the training run
    timestamp: str          # Time of evaluation
    checkpoint_step: int    # Step number (X-axis for learning curves)

    # --- 2. Model & Method Configuration (Separated) ---
    # The Architecture (The "Body")
    model_arch: str         
    # Examples: "OpenVLA-7B", "Qwen2-VL-7B-OFT", "VLA-Adapter", "RT-2-X"
    
    # The Training Recipe (The "Soul")
    training_strategy: str  
    # Examples: "Ours-PureHER", "Ablation-WithKL", "Baseline-BC", "VisGranularity-Mixed"

    # --- 3. Evaluation Conditions (The "Test Paper") ---
    # These define "How" you are testing the model right now.
    env_name: str           # "LIBERO", "RoboTwin", "Custom-Trap"
    task_suite_name: str    # "libero_spatial", "trap_linear_stage"
    problem_id: int         # Specific task instance ID
    
    # Visual Conditions (Critical for your Spectrum Plots)
    vision_granularity: str # "224", "128", "32", "Mask", "Depth"
    
    # Language Conditions (Critical for your "Null Instruction" Gap)
    instruction_type: str   # "l" (standard), "null" (empty/pad), "detailed" (l+d) (l+d+d)
    instruction_value: str  # Actual instruction text used
    
    # --- 4. Detailed Metrics (The "Answers") ---
    success: bool           # Binary success
    seed: Optional[int] = -1     # Random seed used for eval run
    
    # Other detailed metrics
    is_ood_visual: bool = False     # True if evaluating on randomized textures/lighting
    is_ood_language: bool = False   # True if evaluating on modified/null instructions
    # [Critical for Temporal Collapse / KL Experiment]
    # Did it finish step 1 (get sponge) but fail step 2 (wash plate)?
    max_completed_stage: int = -1 # e.g., 1
    total_stages: int = -1       # e.g., 2
    
    # [Critical for Ambiguity/Hallucination Experiment]
    # Did it interact with "red_cup" or "blue_cup"?
    primary_interaction_object: str = ""
    
    # [Optional] For debugging
    failure_reason: str = "" # "timeout", "grasp_miss", "wrong_sequence"
    
class DatabaseHelper:
    def __init__(self, db_name=Path(__file__).parent.parent.parent / 'results' / "starvla_eval_results.db"):
        self.db_name = db_name
        self.lock_file = Path(str(db_name) + ".lock")
        self.lock_fd = None
        self.conn = sqlite3.connect(db_name)
        self.cursor = self.conn.cursor()
        self.create_table()
        
    def check_if_exists(self, eval_result: EvalResult) -> bool:
        self._acquire_lock()
        try:
            # check all fields except success, actual_instruction_steps and eval_id
            conditions = ' AND '.join(f"{f.name} = :{f.name}" for f in fields(EvalResult) 
                                      if f.name in CHECK_EXIST_COLUMNS)
            sql = f'SELECT COUNT(*) FROM EvalResult WHERE {conditions}'
            eval_result_dict = asdict(eval_result)
            # Remove fields not in conditions
            eval_result_dict_filtered = {k: v for k, v in eval_result_dict.items() 
                                         if k in CHECK_EXIST_COLUMNS}
            self.cursor.execute(sql, eval_result_dict_filtered)
            count = self.cursor.fetchone()[0]
            return count > 0
        finally:
            self._release_lock()
        
    def _get_sql_type(self, py_type):
        if py_type == int:
            return 'INTEGER'
        elif py_type == float:
            return 'REAL'
        elif py_type == bool:
            return 'INTEGER'  # Store bool as INTEGER (0 or 1)
        else:
            return 'TEXT'
    
    def _acquire_lock(self, timeout=30):
        """Acquire file lock with timeout"""
        self.lock_fd = open(self.lock_file, 'w')
        start_time = time.time()
        while True:
            try:
                fcntl.flock(self.lock_fd.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                return True
            except IOError:
                if time.time() - start_time >= timeout:
                    raise TimeoutError(f"Could not acquire lock after {timeout} seconds")
                time.sleep(0.1)
    
    def _release_lock(self):
        """Release file lock"""
        if self.lock_fd:
            fcntl.flock(self.lock_fd.fileno(), fcntl.LOCK_UN)
            self.lock_fd.close()
            self.lock_fd = None

    def create_table(self):
        # Generate column definitions from dataclass fields
        columns = ', '.join(f'{f.name} {self._get_sql_type(f.type)}' for f in fields(EvalResult))
        self.cursor.execute(f'CREATE TABLE IF NOT EXISTS EvalResult ({columns})')
        self.conn.commit()

    def insert_eval_result(self, eval_result: EvalResult):
        # Use named placeholders for safe insertion
        self._acquire_lock()
        try:
            headers = ','.join(f.name for f in fields(EvalResult))
            placeholders = ','.join(f':{f.name}' for f in fields(EvalResult))
            sql = f'INSERT INTO EvalResult ({headers}) VALUES ({placeholders})'
            self.cursor.execute(sql, asdict(eval_result))
            self.conn.commit()
        finally:
            self._release_lock()
        
    def delete_all_eval_results(self):
        confirmation = input("Are you sure you want to delete all eval results? Type 'yes' to confirm: ")
        if confirmation.lower() == 'yes':
            self._acquire_lock()
            try:
                self.cursor.execute('DELETE FROM EvalResult')
                self.conn.commit()
            finally:
                self._release_lock()
        else:
            print("Deletion cancelled.")
            
    def copy_to_backup(self, backup_db_name: Path):
        self._acquire_lock()
        try:
            cmd = f'cp {self.db_name} {backup_db_name}'
            os.system(cmd)
        finally:
            self._release_lock()
            
    def query_from_sql(self, sql: str) -> pd.DataFrame:
        self._acquire_lock()
        try:
            df = pd.read_sql_query(sql, self.conn)
            return df
        finally:
            self._release_lock()
            
    def execute_sql(self, sql: str):
        self._acquire_lock()
        try:
            self.cursor.execute(sql)
            self.conn.commit()
        finally:
            self._release_lock()
        

    def get_all_eval_results(self) -> list[EvalResult]:
        self._acquire_lock()
        try:
            query = 'SELECT * FROM EvalResult'
            df = pd.read_sql_query(query, self.conn)
            return df
        finally:
            self._release_lock()
            
    def get_sample_10_eval_results(self) -> list[EvalResult]:
        self._acquire_lock()
        try:
            # get success = 1 samples
            # use pd.read_sql_query for convenience
            query = 'SELECT * FROM EvalResult WHERE success = 1 ORDER BY RANDOM() LIMIT 10'
            df = pd.read_sql_query(query, self.conn)
            return df
        finally:
            self._release_lock()
            
    def integrate_from_another_db(self, other_db_name: Path):
        other_conn = sqlite3.connect(other_db_name)
        other_cursor = other_conn.cursor()
        
        self._acquire_lock()
        try:
            other_cursor.execute('SELECT * FROM EvalResult')
            rows = other_cursor.fetchall()
            columns = [description[0] for description in other_cursor.description]
            
            for row in tqdm(rows, desc="Integrating eval results"):
                eval_result_dict = dict(zip(columns, row))
                eval_result = EvalResult(**eval_result_dict)
                
                # Check existence directly without calling check_if_exists() to avoid nested lock
                conditions = ' AND '.join(f"{f.name} = :{f.name}" for f in fields(EvalResult) 
                                        if f.name in CHECK_EXIST_COLUMNS)
                sql = f'SELECT COUNT(*) FROM EvalResult WHERE {conditions}'
                eval_result_dict_filtered = {k: v for k, v in eval_result_dict.items() 
                                            if k in CHECK_EXIST_COLUMNS}
                self.cursor.execute(sql, eval_result_dict_filtered)
                count = self.cursor.fetchone()[0]
                
                if count == 0:
                    # Insert directly without calling insert_eval_result() to avoid nested lock
                    headers = ','.join(f.name for f in fields(EvalResult))
                    placeholders = ','.join(f':{f.name}' for f in fields(EvalResult))
                    insert_sql = f'INSERT INTO EvalResult ({headers}) VALUES ({placeholders})'
                    self.cursor.execute(insert_sql, asdict(eval_result))
            
            self.conn.commit()
        finally:
            self._release_lock()
            other_conn.close()
    
    def remove_with_keyword(self, eval_round_id: str, keywords: Optional[dict] = None):
        """
        Remove evaluation results based on eval_round_id and optional keyword filters.
        
        Args:
            eval_round_id: The evaluation round identifier
            keywords: Optional dictionary of field-value pairs to filter by.
                     Example: {'model_arch': 'OpenVLA-7B', 'training_strategy': 'Ours-PureHER'}
        """
        query = f"DELETE FROM EvalResult WHERE eval_round_id = '{eval_round_id}'"
        
        if keywords:
            for key, value in keywords.items():
                if isinstance(value, bool):
                    query += f" AND {key} = {1 if value else 0}"
                elif isinstance(value, (int, float)):
                    query += f" AND {key} = {value}"
                else:
                    query += f" AND {key} = '{value}'"
            
        # another query to show how many records will be deleted
        count_query = query.replace("DELETE FROM EvalResult", "SELECT COUNT(*) FROM EvalResult")
        focus_cursor = self.cursor
        focus_conn = self.conn
        
        total_count_query = "SELECT COUNT(*) FROM EvalResult"
        
        
        self._acquire_lock()
        try:
            focus_cursor.execute(count_query)
            count = focus_cursor.fetchone()[0]
            print(f"Number of records to be deleted: {count}")
            
            # total records
            focus_cursor.execute(total_count_query)
            total_count = focus_cursor.fetchone()[0]
            print(f"Total records in the database before deletion: {total_count}")
            
            # calculate percentage
            percentage = (count / total_count * 100) if total_count > 0 else 0
            print(f"Percentage of records to be deleted: {percentage:.2f}%")
            
        finally:
            self._release_lock()
        # need to confirm 
        
        confirm_output = input(f"Are you sure to delete records with the following condition?\n{query}\n Number of records to be deleted: {count}\nType 'yes' to confirm: ")
        if confirm_output.lower() == 'yes':
            self._acquire_lock()
            try:
                focus_cursor.execute(query)
                focus_conn.commit()
                print(f"Deleted {count} records.")
            finally:
                self._release_lock()
        else:
            print("Deletion cancelled.")
            
    def close(self):
        if self.lock_fd:
            self._release_lock()
        self.conn.close()
        # # Clean up lock file if it exists
        # if self.lock_file.exists():
        #     try:
        #         self.lock_file.unlink()
        #     except:
        #         pass
        
if __name__ == "__main__":
    db_helper = DatabaseHelper()
    # create table 
    db_helper.create_table()
    # Example usage
    eval_result = EvalResult(
        eval_round_id="debug",
        train_id="test_train_id_001",
        timestamp="2024-10-01 12:00:00",
        checkpoint_step=10000,
        model_arch="OpenVLA-7B",
        training_strategy="Ours-PureHER",
        env_name="LIBERO",
        task_suite_name="libero_spatial",
        problem_id=1,
        vision_granularity="224",
        instruction_type="l",
        instruction_value="Place the sponge in the cup.",
        success=True
    )
    
    if not db_helper.check_if_exists(eval_result):
        db_helper.insert_eval_result(eval_result)
        print("Inserted new eval result.")
    else:
        print("Eval result already exists.")
    
    all_results = db_helper.get_all_eval_results()
    print("All Eval Results:")
    print(all_results)
    print(f"Total eval results in database: {len(all_results)}")
    
    db_helper.close()
    