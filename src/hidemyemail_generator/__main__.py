import sys


def main() -> None:
    if len(sys.argv) > 1:
        from hidemyemail_generator.main import cli

        cli()
    else:
        from hidemyemail_generator.launcher import main as launcher_main

        launcher_main()


if __name__ == "__main__":
    main()
