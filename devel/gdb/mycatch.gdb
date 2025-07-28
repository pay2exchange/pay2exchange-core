python
import gdb, sys

class FooThrowBreakpoint(gdb.Breakpoint):
    def __init__(self):
        super(FooThrowBreakpoint, self).__init__("__cxa_throw", internal=False)

    def stop(self):
        try:
            # start at the frame inside __cxa_throw, move one up
            #gdb.write("\nGDB plugin: Some exception...\n")
            frame = gdb.newest_frame().older()

            # walk up to 5 frames looking for foo.cpp
            for _ in range(5):
                if frame is None:
                    break
                sal = frame.find_sal()
                if sal.symtab and sal.symtab.filename.endswith("db_maint.cpp"):
                    # print a notice, then stop
                    gdb.write(
                        "\n== exception thrown from %s:%d ==\n"
                        % (sal.symtab.filename, sal.line)
                    )
                    return True
                frame = frame.older()

        except Exception as e:
            # on script error, log to stderr and continue
            sys.stderr.write("FooThrowBreakpoint error: %s\n" % e)

        # default: don’t stop here
        return False

# install the breakpoint
gdb.write("Installing...\n")
FooThrowBreakpoint()
gdb.write("Installed\n")
end
