from time import sleep
import os
import sys
if __name__ == "__main__":
    # if SLURM_JOB_ID is set, we are in slurm
    # then sleep for 300 seconds
    if "SLURM_JOB_ID" in os.environ:
        sleep(300)
    else:
        sys.exit(0)