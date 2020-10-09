import os, sys

file_dir = os.path.dirname(os.path.realpath(__file__))  # xxx/src/
base_root = os.path.dirname(file_dir)  # location where all projects reside

# print base_root
sys.path.append(base_root)

# from ptb_api.SW_Test_flasher.src.class_dyntest import *
from common.SW_Test_flasher.src.class_dyntest import *
# from ptb_api.simpelTools.src.filetools import *
from common.simpelTools.src.filetools import *


class FltTiming(Flashertest):
    """
    define the hash tests
    """

    test_command_list = None
    binary_file_read_from_netx = None
    binary_file_write_to_netx = None

    def __init__(self, lfm):
        Flashertest.__init__(self, lfm)
        self.test_binary_size = 11*1024

    def pre_test_step(self):
        # Generate test-binary-files
        self.binary_file_write_1 = os.path.realpath(os.path.join(self.lfm.get_dir_work(),
                                                       "test_%s_writefile_1.bin" % self.__class__.__name__))
        self.binary_file_write_2 = os.path.realpath(os.path.join(self.lfm.get_dir_work(),
                                                       "test_%s_writefile_2.bin" % self.__class__.__name__))

        self.binary_file_read = os.path.realpath(os.path.join(self.lfm.get_dir_tmp_logfiles(),
                                                       "test_%s_readfile_2.bin" % self.__class__.__name__))

        generate_random_file_by_size_and_name(self.binary_file_write_1, self.test_binary_size)
        generate_random_file_by_size_and_name(self.binary_file_write_2, self.test_binary_size)

        shutil.copy(self.binary_file_write_1, self.lfm.get_dir_tmp_logfiles())
        shutil.copy(self.binary_file_write_2, self.lfm.get_dir_tmp_logfiles())

    def init_command_array(self):
        enable_flasher = {"flasher": True}
        self.command_structure = [

            # erase flash
            [enable_flasher, "cli_flash.lua", "erase", self.bus_port_parameters_flasher,
             "-l 0x%x" % self.test_binary_size, self.plugin_name],

            # write empty (timed)
            [enable_flasher, "cli_flash.lua", "flash", self.bus_port_parameters_flasher, self.plugin_name,
             self.binary_file_write_1],

            # write not empty (timed)
            [enable_flasher, "cli_flash.lua", "flash", self.bus_port_parameters_flasher, self.plugin_name,
             self.binary_file_write_2],

             # read(timed)
            [enable_flasher, "cli_flash.lua", "read", self.bus_port_parameters_flasher,
             "-l 0x%x" % self.test_binary_size, self.plugin_name,
             self.binary_file_read],

            # erase not empty (timed)
            [enable_flasher, "cli_flash.lua", "erase", self.bus_port_parameters_flasher,
             "-l 0x%x" % self.test_binary_size, self.plugin_name],

        ]

