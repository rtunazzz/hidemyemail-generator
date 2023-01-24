import asyncio
import click

from main import generate
from main import list


@click.group()
def cli():
    pass


@click.command()
def generatecommand():
    "Generate emails"
    loop = asyncio.get_event_loop()
    loop.run_until_complete(generate())


@click.command()
@click.option(
    "--active/--inactive", default=True, help="Filter Active / Inactive emails"
)
@click.option("--search", default=None, help="Search emails")
def listcommand(active, search):
    "List emails"
    loop = asyncio.get_event_loop()
    loop.run_until_complete(list(active, search))


cli.add_command(listcommand, name="list")
cli.add_command(generatecommand, name="generate")

if __name__ == "__main__":
    cli()
