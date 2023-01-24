import asyncio
import datetime
import os
from typing import Union, List
import re

from rich.text import Text
from rich.prompt import IntPrompt
from rich.console import Console
from rich.table import Table

from icloud import HideMyEmail


MAX_CONCURRENT_TASKS = 10


class RichHideMyEmail(HideMyEmail):
    _cookie_file = "cookie.txt"

    def __init__(self):
        super().__init__()
        self.console = Console()
        self.table = Table()

        if os.path.exists(self._cookie_file):
            # load in a cookie string from file
            with open(self._cookie_file, "r") as f:
                self.cookies = [line for line in f if not line.startswith('//')][0]
        else:
            self.console.log(
                '[bold yellow][WARN][/] No "cookie.txt" file found! Generation might not work due to unauthorized access.'
            )

    async def _generate_one(self) -> Union[str, None]:
        # First, generate an email
        gen_res = await self.generate_email()

        if not gen_res:
            return
        elif "success" not in gen_res or not gen_res["success"]:
            error = gen_res["error"] if "error" in gen_res else {}
            err_msg = "Unknown"
            if type(error) == int and "reason" in gen_res:
                err_msg = gen_res["reason"]
            elif type(error) == dict and "errorMessage" in error:
                err_msg = error["errorMessage"]
            self.console.log(
                f"[bold red][ERR][/] - Failed to generate email. Reason: {err_msg}"
            )
            return

        email = gen_res["result"]["hme"]
        self.console.log(f'[50%] "{email}" - Successfully generated')

        # Then, reserve it
        reserve_res = await self.reserve_email(email)

        if not reserve_res:
            return
        elif "success" not in reserve_res or not reserve_res["success"]:
            error = reserve_res["error"] if "error" in reserve_res else {}
            err_msg = "Unknown"
            if type(error) == int and "reason" in reserve_res:
                err_msg = reserve_res["reason"]
            elif type(error) == dict and "errorMessage" in error:
                err_msg = error["errorMessage"]
            self.console.log(
                f'[bold red][ERR][/] "{email}" - Failed to reserve email. Reason: {err_msg}'
            )
            return

        self.console.log(f'[100%] "{email}" - Successfully reserved')
        return email

    async def _generate(self, num: int):
        tasks = []
        for _ in range(num):
            task = asyncio.ensure_future(self._generate_one())
            tasks.append(task)

        return filter(lambda e: e is not None, await asyncio.gather(*tasks))

    async def generate(self) -> List[str]:
        try:
            emails = []
            self.console.rule()
            s = IntPrompt.ask(
                Text.assemble(("How many iCloud emails you want to generate?")),
                console=self.console,
            )

            count = int(s)
            self.console.log(f"Generating {count} email(s)...")
            self.console.rule()

            with self.console.status(f"[bold green]Generating iCloud email(s)..."):
                while count > 0:
                    batch = await self._generate(
                        count if count < MAX_CONCURRENT_TASKS else MAX_CONCURRENT_TASKS
                    )
                    count -= MAX_CONCURRENT_TASKS
                    emails += batch

            if len(emails) > 0:
                with open("emails.txt", "a+") as f:
                    f.write(os.linesep.join(emails) + os.linesep)

                self.console.rule()
                self.console.log(
                    f':star: Emails have been saved into the "emails.txt" file'
                )

                self.console.log(
                    f"[bold green]All done![/] Successfully generated [bold green]{len(emails)}[/] email(s)"
                )

            return emails
        except KeyboardInterrupt:
            return []

    async def list(self, active: bool, search: str) -> None:
        gen_res = await self.list_email()
        if not gen_res:
            return

        if "success" not in gen_res or not gen_res["success"]:
            error = gen_res["error"] if "error" in gen_res else {}
            err_msg = "Unknown"
            if type(error) == int and "reason" in gen_res:
                err_msg = gen_res["reason"]
            elif type(error) == dict and "errorMessage" in error:
                err_msg = error["errorMessage"]
            self.console.log(
                f"[bold red][ERR][/] - Failed to generate email. Reason: {err_msg}"
            )
            return

        self.table.add_column("Label")
        self.table.add_column("Hide my email")
        self.table.add_column("Created Date Time")
        self.table.add_column("IsActive")

        for row in gen_res["result"]["hmeEmails"]:
            if row["isActive"] == active:
                if search is not None and re.search(search, row["label"]):
                    self.table.add_row(
                        row["label"],
                        row["hme"],
                        str(
                            datetime.datetime.fromtimestamp(
                                row["createTimestamp"] / 1000
                            )
                        ),
                        str(row["isActive"]),
                    )
                else:
                    self.table.add_row(
                        row["label"],
                        row["hme"],
                        str(
                            datetime.datetime.fromtimestamp(
                                row["createTimestamp"] / 1000
                            )
                        ),
                        str(row["isActive"]),
                    )

        self.console.print(self.table)


async def generate() -> None:
    async with RichHideMyEmail() as hme:
        await hme.generate()


async def list(active: bool, search: str) -> None:
    async with RichHideMyEmail() as hme:
        await hme.list(active, search)


if __name__ == "__main__":
    loop = asyncio.get_event_loop()
    loop.run_until_complete(generate())
