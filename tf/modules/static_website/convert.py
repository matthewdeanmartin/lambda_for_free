from pathlib import Path
import subprocess
import shutil

# === Configuration ===
HCL_FILE: Path = Path("main.tf").resolve()
CDKTF_DIR: Path = Path("cdktf_out").resolve()
OUTPUT_FILE: Path = CDKTF_DIR / "imported.py"
CDKTF_LANGUAGE: str = "python"
PROVIDERS: list[str] = ["hashicorp/aws@~>5.0.0"]

def clean_output_dir(output_dir: Path) -> None:
    if output_dir.exists():
        print(f"Removing existing directory: {output_dir}")
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=False)
    print(f"Created directory: {output_dir}")

def cdktf_init(output_dir: Path, language: str) -> None:
    print(f"Initializing CDKTF project in {output_dir}")
    print(str(output_dir))
    subprocess.run(
        ["cdktf", "init", "--local", "--template", language, "--projec-name", "p1",
         "--project-description", "d1", "--enable-crash-reporting", "false" , "--providers", "aws"],
        check=True,
        cwd=str(output_dir)
    )

def convert_hcl_to_cdktf(hcl_file: Path, output_file: Path, providers: list[str], language: str) -> None:
    print(f"Converting {hcl_file} to CDKTF Python code in {output_file}")
    with hcl_file.open("rb") as infile, output_file.open("w", encoding="utf-8") as outfile:
        subprocess.run(
            [
                "cdktf",
                "convert",
                "--language", language,
                *sum([["--provider", p] for p in providers], [])
            ],
            stdin=infile,
            stdout=outfile,
            check=True,
        )

def main() -> None:
    print("=== Starting HCL to CDKTF conversion ===")
    # clean_output_dir(CDKTF_DIR)
    # cdktf_init(CDKTF_DIR, CDKTF_LANGUAGE)
    convert_hcl_to_cdktf(HCL_FILE, OUTPUT_FILE, PROVIDERS, CDKTF_LANGUAGE)
    print(f"✅ Conversion complete: {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
