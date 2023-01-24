import asyncio
import click

from main import generate
from main import list

@click.group()
def cli():
    pass

@click.command()
def generatecommand():
    "Generate HME"
    loop = asyncio.get_event_loop()
    loop.run_until_complete(generate())

@click.command()
@click.option('--active/--inactive', default=True, help='Filter Active / Inactive HME')
@click.option('--search', default=None, help='Search HME')
def listcommand(active, search):
    "List HME"
    loop = asyncio.get_event_loop()
    loop.run_until_complete(list(active, search))

cli.add_command(listcommand) 
cli.add_command(generatecommand)

if __name__ == '__main__':
    cli()
