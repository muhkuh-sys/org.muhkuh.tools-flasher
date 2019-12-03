import logging
import sys


create_logger = False
try:
    # this is intended!
    l
except NameError:
    create_logger = True


if create_logger:
    formatter_print =  logging.Formatter('[pirate] %(levelname)-8s %(asctime)s | %(message)s', datefmt=' %H:%M:%S')
    formatter_file = logging.Formatter('[pirate][%(levelname)-8s][%(asctime)s]%(message)s')

    l = logging.getLogger("test")

    # Add a file logger
    f = logging.FileHandler("test.log")
    f.setFormatter(formatter_file)
    l.addHandler(f)

    # Add a stream logger
    s = logging.StreamHandler(sys.stdout)
    s.setFormatter(formatter_print)
    l.addHandler(s)

    # Send a test message to both -- critical will always log
    l.setLevel(logging.INFO)
else:
    l.info("skipped creation of logger because is does aready exist!")
