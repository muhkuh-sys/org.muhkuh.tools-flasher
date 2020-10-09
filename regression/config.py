import os
import sys
DIR_SRC = os.path.dirname(os.path.realpath(__file__))

sys.path.insert(0, DIR_SRC)
print("Added to source path: %s " % DIR_SRC)
