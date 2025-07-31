python
# this program is vibe-coded
import gdb
import time

class PollWatchManager:
    watches = {}
    next_id = 0
    last_poll_time = 0
    interval = 0.01  # loop tick rate: check all watches every 10ms

    @classmethod
    def poll_all(cls):
        now = time.time()
        if now - cls.last_poll_time < cls.interval:
            gdb.post_event(cls.poll_all)
            return
        cls.last_poll_time = now

        for watch in list(cls.watches.values()):
            if watch.enabled:
                watch.poll_once()

        gdb.post_event(cls.poll_all)

class PollWatch:
    def __init__(self, expr, interval_ms):
        self.id = PollWatchManager.next_id
        PollWatchManager.next_id += 1
        self.expr = expr
        self.interval = float(interval_ms) / 1000.0
        self.last_time = 0
        self.old_val = None
        self.enabled = True
        PollWatchManager.watches[self.id] = self
        print(f"Started pollwatch {self.id}: '{expr}' every {interval_ms} ms")

    def poll_once(self):
        now = time.time()
        if now - self.last_time < self.interval:
            return
        self.last_time = now

        try:
            val = int(gdb.parse_and_eval(self.expr))
        except Exception:
            val = None

        if self.old_val is None:
            self.old_val = val
        elif val != self.old_val:
            print(f"Pollwatch {self.id} triggered: {self.old_val} -> {val}")
            self.old_val = val
            gdb.execute("interrupt", to_string=True)

class PollWatchCommand(gdb.Command):
    def __init__(self):
        super().__init__("pollwatch", gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        args = arg.strip().split(None, 1)
        if len(args) != 2:
            print("Usage: pollwatch <interval_ms> <expression>")
            return
        try:
            interval_ms = float(args[0])
        except ValueError:
            print("Invalid interval (use float or int milliseconds)")
            return
        expr = args[1]
        PollWatch(expr, interval_ms)

class PollWatchListCommand(gdb.Command):
    def __init__(self):
        super().__init__("pollwatch-list", gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        for wid, w in PollWatchManager.watches.items():
            status = "enabled" if w.enabled else "disabled"
            print(f"{wid}: '{w.expr}' every {w.interval*1000:.1f} ms [{status}]")

class PollWatchEnableCommand(gdb.Command):
    def __init__(self):
        super().__init__("pollwatch-enable", gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        try:
            wid = int(arg.strip())
            w = PollWatchManager.watches.get(wid)
            if w:
                w.enabled = True
                print(f"Enabled pollwatch {wid}")
            else:
                print(f"No pollwatch with ID {wid}")
        except ValueError:
            print("Usage: pollwatch-enable <id>")

class PollWatchDisableCommand(gdb.Command):
    def __init__(self):
        super().__init__("pollwatch-disable", gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        try:
            wid = int(arg.strip())
            w = PollWatchManager.watches.get(wid)
            if w:
                w.enabled = False
                print(f"Disabled pollwatch {wid}")
            else:
                print(f"No pollwatch with ID {wid}")
        except ValueError:
            print("Usage: pollwatch-disable <id>")

PollWatchCommand()
PollWatchListCommand()
PollWatchEnableCommand()
PollWatchDisableCommand()
gdb.post_event(PollWatchManager.poll_all)
end

