
from WFP.wfp_test_flash import *

root__ = os.path.dirname(os.path.realpath(__file__))
base_root = os.path.dirname(root__)  # location where all projects reside

# print base_root
sys.path.append(base_root)



class TestWfpMultiTarget(Flashertest):
    """
    define the standard tests
    """

    test_command_list = None

    binary_file_read_from_netx = None
    binary_file_write_to_netx = None
    user_inupt_assign = {}

    def __init__(self, lfm):
        Flashertest.__init__(self, lfm)
        # self.test_binary_size = 5 * 1024
        self.test_files = {}
        self.memory_to_test = None
        self.plugin = plugin_name = None
        self.user_inupt_assign = {}

    def get_target_data(self):
        tree = parse(self.wfp_xml_path)
        root = tree.getroot()
        self.test_data = {}
        for target in root.getchildren():
            if not target.tag == "Target":
                continue
            if not target.attrib['netx'] == CHIP_TYPE[self.chip_id]:
                continue
            self.test_data['target'] = {}
            for i, command in enumerate(target.getchildren()):
                self.test_data['target'][i] = command.attrib
                self.test_data['target'][i]['bus'] = FLASHER_BUS_NAME[command.attrib['bus']]
                self.test_data['target'][i]['files'] = {}
                for j, data in enumerate(command.getchildren()):
                    self.test_data['target'][i]['files'][j] = {}
                    self.test_data['target'][i]['files'][j] = data.attrib


    def init_params(self, plugin_name, memories_to_test, test_binary_size, path_lua_files, flasher_binary,
                    dict_add_params, ut_class=None):


        self.ut_class = ut_class
        self.command_structure = []
        self.path_lua_files = path_lua_files
        self.flasher_binary = flasher_binary
        self.dict_add_params = dict_add_params

        self.memories_to_test = memories_to_test
        #  get the plugin name of the board
        self.plugin_name = "-p %s" % plugin_name["plugin_name"]

        self.wfp_dir_path = os.path.join(root__, "test_files", "wfp_archive")
        self.wfp_zip_path = os.path.join(root__, "test_files", "wfp_archive.zip")
        self.wfp_xml_path = os.path.join(self.wfp_dir_path, "wfp.xml")


        # get plugin number
        self.plug_num = plugin_name['plug_num']
        self.bool_params_init = True
        self.chip_id = plugin_name['netx_chip_type']

        self.get_target_data()


    def pre_test_step(self):
        enable_flasher = {"flasher": True}
        wfp_flash = {"wfp": {"user_input": self.plug_num}}
        wfp_pack = {"wfp": {}}
        for flash in self.test_data['target'].values():
            self.bus_port_parameters_flasher = "-b %s -u %s -cs %s" % (flash['bus'],
                                                                       flash["unit"],
                                                                       flash['chip_select'])

            self.memory_to_test = None
            for mem in self.memories_to_test:
                if (mem["b"] == int(flash['bus']) and
                        mem["u"] == int(flash['unit']) and
                        mem["cs"] == int(flash['chip_select'])):
                    self.memory_to_test = mem
                    break
            if not self.memory_to_test:
                self.ut_class.skipTest('test_wfp_multi_target: Memory from wfp.xml is not found on test hardware!')
                # raise (BaseException("Memory from wfp.xml is not found on test hardware!"))

            self.test_binary_size = self.memory_to_test['size']
            # add erase command and wfp flash command
            self.command_structure.append([enable_flasher, "cli_flash.lua", "erase", self.bus_port_parameters_flasher,
                                           "-l 0x%x" % self.test_binary_size, self.plugin_name])
            self.command_structure.append([wfp_flash, "wfp.lua", "flash", self.wfp_zip_path])

            for data in flash['files'].values():
                file_path = os.path.realpath(os.path.join(self.wfp_dir_path, data['file']))
                self.command_structure.append([enable_flasher,
                                               "cli_flash.lua",
                                               "verify",
                                               self.bus_port_parameters_flasher,
                                               self.plugin_name,
                                               "-s", "0x%08X" % (int(data['offset'], 16)),
                                               file_path])

    def convert_final_command_entries_to_commands(self):
        if self.command_strings:
            assert True

        # define positions inside command_structure list
        prog_select = 0      # used to select the program, which should be executed
        parameter_start = 1  # first optional parameter for the program

        l.info("Generate commands:")
        for idx, ele in enumerate(self.command_structure):

            #detect the program to use
            dict_prog_select = ele[prog_select] # type = dict
            assert(type(dict_prog_select) is dict)
            tmp_final_test_command = None
            for prog in dict_prog_select.iterkeys():
                if prog == "flasher":
                    # concat all to one string
                    tmp_final_test_command = self.flasher_binary
                    # make full file path
                    tmp_full_file_path = os.path.join(self.path_lua_files, ele[parameter_start])
                    self.command_structure[idx][parameter_start] = tmp_full_file_path

                elif prog == "openocd":
                    # concat all to one string
                    tmp_final_test_command = dict_prog_select["bin_path"]
                elif prog == "bin_path":
                    # skip known parameter used for path to binary
                    pass
                elif prog == "wfp":
                    user_input = dict_prog_select['wfp'].get('user_input', None)
                    # concat all to one string
                    tmp_final_test_command = self.flasher_binary
                    # make full file path
                    tmp_full_file_path = os.path.join(self.path_lua_files, ele[parameter_start])
                    self.command_structure[idx][parameter_start] = tmp_full_file_path
                    # assign a user input to a command string
                    if user_input:
                        self.user_inupt_assign[idx] = user_input
                else:
                    l.error("key %s is not supported" % prog)

            for int_ele in ele[parameter_start:]:
                tmp_final_test_command += " %s" % int_ele
            # append
            self.command_strings.append(tmp_final_test_command)
            # todo: later: this should be also a json tolerant structure, combining input and output.
            l.info(self.command_strings[-1])

    def run_batch_commands(self):

        default_carrier = command_carrier()
        default_carrier.bool_interrupt_batch = self.bool_interrupt_batch_f

        default_carrier.change_dir_to_bin = True  # relevant for executing flasher with linux correct
        l.info("Execute generated commands above!")
        # todo: rework the command carrier, this is kind of not cool. (redundant code)
        # inert here final commands!
        # todo: integrate the logfiles more?
        carrier_result = batch_command_base(
            default_carrier,
            self.command_strings,
            self.lfm.get_dir_tmp_logfiles(),
            self.uuid_test,
            #  added to hand over user input parameter, that need to be set during execution of a command
            self.user_inupt_assign
        )
        self.numErrors += eval_batch_result(
            carrier_result,
            self.lfm.get_dir_tmp_logfiles(),
            self.logfile_prefix,
            "%s %s" % (self.uuid_test, self.__class__.__name__))
        self.numErrors_a.append([self.uuid_test, self.numErrors, self.__class__.__name__, len(self.command_strings)])

    def init_command_array(self):
        pass
