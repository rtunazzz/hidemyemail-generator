

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
def listcommand():
    "List HME"
    loop = asyncio.get_event_loop()
    loop.run_until_complete(list())

cli.add_command(listcommand) 
cli.add_command(generatecommand)

if __name__ == '__main__':
    cli()
