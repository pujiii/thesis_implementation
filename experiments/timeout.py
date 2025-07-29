import subprocess
import sys
import os

def main():
    if len(sys.argv) != 3:
        print(f"Usage: python {sys.argv[0]} <domainname> <problem>")
        sys.exit(1)

    domainname = sys.argv[1]
    problem = sys.argv[2]

    # Example Julia call: julia my_script.jl domainname problem
    cmd = [
        "julia",
        "--project=./Implementation",
        "Implementation/experiments/solve_problem.jl",
        f"--domainname={domainname}",
        f"--problem={problem}"
    ]

    try:
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        stdout, stderr = process.communicate(timeout=600)  # timeout in sec

        print(stdout)

    except subprocess.TimeoutExpired:
        process.kill()
        print(subprocess.PIPE)
        print(-1)

if __name__ == "__main__":
    main()