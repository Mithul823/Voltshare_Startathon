from pathlib import Path


def main() -> None:
    path = Path(__file__).resolve().parents[1] / "app" / "db" / "seeds" / "seed_marketplace.sql"
    print(path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    main()
